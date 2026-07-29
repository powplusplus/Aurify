import Foundation
import Combine

@MainActor
public class DetailViewModel: ObservableObject {
    @Published public var mediaItem: MediaItem
    @Published public var detailedItem: MediaItem?
    @Published public var seasons: [SeasonDetail] = []
    @Published public var selectedSeasonNumber: Int = 1
    @Published public var currentSeasonEpisodes: [Episode] = []
    @Published public var selectedEpisode: Episode?
    @Published public var isLoading: Bool = false
    @Published public var isResolvingStream: Bool = false
    @Published public var resolvedStream: ResolvedMediaStream?
    @Published public var errorMessage: String? = nil
    @Published public private(set) var providerStates: [ServerProvider: ProviderResolutionState] =
        Dictionary(uniqueKeysWithValues: ServerProvider.allCases.map { ($0, ProviderResolutionState.idle) })
    @Published public private(set) var resolvingProvider: ServerProvider?
    
    public init(mediaItem: MediaItem) {
        self.mediaItem = mediaItem
    }

    public func loadDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let detail = try await TMDBService.shared.fetchDetail(id: mediaItem.id, mediaType: mediaItem.mediaType)
            self.detailedItem = detail
            
            if mediaItem.mediaType == .tv, let totalSeasons = detail.numberOfSeasons, totalSeasons > 0 {
                self.selectedSeasonNumber = 1
                await loadSeason(number: 1)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    public func loadSeason(number: Int) async {
        selectedSeasonNumber = number
        do {
            let season = try await TMDBService.shared.fetchSeasonDetail(tvId: mediaItem.id, seasonNumber: number)
            self.currentSeasonEpisodes = season.episodes
            self.selectedEpisode = season.episodes.first
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func prepareStreamForPlayback(provider: ServerProvider = UserSettings.shared.primaryProvider) async -> ResolvedMediaStream? {
        isResolvingStream = true
        errorMessage = nil
        
        let seasonNum = mediaItem.mediaType == .tv ? selectedSeasonNumber : nil
        let epNum = mediaItem.mediaType == .tv ? (selectedEpisode?.episodeNumber ?? 1) : nil

        let candidates: [ServerProvider]
        if provider == .zstreamAuto {
            candidates = ServerProvider.nativePlaybackOrder
                + (UserSettings.shared.customResolverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [.custom])
        } else {
            candidates = [provider]
        }

        providerStates = Dictionary(uniqueKeysWithValues: ServerProvider.allCases.map {
            ($0, ProviderResolutionState.idle)
        })
        if provider == .zstreamAuto { providerStates[.zstreamAuto] = .searching }
        var failures: [String] = []

        for (index, candidate) in candidates.enumerated() {
            resolvingProvider = candidate
            providerStates[candidate] = .searching
            do {
                let stream = try await StreamResolver.shared.resolveStream(
                    tmdbId: mediaItem.id,
                    mediaType: mediaItem.mediaType,
                    season: seasonNum,
                    episode: epNum,
                    preferredProvider: candidate
                )
                let playbackStream = ResolvedMediaStream(
                    sources: stream.sources,
                    subtitles: stream.subtitles,
                    activeProvider: stream.activeProvider,
                    fallbackProviders: provider == .zstreamAuto
                        ? Array(candidates.dropFirst(index + 1))
                        : []
                )
                providerStates[candidate] = .available
                if provider == .zstreamAuto { providerStates[.zstreamAuto] = .available }
                resolvedStream = playbackStream
                resolvingProvider = nil
                isResolvingStream = false
                return playbackStream
            } catch {
                failures.append("\(candidate.rawValue): \(error.localizedDescription)")
                providerStates[candidate] = .unavailable(error.localizedDescription)
            }
        }

        if provider == .zstreamAuto {
            providerStates[.zstreamAuto] = .unavailable("No provider returned a playable stream.")
        }
        resolvingProvider = nil
        errorMessage = failures.isEmpty
            ? StreamResolverError.noPlayableSource.localizedDescription
            : failures.joined(separator: "\n")
        isResolvingStream = false
        return nil
    }
}
