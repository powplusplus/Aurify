import Foundation
import Combine

@MainActor
public final class WatchlistManager: ObservableObject {
    public static let shared = WatchlistManager()
    @Published public private(set) var items: [MediaItem] = []
    private let storageKey = "aurify_watchlist_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([MediaItem].self, from: data) {
            items = saved
        }
    }

    public func contains(_ item: MediaItem) -> Bool {
        items.contains { $0.id == item.id && $0.mediaType == item.mediaType }
    }

    public func toggle(_ item: MediaItem) {
        if contains(item) {
            items.removeAll { $0.id == item.id && $0.mediaType == item.mediaType }
        } else {
            items.insert(item, at: 0)
        }
        persist()
    }

    public func clear() {
        items.removeAll()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
