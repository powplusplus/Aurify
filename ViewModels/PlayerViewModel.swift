import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
public final class PlayerViewModel: ObservableObject {
    @Published public private(set) var player: AVPlayer?
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public var isControlsVisible = true
    @Published public private(set) var isBuffering = true
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isFinished = false

    @Published public private(set) var availableSubtitles: [SubtitleTrack]
    @Published public private(set) var selectedSubtitleTrack: SubtitleTrack?
    @Published public private(set) var activeSubtitleCue: String?
    @Published public private(set) var availableAudioTracks: [AudioTrack] = []
    @Published public private(set) var selectedAudioTrackID: String?
    @Published public private(set) var availableSources: [StreamSource]
    @Published public private(set) var activeSource: StreamSource?
    @Published public private(set) var activeProvider: ServerProvider
    @Published public private(set) var providerStates: [ServerProvider: ProviderResolutionState]
    @Published public private(set) var isResolvingProvider = false
    @Published public private(set) var playbackSpeed: Double
    @Published public var gestureMessage: String?

    public let mediaItem: MediaItem
    public let seasonNumber: Int?
    public let episodeNumber: Int?

    private var parsedCues: [SubtitleCue] = []
    private var timeObserverToken: Any?
    private var playerCancellables = Set<AnyCancellable>()
    private var itemCancellables = Set<AnyCancellable>()
    private var hideControlsTimer: Timer?
    private var pendingResumeTime: TimeInterval?
    private var lastProgressSaveTime: TimeInterval = -20
    private var audioSelectionGroup: AVMediaSelectionGroup?
    private var audioOptions: [String: AVMediaSelectionOption] = [:]
    private var fallbackProviders: [ServerProvider]
    private var isAttemptingAutomaticFallback = false

    public init(mediaItem: MediaItem, stream: ResolvedMediaStream, seasonNumber: Int? = nil, episodeNumber: Int? = nil) {
        self.mediaItem = mediaItem
        self.availableSources = stream.sources
        self.availableSubtitles = stream.subtitles
        self.activeProvider = stream.activeProvider
        self.providerStates = Dictionary(uniqueKeysWithValues: ServerProvider.allCases.map {
            ($0, $0 == stream.activeProvider ? ProviderResolutionState.available : ProviderResolutionState.idle)
        })
        self.fallbackProviders = stream.fallbackProviders
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.playbackSpeed = UserSettings.shared.playbackSpeed

        if let saved = WatchHistoryManager.shared.getProgress(
            mediaId: mediaItem.id,
            mediaType: mediaItem.mediaType,
            season: seasonNumber,
            episode: episodeNumber
        ), saved.isContinueWatching {
            pendingResumeTime = saved.currentTime
            currentTime = saved.currentTime
        }

        let preferredQuality = UserSettings.shared.defaultQuality
        let initialSource = stream.sources.first(where: { $0.quality == preferredQuality }) ?? stream.sources.first
        if let initialSource {
            activeSource = initialSource
            installPlayer(source: initialSource, autoplay: true)
        }

        if UserSettings.shared.subtitlesEnabled {
            let preferred = UserSettings.shared.preferredSubtitleLanguage.lowercased()
            let track = stream.subtitles.first { $0.language.lowercased() == preferred }
            if let track { selectSubtitleTrack(track) }
        }
        resetHideControlsTimer()
    }

    deinit {
        MainActor.assumeIsolated { cleanup() }
    }

