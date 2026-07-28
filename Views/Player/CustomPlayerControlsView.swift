import SwiftUI
#if canImport(UIKit)
import AVKit

private struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.activeTintColor = .systemIndigo
        view.tintColor = .white
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif

public struct CustomPlayerControlsView: View {
    @ObservedObject public var viewModel: PlayerViewModel
    public let onClose: () -> Void

    public init(viewModel: PlayerViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { viewModel.toggleControlsVisibility() }

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerControls
                Spacer()
                timeline
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            controlButton(systemName: "xmark") {
                viewModel.saveCurrentProgress()
                onClose()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.mediaItem.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                if let season = viewModel.seasonNumber, let episode = viewModel.episodeNumber {
                    Text("Season \(season) · Episode \(episode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.activeProvider.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.white)

            Spacer()

            #if canImport(UIKit)
            AirPlayRouteButton()
                .frame(width: 42, height: 42)
                .padding(2)
                .background(.ultraThinMaterial, in: Circle())
                .accessibilityLabel("AirPlay")
            #endif

            Menu {
                Button("Off", systemImage: viewModel.selectedSubtitleTrack == nil ? "checkmark" : "captions.bubble") {
                    viewModel.selectSubtitleTrack(nil)
                }
                if !viewModel.availableSubtitles.isEmpty { Divider() }
                ForEach(viewModel.availableSubtitles) { track in
                    Button {
                        viewModel.selectSubtitleTrack(track)
                    } label: {
                        Label(track.label, systemImage: viewModel.selectedSubtitleTrack?.id == track.id ? "checkmark" : "captions.bubble")
                    }
                }
            } label: {
                playerMenuIcon(viewModel.selectedSubtitleTrack == nil ? "captions.bubble" : "captions.bubble.fill")
            }
            .accessibilityLabel("Subtitles")

            Menu {
                ForEach(viewModel.availableSources) { source in
                    Button {
                        viewModel.changeQuality(source)
                    } label: {
                        Label(source.name, systemImage: viewModel.activeSource?.id == source.id ? "checkmark" : "play.rectangle")
                    }
                }
            } label: {
                playerMenuIcon("gearshape.fill")
            }
            .accessibilityLabel("Quality")

            Menu {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { speed in
                    Button {
                        viewModel.setPlaybackSpeed(speed)
                    } label: {
                        Label(String(format: "%gx", speed), systemImage: viewModel.playbackSpeed == speed ? "checkmark" : "speedometer")
                    }
                }
            } label: {
                playerMenuIcon("speedometer")
            }
            .accessibilityLabel("Playback speed")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var centerControls: some View {
        HStack(spacing: 38) {
            controlButton(systemName: "gobackward.10", size: 28) { viewModel.skip(seconds: -10) }
            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 76, height: 76)
                    .background(.white, in: Circle())
                    .shadow(color: .white.opacity(0.25), radius: 20)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            controlButton(systemName: "goforward.10", size: 28) { viewModel.skip(seconds: 10) }
        }
    }

    private var timeline: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(get: { viewModel.currentTime }, set: { viewModel.seek(to: $0) }),
                in: 0...max(viewModel.duration, 1)
            )
            .tint(.indigo)
            .disabled(viewModel.duration <= 0)
            HStack {
                Text(formatTime(viewModel.currentTime))
                Spacer()
                if let source = viewModel.activeSource {
                    Text(source.name)
                }
                Spacer()
                Text("−\(formatTime(max(viewModel.duration - viewModel.currentTime, 0)))")
            }
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func playerMenuIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(.ultraThinMaterial, in: Circle())
    }

    private func controlButton(systemName: String, size: CGFloat = 17, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "00:00" }
        let total = max(Int(time), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
