import SwiftUI

public struct LibraryView: View {
    private enum SectionChoice: String, CaseIterable, Identifiable {
        case watchlist = "Watchlist"
        case history = "History"
        var id: String { rawValue }
    }

    @ObservedObject private var watchlist = WatchlistManager.shared
    @ObservedObject private var history = WatchHistoryManager.shared
    @State private var selection: SectionChoice = .watchlist
    @State private var selectedMedia: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 145, maximum: 180), spacing: 16)]

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if currentItems.isEmpty {
                    ContentUnavailableView(
                        selection == .watchlist ? "Your watchlist is empty" : "Nothing watched yet",
                        systemImage: selection == .watchlist ? "bookmark" : "clock",
                        description: Text(selection == .watchlist ? "Save a title from its details page." : "Playback progress appears here automatically.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(currentItems, id: \.stableKey) { entry in
                                Button { selectedMedia = entry.item } label: {
                                    PosterCard(mediaItem: entry.item, progressFraction: entry.progress)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if selection == .watchlist {
                                        Button("Remove from Watchlist", systemImage: "bookmark.slash", role: .destructive) {
                                            watchlist.toggle(entry.item)
                                        }
                                    } else if let historyID = entry.historyID {
                                        Button("Remove from History", systemImage: "trash", role: .destructive) {
                                            history.removeFromHistory(id: historyID)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color.aurifyBackground)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Library section", selection: $selection) {
                        ForEach(SectionChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
            .sheet(item: $selectedMedia) { MediaDetailView(mediaItem: $0) }
        }
    }

    private var currentItems: [LibraryEntry] {
        if selection == .watchlist {
            return watchlist.items.map { LibraryEntry(item: $0, progress: nil, historyID: nil) }
        }
        return history.history.map { LibraryEntry(item: $0.mediaItem, progress: $0.progressFraction, historyID: $0.id) }
    }
}

private struct LibraryEntry {
    let item: MediaItem
    let progress: Double?
    let historyID: String?
    var stableKey: String { historyID ?? "\(item.mediaType.rawValue)-\(item.id)" }
}
