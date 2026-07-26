import Foundation
import Combine

public struct WatchProgress: Identifiable, Codable {
    public var id: String { "\(mediaItem.id)_\(seasonNumber ?? 0)_\(episodeNumber ?? 0)" }
    public let mediaItem: MediaItem
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var seasonNumber: Int?
    public var episodeNumber: Int?
    public var lastWatchedDate: Date

    public var progressFraction: Double {
        guard duration > 0 else { return 0.0 }
        return min(max(currentTime / duration, 0.0), 1.0)
    }

    public var formattedTimeRemaining: String {
        let remaining = max(duration - currentTime, 0)
        let mins = Int(remaining) / 60
        return "\(mins)m left"
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

public class WatchHistoryManager: ObservableObject {
    public static let shared = WatchHistoryManager()
    
    private let storageKey = "aurify_watch_history_v1"
    @Published public private(set) var history: [WatchProgress] = []

    private init() {
        loadHistory()
    }

    public func getProgress(mediaId: Int, season: Int? = nil, episode: Int? = nil) -> WatchProgress? {
        if let season = season, let episode = episode {
            return history.first { $0.mediaItem.id == mediaId && $0.seasonNumber == season && $0.episodeNumber == episode }
        }
        return history.first { $0.mediaItem.id == mediaId }
    }

    public func saveProgress(
        mediaItem: MediaItem,
        currentTime: TimeInterval,
        duration: TimeInterval,
        season: Int? = nil,
        episode: Int? = nil
    ) {
        guard duration > 5.0 else { return } // Avoid saving invalid micro-durations
        
        let newProgress = WatchProgress(
            mediaItem: mediaItem,
            currentTime: currentTime,
            duration: duration,
            seasonNumber: season,
            episodeNumber: episode,
            lastWatchedDate: Date()
        )

        // Remove existing entry for the same media item/episode
        history.removeAll { $0.id == newProgress.id }
        
        // Insert at the beginning (most recently watched first)
        history.insert(newProgress, at: 0)
        
        // Keep maximum 50 recent items
        if history.count > 50 {
            history = Array(history.prefix(50))
        }

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
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save watch history: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            self.history = try JSONDecoder().decode([WatchProgress].self, from: data)
        } catch {
            print("Failed to load watch history: \(error.localizedDescription)")
        }
    }
}
