import SwiftUI

public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedMediaForDetail: MediaItem? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 175), spacing: 16)
    ]

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    
                    // Search Header & Input Box
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.5))

                            TextField("Search movies, TV series...", text: $viewModel.searchQuery)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .accentColor(.cyan)

                            if !viewModel.searchQuery.isEmpty {
                                Button(action: { viewModel.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Results or Loading or Empty State
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.cyan)
                        Spacer()
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No titles found for '\(viewModel.searchQuery)'")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    } else if viewModel.searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 48))
                                .foregroundColor(.cyan.opacity(0.6))
                            Text("Search Aurify")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Find your favorite movies, series, and anime instantly.")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.searchResults) { item in
                                    Button(action: { selectedMediaForDetail = item }) {
                                        PosterCard(mediaItem: item)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedMediaForDetail) { item in
                MediaDetailView(mediaItem: item)
            }
            .task {
                await viewModel.loadGenres()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
