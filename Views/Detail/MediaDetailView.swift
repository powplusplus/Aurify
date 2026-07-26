import SwiftUI

public struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DetailViewModel
    @State private var activeStreamForPlayer: ResolvedMediaStream? = nil
    @State private var isPlayerPresented: Bool = false
    @State private var selectedProvider: ServerProvider = UserSettings.shared.primaryProvider

    public init(mediaItem: MediaItem) {
        _viewModel = StateObject(wrappedValue: DetailViewModel(mediaItem: mediaItem))
    }

    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Header Backdrop Image & Close Button
                    ZStack(alignment: .topLeading) {
                        AsyncImageBackdrop(url: viewModel.mediaItem.fullBackdropURL ?? viewModel.mediaItem.fullPosterURL, height: 380)

                        // Close Modal Button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)
                    }

                    // Content Container
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Title & Tags
                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.mediaItem.title)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            HStack(spacing: 10) {
                                Text(viewModel.mediaItem.displayDate)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))

                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))

                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", viewModel.mediaItem.voteAverage))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }

                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))

                                Text(viewModel.mediaItem.mediaType.displayName.uppercased())
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }

                        // Play Stream CTA Button
                        Button(action: {
                            Task {
                                if let stream = await viewModel.prepareStreamForPlayback(provider: selectedProvider) {
                                    self.activeStreamForPlayer = stream
                                    self.isPlayerPresented = true
                                }
                            }
                        }) {
                            HStack(spacing: 10) {
                                if viewModel.isResolvingStream {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18))
                                    Text("Start Streaming")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.white.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .disabled(viewModel.isResolvingStream)

                        // Provider Choice Switcher
                        HStack {
                            Text("Server Provider")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Picker("Provider", selection: $selectedProvider) {
                                ForEach(ServerProvider.allCases) { prov in
                                    Text(prov.rawValue).tag(prov)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .tint(.cyan)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

                        // TV Show Episode Selector
                        if viewModel.mediaItem.mediaType == .tv, let totalS = viewModel.detailedItem?.numberOfSeasons ?? viewModel.mediaItem.numberOfSeasons {
                            SeasonEpisodeSelector(
                                totalSeasons: totalS,
                                selectedSeasonNumber: $viewModel.selectedSeasonNumber,
                                episodes: viewModel.currentSeasonEpisodes,
                                selectedEpisode: $viewModel.selectedEpisode
                            ) { newSeason in
                                Task {
                                    await viewModel.loadSeason(number: newSeason)
                                }
                            }
                        }

                        // Synopsis / Overview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Storyline")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(viewModel.mediaItem.overview.isEmpty ? "No detailed synopsis available for this title." : viewModel.mediaItem.overview)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(5)
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task {
            await viewModel.loadDetails()
        }
        .fullScreenCover(isPresented: $isPlayerPresented) {
            if let stream = activeStreamForPlayer {
                VideoPlayerContainerView(
                    mediaItem: viewModel.mediaItem,
                    stream: stream,
                    seasonNumber: viewModel.mediaItem.mediaType == .tv ? viewModel.selectedSeasonNumber : nil,
                    episodeNumber: viewModel.mediaItem.mediaType == .tv ? (viewModel.selectedEpisode?.episodeNumber ?? 1) : nil
                )
            }
        }
    }
}
