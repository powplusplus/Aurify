import Foundation
import Combine

public struct WatchProgress: Identifiable, Codable, Hashable {
    public var id: String { "\(mediaItem.mediaType.rawValue)_\(mediaItem.id)_\(seasonNumber ?? 0)_\(episodeNumber ?? 0)" }
    public let mediaItem: MediaItem
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var seasonNumber: Int?
    public var episodeNumber: Int?
    public var lastWatchedDate: Date

    public var progressFraction: Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    public var isCompleted: Bool { progressFraction >= 0.95 }
    public var isContinueWatching: Bool { progressFraction >= 0.01 && progressFraction < 0.95 }

    public var formattedTimeRemaining: String {
        let remaining = max(duration - currentTime, 0)
        let minutes = Int(remaining) / 60
        return minutes > 0 ? "\(minutes)m left" : "Almost finished"
    }

    public init(
        mediaItem: MediaItem,
        currentTime: TimeInterval,
        duration: TimeInterval,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        lastWatchedDate: Date = Date()
    ) {
        self.mediaItem = mediaItem
        self.currentTime = currentTime
        self.duration = duration
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.lastWatchedDate = lastWatchedDate
    }
}

@MainActor
public final class WatchHistoryManager: ObservableObject {
    public static let shared = WatchHistoryManager()

    private let storageKey = "aurify_watch_history_v2"
    private let legacyStorageKey = "aurify_watch_history_v1"
    @Published public private(set) var history: [WatchProgress] = []

    private init() { loadHistory() }

    public var continueWatching: [WatchProgress] {
        history.filter(\.isContinueWatching)
    }

    public func getProgress(mediaId: Int, mediaType: MediaType? = nil, season: Int? = nil, episode: Int? = nil) -> WatchProgress? {
        history.first {
            $0.mediaItem.id == mediaId &&
            (mediaType == nil || $0.mediaItem.mediaType == mediaType) &&
            $0.seasonNumber == season &&
            $0.episodeNumber == episode
        }
    }

    public func saveProgress(
        mediaItem: MediaItem,
        currentTime: TimeInterval,
        duration: TimeInterval,
        season: Int? = nil,
        episode: Int? = nil
    ) {
        guard duration.isFinite, currentTime.isFinite, duration > 5, currentTime >= 0 else { return }
        let entry = WatchProgress(
            mediaItem: mediaItem,
            currentTime: min(currentTime, duration),
            duration: duration,
            seasonNumber: season,
            episodeNumber: episode
        )
        history.removeAll { $0.id == entry.id }
        history.insert(entry, at: 0)
        history = Array(history.prefix(100))
        persistHistory()
    }

    public func removeFromHistory(id: String) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    public func clearAllHistory() {
        history.removeAll()
        persistHistory()
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadHistory() {
        let defaults = UserDefaults.standard
        let data = defaults.data(forKey: storageKey) ?? defaults.data(forKey: legacyStorageKey)
        guard let data, let decoded = try? JSONDecoder().decode([WatchProgress].self, from: data) else { return }
        history = decoded.sorted { $0.lastWatchedDate > $1.lastWatchedDate }
        if defaults.data(forKey: storageKey) == nil { persistHistory() }
    }
}
