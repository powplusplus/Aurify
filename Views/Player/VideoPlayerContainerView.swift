import SwiftUI
import AVKit

public struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    public let player: AVPlayer?

    public init(player: AVPlayer?) {
        self.player = player
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

public struct VideoPlayerContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlayerViewModel

    public init(
        mediaItem: MediaItem,
        stream: ResolvedMediaStream,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) {
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
                fontSize: CGFloat(UserSettings.shared.subtitleFontSize),
                backgroundOpacity: UserSettings.shared.subtitleBgOpacity
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
        }
        .statusBar(hidden: true)
        .onDisappear {
            viewModel.saveCurrentProgress()
            viewModel.player?.pause()
        }
    }
}
