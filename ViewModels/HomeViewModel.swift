import Foundation
import Combine

@MainActor
public class HomeViewModel: ObservableObject {
    @Published public var trendingMedia: [MediaItem] = []
    @Published public var popularMovies: [MediaItem] = []
    @Published public var popularSeries: [MediaItem] = []
    @Published public var topRatedMedia: [MediaItem] = []
    @Published public var continueWatching: [WatchProgress] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var selectedMediaType: MediaType = .movie

    private var cancellables = Set<AnyCancellable>()

    public init() {
        WatchHistoryManager.shared.$history
            .receive(on: DispatchQueue.main)
            .map { $0.filter(\.isContinueWatching) }
            .assign(to: &$continueWatching)
    }

    public func loadContent() async {
        isLoading = true
        errorMessage = nil

        let trendingTask = Task { try? await TMDBService.shared.fetchTrending(mediaType: selectedMediaType) }
        let moviesTask = Task { try? await TMDBService.shared.fetchPopular(mediaType: .movie) }
        let seriesTask = Task { try? await TMDBService.shared.fetchPopular(mediaType: .tv) }
        let topRatedTask = Task { try? await TMDBService.shared.fetchTopRated(mediaType: selectedMediaType) }
        let results = await (
            trendingTask.value,
            moviesTask.value,
            seriesTask.value,
            topRatedTask.value
        )

        trendingMedia = results.0 ?? []
        popularMovies = results.1 ?? []
        popularSeries = results.2 ?? []
        topRatedMedia = results.3 ?? []
        if trendingMedia.isEmpty && popularMovies.isEmpty && popularSeries.isEmpty && topRatedMedia.isEmpty {
            errorMessage = UserSettings.shared.hasTMDBCredential
                ? "The catalog could not be loaded. Check your connection or TMDB token."
                : CatalogError.missingCredential.localizedDescription
        }
        isLoading = false
    }

    public func switchMediaType(_ type: MediaType) async {
        guard selectedMediaType != type else { return }
        selectedMediaType = type
        await loadContent()
    }
}
