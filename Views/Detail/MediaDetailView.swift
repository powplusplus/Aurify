import SwiftUI

public struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DetailViewModel
    @ObservedObject private var watchlist = WatchlistManager.shared
    @ObservedObject private var history = WatchHistoryManager.shared
    @State private var streamForPlayer: ResolvedMediaStream?
    @State private var showPlayer = false
    @State private var selectedProvider = UserSettings.shared.primaryProvider

    public init(mediaItem: MediaItem) {
        _viewModel = StateObject(wrappedValue: DetailViewModel(mediaItem: mediaItem))
    }

    public var body: some View {
        ZStack {
            Color.aurifyBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    details
                }
            }
        }
        .task { await viewModel.loadDetails() }
        .fullScreenCover(isPresented: $showPlayer) {
            if let streamForPlayer {
                VideoPlayerContainerView(
                    mediaItem: viewModel.mediaItem,
                    stream: streamForPlayer,
                    seasonNumber: viewModel.mediaItem.mediaType == .tv ? viewModel.selectedSeasonNumber : nil,
                    episodeNumber: viewModel.mediaItem.mediaType == .tv ? viewModel.selectedEpisode?.episodeNumber : nil,
                    onPlaybackFinished: viewModel.mediaItem.mediaType == .tv ? { Task { await playNextEpisode() } } : nil
                )
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            AsyncImageBackdrop(
                url: viewModel.mediaItem.fullBackdropURL ?? viewModel.mediaItem.fullPosterURL,
                height: 390,
                contentMode: .fit
            )
            HStack {
                circleButton("xmark") { dismiss() }
                Spacer()
                circleButton(watchlist.contains(viewModel.mediaItem) ? "bookmark.fill" : "bookmark") {
                    watchlist.toggle(viewModel.mediaItem)
                }
                .accessibilityLabel(watchlist.contains(viewModel.mediaItem) ? "Remove from Watchlist" : "Add to Watchlist")
            }
            .padding(20)
        }
        .frame(height: 390)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.detailedItem?.title ?? viewModel.mediaItem.title)
                    .font(.largeTitle.bold())
                HStack(spacing: 10) {
                    Text(viewModel.mediaItem.displayDate)
                    Label(String(format: "%.1f", viewModel.mediaItem.voteAverage), systemImage: "star.fill")
                        .symbolRenderingMode(.multicolor)
                    Text(viewModel.mediaItem.mediaType == .movie ? "Movie" : "Series")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                if let tagline = viewModel.detailedItem?.tagline, !tagline.isEmpty {
                    Text(tagline).font(.headline).foregroundStyle(.secondary)
                }
            }

            Button { Task { await play() } } label: {
                HStack {
                    if viewModel.isResolvingStream { ProgressView().tint(.black) }
                    else { Image(systemName: resumeProgress == nil ? "play.fill" : "play.fill") }
                    Text(resumeProgress == nil ? "Play" : "Resume")
                    if let resumeProgress { Text("· \(Int(resumeProgress.progressFraction * 100))%").foregroundStyle(.secondary) }
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(viewModel.isResolvingStream || (viewModel.mediaItem.mediaType == .tv && viewModel.selectedEpisode == nil))

            GlassCard(cornerRadius: 18, padding: 12) {
                HStack {
                    Label("Source", systemImage: selectedProvider.iconName)
                    Spacer()
                    Picker("Source", selection: $selectedProvider) {
                        ForEach(ServerProvider.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                }
            }

            if viewModel.mediaItem.mediaType == .tv,
               let count = viewModel.detailedItem?.numberOfSeasons ?? viewModel.mediaItem.numberOfSeasons {
                SeasonEpisodeSelector(
                    totalSeasons: count,
                    selectedSeasonNumber: $viewModel.selectedSeasonNumber,
                    episodes: viewModel.currentSeasonEpisodes,
                    selectedEpisode: $viewModel.selectedEpisode
                ) { season in
                    Task { await viewModel.loadSeason(number: season) }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("Storyline").font(.title3.bold())
                Text(viewModel.detailedItem?.overview.nonEmpty ?? viewModel.mediaItem.overview.nonEmpty ?? "No synopsis is available for this title.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private var resumeProgress: WatchProgress? {
        history.getProgress(
            mediaId: viewModel.mediaItem.id,
            mediaType: viewModel.mediaItem.mediaType,
            season: viewModel.mediaItem.mediaType == .tv ? viewModel.selectedSeasonNumber : nil,
            episode: viewModel.mediaItem.mediaType == .tv ? viewModel.selectedEpisode?.episodeNumber : nil
        )
    }

    private func play() async {
        if let stream = await viewModel.prepareStreamForPlayback(provider: selectedProvider) {
            streamForPlayer = stream
            showPlayer = true
        }
    }

    private func playNextEpisode() async {
        guard viewModel.mediaItem.mediaType == .tv, let current = viewModel.selectedEpisode else { return }
        if let index = viewModel.currentSeasonEpisodes.firstIndex(where: { $0.id == current.id }),
           viewModel.currentSeasonEpisodes.indices.contains(index + 1) {
            viewModel.selectedEpisode = viewModel.currentSeasonEpisodes[index + 1]
        } else {
            let total = viewModel.detailedItem?.numberOfSeasons ?? viewModel.mediaItem.numberOfSeasons ?? viewModel.selectedSeasonNumber
            guard viewModel.selectedSeasonNumber < total else { return }
            await viewModel.loadSeason(number: viewModel.selectedSeasonNumber + 1)
            guard viewModel.selectedEpisode != nil else { return }
        }

        showPlayer = false
        try? await Task.sleep(nanoseconds: 500_000_000)
        if let stream = await viewModel.prepareStreamForPlayback(provider: selectedProvider) {
            streamForPlayer = stream
            showPlayer = true
        }
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
