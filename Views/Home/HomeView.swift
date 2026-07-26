import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedMediaForDetail: MediaItem? = nil
    @State private var selectedCategory: String = "All"
    
    let categories = ["All", "Action", "Sci-Fi", "Drama", "Animation", "Comedy", "Thriller"]

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                // Background color palette
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.trendingMedia.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.cyan)
                        Text("Loading Aurify...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // Top Bar Header
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AURIFY")
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.cyan, .blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    Text("iOS 27 Vision Edition")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.4))
                                }

                                Spacer()

                                // Media type switcher (Movies / TV)
                                HStack(spacing: 4) {
                                    ForEach(MediaType.allCases) { type in
                                        Button(action: {
                                            Task {
                                                await viewModel.switchMediaType(type)
                                            }
                                        }) {
                                            Text(type.displayName)
                                                .font(.system(size: 12, weight: viewModel.selectedMediaType == type ? .bold : .medium, design: .rounded))
                                                .foregroundColor(viewModel.selectedMediaType == type ? .black : .white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    ZStack {
                                                        if viewModel.selectedMediaType == type {
                                                            Capsule().fill(Color.white)
                                                        } else {
                                                            Capsule().fill(Color.clear)
                                                        }
                                                    }
                                                )
                                        }
                                    }
                                }
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                            // Category Filter Pills
                            CategoryPills(categories: categories, selectedCategory: $selectedCategory)

                            // Hero Banner Carousel
                            if let heroItem = viewModel.trendingMedia.first {
                                heroBannerView(heroItem)
                            }

                            // Continue Watching Row
                            ContinueWatchingSection(items: viewModel.continueWatching) { progress in
                                selectedMediaForDetail = progress.mediaItem
                            }

                            // Trending Rail
                            mediaRail(title: "🔥 Trending Right Now", items: viewModel.trendingMedia)

                            // Popular Movies Rail
                            mediaRail(title: "🍿 Popular Movies", items: viewModel.popularMovies)

                            // Popular TV Series Rail
                            mediaRail(title: "📺 Top TV Series", items: viewModel.popularSeries)

                            // Top Rated Rail
                            mediaRail(title: "⭐ Top Rated Masterpieces", items: viewModel.topRatedMedia)
                        }
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await viewModel.loadContent()
                    }
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .sheet(item: $selectedMediaForDetail) { item in
                MediaDetailView(mediaItem: item)
            }
            .task {
                if viewModel.trendingMedia.isEmpty {
                    await viewModel.loadContent()
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }

    private func heroBannerView(_ item: MediaItem) -> some View {
        Button(action: { selectedMediaForDetail = item }) {
            ZStack(alignment: .bottomLeading) {
                AsyncImageBackdrop(url: item.fullBackdropURL, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("SPOTLIGHT")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan)
                            .clipShape(Capsule())

                        Spacer()
                    }

                    Text(item.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(item.overview)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("Watch Now")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", item.voteAverage))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(height: 280)
            .padding(.horizontal, 20)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .padding(.horizontal, 20)
            )
            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func mediaRail(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        Button(action: { selectedMediaForDetail = item }) {
                            PosterCard(mediaItem: item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
