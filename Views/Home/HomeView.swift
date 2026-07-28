import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedMedia: MediaItem?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.aurifyBackground.ignoresSafeArea()
                content
            }
            .sheet(item: $selectedMedia) { MediaDetailView(mediaItem: $0) }
            .task {
                if viewModel.trendingMedia.isEmpty { await viewModel.loadContent() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.trendingMedia.isEmpty {
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(.aurifyAccent)
                Text("Loading Aurify").foregroundStyle(.secondary)
            }
        } else if let error = viewModel.errorMessage, viewModel.trendingMedia.isEmpty {
            ContentUnavailableView {
                Label("Catalog unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await viewModel.loadContent() } }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header
                    if let hero = viewModel.trendingMedia.first { heroBanner(hero) }
                    ContinueWatchingSection(items: viewModel.continueWatching) { selectedMedia = $0.mediaItem }
                    mediaRail(title: "Trending now", items: viewModel.trendingMedia)
                    mediaRail(title: "Popular movies", items: viewModel.popularMovies)
                    mediaRail(title: "Popular series", items: viewModel.popularSeries)
                    mediaRail(title: "Top rated", items: viewModel.topRatedMedia)
                }
                .padding(.bottom, 36)
            }
            .refreshable { await viewModel.loadContent() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aurify")
                    .font(.largeTitle.bold())
                    .foregroundStyle(LinearGradient(colors: [.white, .indigo, .purple], startPoint: .leading, endPoint: .trailing))
                Text("Native cinema")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Media type", selection: Binding(
                get: { viewModel.selectedMediaType },
                set: { type in Task { await viewModel.switchMediaType(type) } }
            )) {
                Text("Movies").tag(MediaType.movie)
                Text("Series").tag(MediaType.tv)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func heroBanner(_ item: MediaItem) -> some View {
        Button { selectedMedia = item } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncImageBackdrop(url: item.fullBackdropURL ?? item.fullPosterURL, height: 300)
                LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text("SPOTLIGHT")
                        .font(.caption2.black())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.aurifyAccent, in: Capsule())
                    Text(item.title)
                        .font(.title.bold())
                        .lineLimit(2)
                    Text(item.overview)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                    Label("View details", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(.black)
                        .background(.white, in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(22)
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.13)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func mediaRail(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        Button { selectedMedia = item } label: { PosterCard(mediaItem: item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .foregroundStyle(.white)
    }
}
