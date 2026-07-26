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
    
    // Subtitles state
    @Published public var availableSubtitles: [SubtitleTrack] = []
    @Published public var selectedSubtitleTrack: SubtitleTrack?
    @Published public var activeSubtitleCue: String? = nil
    private var parsedCues: [SubtitleCue] = []
    
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
    private var hideControlsTimer: Timer?
    
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

        if let initialSource = stream.sources.first {
            self.activeSource = initialSource
            setupPlayer(with: initialSource.url)
        }
        
        // Auto-select preferred subtitle language if available
        let prefLang = UserSettings.shared.preferredSubtitleLanguage.lowercased()
        if let defaultTrack = stream.subtitles.first(where: { $0.language.lowercased().contains(prefLang) }) ?? stream.subtitles.first {
            selectSubtitleTrack(defaultTrack)
        }
        
        // Restore progress if available
        if let saved = WatchHistoryManager.shared.getProgress(mediaId: mediaItem.id, season: seasonNumber, episode: episodeNumber) {
            seek(to: saved.currentTime)
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

    public func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        addTimeObserver()
        player?.play()
        isPlaying = true
    }

    public func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
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
        let currentPos = currentTime
        setupPlayer(with: source.url)
        seek(to: currentPos)
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
