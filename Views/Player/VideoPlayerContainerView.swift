import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
public struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    public let player: AVPlayer?

    public init(player: AVPlayer?) {
        self.player = player
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
#elseif canImport(AppKit)
import AppKit

public struct AVPlayerViewControllerRepresentable: NSViewRepresentable {
    public let player: AVPlayer?

    public init(player: AVPlayer?) {
        self.player = player
    }

    public func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }

    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
#endif

public struct VideoPlayerContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject private var settings = UserSettings.shared
    private let onPlaybackFinished: (() -> Void)?
    @State private var handledCompletion = false
    @State private var showProviderCarousel = false
    @State private var providerSelection: ServerProvider

    public init(
        mediaItem: MediaItem,
        stream: ResolvedMediaStream,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        onPlaybackFinished: (() -> Void)? = nil
    ) {
        self.onPlaybackFinished = onPlaybackFinished
        _providerSelection = State(initialValue: stream.activeProvider)
        _viewModel = StateObject(wrappedValue: PlayerViewModel(
            mediaItem: mediaItem,
            stream: stream,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber
        ))
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Native AVPlayer Layer
            AVPlayerViewControllerRepresentable(player: viewModel.player)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.toggleControlsVisibility()
                }

            // Subtitle Text Overlay
            SubtitleOverlayView(
                text: viewModel.activeSubtitleCue,
                fontSize: CGFloat(settings.subtitleFontSize),
                backgroundOpacity: settings.subtitleBgOpacity
            )

            // Gesture Alert Message Popup (e.g. +10s / -10s)
            if let gestureMsg = viewModel.gestureMessage {
                Text(gestureMsg)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
            }

            // Glass Controls Overlay
            if viewModel.isControlsVisible {
                CustomPlayerControlsView(viewModel: viewModel) {
                    dismiss()
                } onShowProviders: {
                    providerSelection = viewModel.activeProvider
                    withAnimation(.easeInOut(duration: 0.2)) { showProviderCarousel = true }
                }
                .transition(.opacity)
            }

            if showProviderCarousel {
                providerPickerOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let error = viewModel.errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    HStack {
                        Button("Close") { dismiss() }
                        Button("Sources") {
                            viewModel.dismissError()
                            providerSelection = viewModel.activeProvider
                            withAnimation(.easeInOut(duration: 0.2)) { showProviderCarousel = true }
                        }
                        Button("Retry") { viewModel.retry() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
                .frame(maxWidth: 420)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding()
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            #if canImport(UIKit)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            guard finished, !handledCompletion else { return }
            handledCompletion = true
            if settings.autoPlayNextEpisode { onPlaybackFinished?() }
        }
        .onChange(of: viewModel.activeProvider) { _, provider in
            providerSelection = provider
        }
    }

    private var providerPickerOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !viewModel.isResolvingProvider else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { showProviderCarousel = false }
                }

            GlassCard(cornerRadius: 28, padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Playback source")
                                .font(.title3.bold())
                            Text("Switch provider without leaving the native player")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showProviderCarousel = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isResolvingProvider)
                    }

                    ProviderCarousel(
                        selection: $providerSelection,
                        providers: ServerProvider.carouselProviders.filter { $0 != .zstreamAuto },
                        states: viewModel.providerStates,
                        isEnabled: !viewModel.isResolvingProvider
                    ) { provider in
                        Task {
                            await viewModel.changeProvider(provider)
                            if viewModel.activeProvider == provider {
                                withAnimation(.easeInOut(duration: 0.2)) { showProviderCarousel = false }
                            } else {
                                providerSelection = viewModel.activeProvider
                            }
                        }
                    }
                    .frame(height: 116)
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }
}
