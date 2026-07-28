import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
public class PlayerViewModel: ObservableObject {
    @Published public var player: AVPlayer?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var isControlsVisible: Bool = true
    @Published public var isBuffering: Bool = false
    @Published public var playbackError: String?
    
    // Subtitles state
    @Published public var availableSubtitles: [SubtitleTrack] = []
    @Published public var selectedSubtitleTrack: SubtitleTrack?
    @Published public var activeSubtitleCue: String? = nil
    private var parsedCues: [SubtitleCue] = []

    // Audio state. The actual AVMediaSelectionOption objects are kept private,
    // because they are tied to the active AVPlayerItem.
    @Published public var availableAudioTracks: [AudioTrack] = []
    @Published public var selectedAudioTrackID: String?
    private var audioSelectionGroup: AVMediaSelectionGroup?
    private var audioOptions: [String: AVMediaSelectionOption] = [:]
    
    // Quality & Server state
    @Published public var availableSources: [StreamSource] = []
    @Published public var activeSource: StreamSource?
    @Published public var activeProvider: ServerProvider = .zstream
    
    // Gesture overlay states
    @Published public var isSeeking: Bool = false
    @Published public var gestureMessage: String? = nil
    
    public let mediaItem: MediaItem
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var itemCancellables = Set<AnyCancellable>()
    private var hideControlsTimer: Timer?
    private var pendingSeekTime: TimeInterval?
    private var shouldPlayWhenReady = true
    
    public init(
        mediaItem: MediaItem,
        stream: ResolvedMediaStream,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) {
        self.mediaItem = mediaItem
        self.availableSources = stream.sources
        self.availableSubtitles = stream.subtitles
        self.activeProvider = stream.activeProvider
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber

        if let saved = WatchHistoryManager.shared.getProgress(mediaId: mediaItem.id, season: seasonNumber, episode: episodeNumber) {
            self.pendingSeekTime = saved.currentTime
        }

        if let initialSource = stream.sources.first {
            self.activeSource = initialSource
            setupPlayer(with: initialSource)
        } else {
            self.playbackError = "No playable video source was found."
        }
        
        // Auto-select preferred subtitle language if available
        let prefLang = UserSettings.shared.preferredSubtitleLanguage.lowercased()
        if let defaultTrack = stream.subtitles.first(where: { $0.language.lowercased().contains(prefLang) }) ?? stream.subtitles.first {
            selectSubtitleTrack(defaultTrack)
        }
        
        resetHideControlsTimer()
    }

    deinit {
        MainActor.assumeIsolated {
            if let token = timeObserverToken {
                player?.removeTimeObserver(token)
            }
        }
    }

