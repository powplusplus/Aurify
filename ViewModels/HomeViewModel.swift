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
        // Observe watch history changes
        WatchHistoryManager.shared.$history
            .receive(on: DispatchQueue.main)
            .assign(to: &$continueWatching)
    }

    public func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let trending = TMDBService.shared.fetchTrending(mediaType: selectedMediaType)
            async let movies = TMDBService.shared.fetchPopular(mediaType: .movie)
            async let series = TMDBService.shared.fetchPopular(mediaType: .tv)
            async let topRated = TMDBService.shared.fetchTopRated(mediaType: selectedMediaType)

            self.trendingMedia = try await trending
            self.popularMovies = try await movies
            self.popularSeries = try await series
            self.topRatedMedia = try await topRated
        } catch {
            self.errorMessage = "Unable to load media content. Please check your internet connection."
        }
        
        isLoading = false
    }

    public func switchMediaType(_ type: MediaType) async {
        guard selectedMediaType != type else { return }
        selectedMediaType = type
        await loadContent()
    }
}
