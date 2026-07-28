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

            if viewModel.isBuffering && viewModel.playbackError == nil {
                ProgressView("Loading video…")
                    .tint(.white)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

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

            if let error = viewModel.playbackError {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    Button("Retry") {
                        viewModel.retryPlayback()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .padding(24)
                .frame(maxWidth: 340)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(24)
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
