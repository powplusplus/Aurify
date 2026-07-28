import SwiftUI

public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedMedia: MediaItem?
    private let columns = [GridItem(.adaptive(minimum: 145, maximum: 180), spacing: 16)]

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.searchResults.isEmpty {
                    ProgressView("Searching…").controlSize(.large)
                } else if let error = viewModel.errorMessage, viewModel.searchResults.isEmpty {
                    ContentUnavailableView("Search unavailable", systemImage: "exclamationmark.magnifyingglass", description: Text(error))
                } else if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Find something to watch", systemImage: "sparkles.tv", description: Text("Search movies and series from the Z-Stream catalog."))
                } else if viewModel.searchResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.searchResults) { item in
                                Button { selectedMedia = item } label: { PosterCard(mediaItem: item) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.aurifyBackground)
            .navigationTitle("Search")
            .searchable(text: $viewModel.searchQuery, prompt: "Movies and TV series")
            .sheet(item: $selectedMedia) { MediaDetailView(mediaItem: $0) }
        }
    }
}
