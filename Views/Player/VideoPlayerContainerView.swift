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

    public init(
        mediaItem: MediaItem,
        stream: ResolvedMediaStream,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        onPlaybackFinished: (() -> Void)? = nil
    ) {
        self.onPlaybackFinished = onPlaybackFinished
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
                }
                .transition(.opacity)
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
    }
}
