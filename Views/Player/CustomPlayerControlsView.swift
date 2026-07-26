import SwiftUI

public struct CustomPlayerControlsView: View {
    @ObservedObject public var viewModel: PlayerViewModel
    public let onClose: () -> Void

    public init(viewModel: PlayerViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            // Background translucent dark overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.toggleControlsVisibility()
                }

            VStack {
                // Top Control Bar
                HStack {
                    Button(action: {
                        viewModel.saveCurrentProgress()
                        onClose()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.mediaItem.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let s = viewModel.seasonNumber, let e = viewModel.episodeNumber {
                            Text("Season \(s) • Episode \(e)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.leading, 6)

                    Spacer()

                    // Subtitles Menu
                    Menu {
                        Button("Off") {
                            viewModel.selectSubtitleTrack(nil)
                        }
                        ForEach(viewModel.availableSubtitles) { track in
                            Button(track.label) {
                                viewModel.selectSubtitleTrack(track)
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.selectedSubtitleTrack == nil ? "captions.bubble" : "captions.bubble.fill")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.selectedSubtitleTrack == nil ? .white : .cyan)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    // Quality Menu
                    Menu {
                        ForEach(viewModel.availableSources) { source in
                            Button(source.quality.rawValue) {
                                viewModel.changeQuality(source)
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // Center Play/Pause & Skip Buttons
                HStack(spacing: 40) {
                    Button(action: { viewModel.skip(seconds: -10) }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.black)
                            .padding(22)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .white.opacity(0.4), radius: 15)
                    }

                    Button(action: { viewModel.skip(seconds: 10) }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                Spacer()

                // Bottom Timeline Scrubber & Duration
                VStack(spacing: 8) {
                    HStack {
                        Text(formatTime(viewModel.currentTime))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))

                        Slider(
                            value: Binding(
                                get: { viewModel.currentTime },
                                set: { newValue in viewModel.seek(to: newValue) }
                            ),
                            in: 0...max(viewModel.duration, 1.0)
                        )
                        .tint(.cyan)

                        Text(formatTime(viewModel.duration))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "00:00" }
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
