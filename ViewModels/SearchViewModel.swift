import Foundation
import Combine

@MainActor
public class SearchViewModel: ObservableObject {
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [MediaItem] = []
    @Published public var genres: [Genre] = []
    @Published public var selectedGenre: Genre? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    public init() {
        // Setup search query debouncer (350ms)
        $searchQuery
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchTask?.cancel()
                self?.searchTask = Task { [weak self] in
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    public func loadGenres() async {
        do {
            let fetched = try await TMDBService.shared.fetchGenres(mediaType: .movie)
            self.genres = fetched
        } catch {
            print("Failed to load genres: \(error.localizedDescription)")
        }
    }

    public func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.searchResults = []
            self.errorMessage = nil
            self.isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let results = try await TMDBService.shared.searchMedia(query: query)
            guard !Task.isCancelled else { return }
            self.searchResults = results
        } catch {
            guard !Task.isCancelled else { return }
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func filterByGenre(_ genre: Genre?) {
        selectedGenre = genre
    }
}
