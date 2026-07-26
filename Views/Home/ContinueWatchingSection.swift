import SwiftUI

public struct ContinueWatchingSection: View {
    public let items: [WatchProgress]
    public let onSelect: (WatchProgress) -> Void

    public init(items: [WatchProgress], onSelect: @escaping (WatchProgress) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
        guard !items.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Continue Watching")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(items) { progress in
                            Button(action: { onSelect(progress) }) {
                                ZStack(alignment: .bottomLeading) {
                                    AsyncImage(url: progress.mediaItem.fullBackdropURL ?? progress.mediaItem.fullPosterURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        default:
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 240, height: 135)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                    // Dark gradient overlay
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                    // Center play button
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 8)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                    // Bottom details & progress
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(progress.mediaItem.title)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        if let s = progress.seasonNumber, let e = progress.episodeNumber {
                                            Text("S\(s) E\(e) • \(progress.formattedTimeRemaining)")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.cyan)
                                        } else {
                                            Text(progress.formattedTimeRemaining)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.cyan)
                                        }

                                        // Progress bar
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.3))
                                                .frame(height: 4)
                                            Capsule()
                                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: max(220 * CGFloat(progress.progressFraction), 8), height: 4)
                                        }
                                    }
                                    .padding(12)
                                }
                                .frame(width: 240, height: 135)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        )
    }
}