    public func setupPlayer(with source: StreamSource) {
        itemCancellables.removeAll()
        playbackError = nil
        isBuffering = true
        isPlaying = false
        availableAudioTracks = []
        selectedAudioTrackID = nil
        audioSelectionGroup = nil
        audioOptions = [:]

        let playerItem = AVPlayerItem(url: source.url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        observe(playerItem)
        addTimeObserver()
    }

    public func togglePlayPause() {
        guard let player = player else {
            retryPlayback()
            return
        }

        if player.currentItem?.status == .failed {
            retryPlayback()
            return
        }

        if isPlaying {
            shouldPlayWhenReady = false
            player.pause()
            isPlaying = false
        } else {
            shouldPlayWhenReady = true
            playbackError = nil
            if player.currentItem?.status == .readyToPlay {
                player.play()
            } else {
                isBuffering = true
            }
        }
        resetHideControlsTimer()
    }

    public func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let targetCMTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: targetCMTime) { [weak self] _ in
            self?.currentTime = time
            self?.updateSubtitleCue(for: time)
        }
        resetHideControlsTimer()
    }

    public func skip(seconds: TimeInterval) {
        let newTime = min(max(currentTime + seconds, 0), duration)
        seek(to: newTime)
        showGestureNotification(seconds > 0 ? "+\(Int(seconds))s" : "\(Int(seconds))s")
    }

    public func selectSubtitleTrack(_ track: SubtitleTrack?) {
        selectedSubtitleTrack = track
        guard let track = track else {
            parsedCues = []
            activeSubtitleCue = nil
            return
        }
        
        Task {
            do {
                let cues = try await SubtitleParser.shared.fetchAndParse(url: track.url)
                self.parsedCues = cues
                self.updateSubtitleCue(for: self.currentTime)
            } catch {
                print("Failed to parse subtitles: \(error)")
            }
        }
    }

    public func changeQuality(_ source: StreamSource) {
        activeSource = source
        pendingSeekTime = currentTime
        setupPlayer(with: source)
    }

    public func retryPlayback() {
        guard let source = activeSource else {
            playbackError = "No playable video source was found."
            return
        }

        pendingSeekTime = currentTime > 0 ? currentTime : pendingSeekTime
        shouldPlayWhenReady = true
        setupPlayer(with: source)
    }

    public func selectAudioTrack(_ track: AudioTrack) {
        guard let group = audioSelectionGroup, let option = audioOptions[track.id] else { return }
        player?.currentItem?.select(option, in: group)
        selectedAudioTrackID = track.id
        resetHideControlsTimer()
    }

    private func observe(_ item: AVPlayerItem) {
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] status in
                guard let self, let item, self.player?.currentItem === item else { return }

                switch status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self.loadAudioTracks(from: item)
                    self.resumePendingPlayback()
                case .failed:
                    self.handlePlaybackFailure(item.error)
                case .unknown:
                    self.isBuffering = true
                @unknown default:
                    self.isBuffering = true
                }
            }
            .store(in: &itemCancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.handlePlaybackFailure(error)
            }
            .store(in: &itemCancellables)

        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.isPlaying = status == .playing
                self.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
            .store(in: &itemCancellables)
    }

    private func resumePendingPlayback() {
        let startPlayback = { [weak self] in
            guard let self, self.shouldPlayWhenReady else { return }
            self.player?.play()
        }

        guard let time = pendingSeekTime, time > 0 else {
            startPlayback()
            return
        }

        pendingSeekTime = nil
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self else { return }
            if finished {
                self.currentTime = time
                self.updateSubtitleCue(for: time)
            }
            if self.shouldPlayWhenReady {
                self.player?.play()
            }
        }
    }

    private func loadAudioTracks(from item: AVPlayerItem) {
        Task { [weak self, weak item] in
            guard let self, let item else { return }
            do {
                guard let group = try await item.asset.loadMediaSelectionGroup(for: .audible),
                      self.player?.currentItem === item else { return }

                self.audioSelectionGroup = group
                self.audioOptions = Dictionary(uniqueKeysWithValues: group.options.enumerated().map { index, option in
                    let language = option.extendedLanguageTag ?? option.locale?.identifier
                    let id = "\(index)-\(language ?? option.displayName)"
                    return (id, option)
                })
                self.availableAudioTracks = group.options.enumerated().map { index, option in
                    let language = option.extendedLanguageTag ?? option.locale?.identifier
                    return AudioTrack(id: "\(index)-\(language ?? option.displayName)", label: option.displayName, languageCode: language)
                }
                if let selected = item.selectedMediaOption(in: group),
                   let selectedID = self.audioOptions.first(where: { $0.value === selected })?.key {
                    self.selectedAudioTrackID = selectedID
                }
            } catch {
                // Audio rendition metadata is optional; video playback remains usable without it.
                self.availableAudioTracks = []
            }
        }
    }

    private func handlePlaybackFailure(_ error: Error?) {
        isPlaying = false
        isBuffering = false
        shouldPlayWhenReady = false
        let reason = error?.localizedDescription ?? "The stream could not be played."
        playbackError = "Playback failed. \(reason)"
    }

    private func addTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            if let currentItem = self.player?.currentItem {
                let dur = currentItem.duration.seconds
                if !dur.isNaN && dur > 0 {
                    self.duration = dur
                }
            }

            self.updateSubtitleCue(for: self.currentTime)
            
            // Save progress periodically every 5 seconds
            if Int(self.currentTime) % 5 == 0 && self.currentTime > 0 {
                self.saveCurrentProgress()
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func updateSubtitleCue(for time: TimeInterval) {
        guard !parsedCues.isEmpty else {
            activeSubtitleCue = nil
            return
        }
        
        let matchingCue = parsedCues.first { time >= $0.startTime && time <= $0.endTime }
        activeSubtitleCue = matchingCue?.text
    }

    public func saveCurrentProgress() {
        WatchHistoryManager.shared.saveProgress(
            mediaItem: mediaItem,
            currentTime: currentTime,
            duration: duration,
            season: seasonNumber,
            episode: episodeNumber
        )
    }

    public func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isControlsVisible.toggle()
        }
        if isControlsVisible {
            resetHideControlsTimer()
        }
    }

    private func resetHideControlsTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isControlsVisible = false
                    }
                }
            }
        }
    }

    private func showGestureNotification(_ text: String) {
        gestureMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            Task { @MainActor [weak self] in
                if self?.gestureMessage == text {
                    self?.gestureMessage = nil
                }
            }
        }
    }
}