    public func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.playImmediately(atRate: Float(playbackSpeed))
        }
        isPlaying.toggle()
        resetHideControlsTimer()
    }

    public func seek(to time: TimeInterval) {
        guard let player, time.isFinite else { return }
        let clamped = min(max(time, 0), duration > 0 ? duration : time)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        updateSubtitleCue(for: clamped)
        resetHideControlsTimer()
    }

    public func skip(seconds: TimeInterval) {
        seek(to: currentTime + seconds)
        showGestureNotification(seconds > 0 ? "+\(Int(seconds))s" : "\(Int(seconds))s")
    }

    public func selectSubtitleTrack(_ track: SubtitleTrack?) {
        selectedSubtitleTrack = track
        parsedCues = []
        activeSubtitleCue = nil
        guard let track else { return }
        Task {
            do {
                let cues = try await SubtitleParser.shared.fetchAndParse(url: track.url)
                guard selectedSubtitleTrack?.id == track.id else { return }
                parsedCues = cues
                updateSubtitleCue(for: currentTime)
            } catch {
                errorMessage = "Subtitles could not be loaded: \(error.localizedDescription)"
            }
        }
    }

    public func selectAudioTrack(_ track: AudioTrack) {
        guard let group = audioSelectionGroup,
              let option = audioOptions[track.id] else { return }
        player?.currentItem?.select(option, in: group)
        selectedAudioTrackID = track.id
        resetHideControlsTimer()
    }

    public func changeQuality(_ source: StreamSource) {
        guard activeSource?.id != source.id else { return }
        let resume = currentTime
        activeSource = source
        pendingResumeTime = resume
        installPlayer(source: source, autoplay: isPlaying)
    }

    @discardableResult
    public func changeProvider(_ provider: ServerProvider, autoplay: Bool? = nil) async -> Bool {
        guard provider != .zstreamAuto,
              provider != activeProvider,
              !isResolvingProvider else { return false }

        isResolvingProvider = true
        providerStates[provider] = .searching
        let resume = currentTime
        let shouldAutoplay = autoplay ?? isPlaying
        do {
            let stream = try await StreamResolver.shared.resolveStream(
                tmdbId: mediaItem.id,
                mediaType: mediaItem.mediaType,
                season: seasonNumber,
                episode: episodeNumber,
                preferredProvider: provider
            )
            guard let source = stream.sources.first(where: { $0.quality == UserSettings.shared.defaultQuality })
                    ?? stream.sources.first else {
                throw StreamResolverError.noPlayableSource
            }

            if case .unavailable? = providerStates[activeProvider] {
                // Preserve the failed state so the source sheet explains the automatic switch.
            } else {
                providerStates[activeProvider] = .idle
            }
            providerStates[provider] = .available
            availableSources = stream.sources
            availableSubtitles = stream.subtitles
            activeProvider = stream.activeProvider
            fallbackProviders.removeAll { $0 == provider }
            activeSource = source
            selectedSubtitleTrack = nil
            parsedCues = []
            activeSubtitleCue = nil
            pendingResumeTime = resume
            installPlayer(source: source, autoplay: shouldAutoplay)

            if UserSettings.shared.subtitlesEnabled {
                let preferred = UserSettings.shared.preferredSubtitleLanguage.lowercased()
                if let track = stream.subtitles.first(where: { $0.language.lowercased() == preferred }) {
                    selectSubtitleTrack(track)
                }
            }
            showGestureNotification("Playing from \(provider.rawValue)")
            isResolvingProvider = false
            return true
        } catch {
            providerStates[provider] = .unavailable(error.localizedDescription)
            showGestureNotification("\(provider.rawValue) unavailable")
        }
        isResolvingProvider = false
        return false
    }

    public func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        UserSettings.shared.playbackSpeed = speed
        if isPlaying { player?.rate = Float(speed) }
    }

    public func retry() {
        guard let activeSource else { return }
        pendingResumeTime = currentTime
        errorMessage = nil
        installPlayer(source: activeSource, autoplay: true)
    }

    public func saveCurrentProgress() {
        WatchHistoryManager.shared.saveProgress(
            mediaItem: mediaItem,
            currentTime: currentTime,
            duration: duration,
            season: seasonNumber,
            episode: episodeNumber
        )
        lastProgressSaveTime = currentTime
    }

    public func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.2)) { isControlsVisible.toggle() }
        if isControlsVisible { resetHideControlsTimer() }
    }

    public func dismissError() { errorMessage = nil }

    public func cleanup() {
        saveCurrentProgress()
        player?.pause()
        hideControlsTimer?.invalidate()
        if let timeObserverToken, let player {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        itemCancellables.removeAll()
        playerCancellables.removeAll()
    }

    private func installPlayer(source: StreamSource, autoplay: Bool) {
        itemCancellables.removeAll()
        availableAudioTracks = []
        selectedAudioTrackID = nil
        audioSelectionGroup = nil
        audioOptions = [:]
        if let timeObserverToken, let player {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        var options: [String: Any] = [
            "AVURLAssetAllowsCellularAccessKey": UserSettings.shared.allowsCellularStreaming
        ]
        if !source.headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = source.headers
        }
        let asset = AVURLAsset(url: source.url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 8

        let nextPlayer = player ?? AVPlayer()
        nextPlayer.automaticallyWaitsToMinimizeStalling = true
        nextPlayer.preventsDisplaySleepDuringVideoPlayback = true
        nextPlayer.replaceCurrentItem(with: item)
        player = nextPlayer
        observe(player: nextPlayer, item: item)
        addTimeObserver(to: nextPlayer)

        if autoplay {
            nextPlayer.playImmediately(atRate: Float(playbackSpeed))
            isPlaying = true
        }
    }

    private func observe(player: AVPlayer, item: AVPlayerItem) {
        playerCancellables.removeAll()
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
                self?.isPlaying = status == .playing
            }
            .store(in: &playerCancellables)

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .readyToPlay {
                    self.loadAudioTracks(from: item)
                } else if status == .failed {
                    self.handlePlaybackFailure(
                        item.error?.localizedDescription ?? "This source could not be played."
                    )
                }
            }
            .store(in: &itemCancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self.handlePlaybackFailure(error?.localizedDescription ?? "This source stopped playing.")
            }
            .store(in: &itemCancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isFinished = true
                self.isPlaying = false
                self.saveCurrentProgress()
                self.isControlsVisible = true
            }
            .store(in: &itemCancellables)
    }

    private func loadAudioTracks(from item: AVPlayerItem) {
        Task { [weak self, weak item] in
            guard let self, let item else { return }
            do {
                guard let group = try await item.asset.loadMediaSelectionGroup(for: .audible),
                      self.player?.currentItem === item else { return }

                let options = Dictionary(uniqueKeysWithValues: group.options.enumerated().map { index, option in
                    let language = option.extendedLanguageTag ?? option.locale?.identifier
                    let id = "\(index)-\(language ?? option.displayName)"
                    return (id, option)
                })
                self.audioSelectionGroup = group
                self.audioOptions = options
                self.availableAudioTracks = group.options.enumerated().map { index, option in
                    let language = option.extendedLanguageTag ?? option.locale?.identifier
                    return AudioTrack(
                        id: "\(index)-\(language ?? option.displayName)",
                        label: option.displayName,
                        languageCode: language
                    )
                }
                if let selected = item.selectedMediaOption(in: group),
                   let selectedID = options.first(where: { $0.value === selected })?.key {
                    self.selectedAudioTrackID = selectedID
                }
            } catch {
                self.availableAudioTracks = []
            }
        }
    }

    private func handlePlaybackFailure(_ message: String) {
        isBuffering = false
        isPlaying = false
        if isResolvingProvider || isAttemptingAutomaticFallback { return }
        providerStates[activeProvider] = .unavailable(message)
        guard !fallbackProviders.isEmpty else {
            errorMessage = message
            return
        }

        let provider = fallbackProviders.removeFirst()
        isAttemptingAutomaticFallback = true
        gestureMessage = "Trying \(provider.rawValue)…"
        Task { [weak self] in
            guard let self else { return }
            let switched = await self.changeProvider(provider, autoplay: true)
            self.isAttemptingAutomaticFallback = false
            if !switched { self.handlePlaybackFailure(message) }
        }
    }

    private func addTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite { self.currentTime = seconds }
            if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
                self.duration = itemDuration
                if let resume = self.pendingResumeTime {
                    self.pendingResumeTime = nil
                    self.seek(to: resume)
                }
            }
            self.updateSubtitleCue(for: self.currentTime)
            if self.currentTime - self.lastProgressSaveTime >= 10 { self.saveCurrentProgress() }
        }
    }

    private func updateSubtitleCue(for time: TimeInterval) {
        guard !parsedCues.isEmpty else { activeSubtitleCue = nil; return }
        var low = 0
        var high = parsedCues.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let cue = parsedCues[mid]
            if time < cue.startTime { high = mid - 1 }
            else if time > cue.endTime { low = mid + 1 }
            else { activeSubtitleCue = cue.text; return }
        }
        activeSubtitleCue = nil
    }

    private func resetHideControlsTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                withAnimation(.easeInOut(duration: 0.25)) { self.isControlsVisible = false }
            }
        }
    }

    private func showGestureNotification(_ text: String) {
        gestureMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if gestureMessage == text { gestureMessage = nil }
        }
    }
}
