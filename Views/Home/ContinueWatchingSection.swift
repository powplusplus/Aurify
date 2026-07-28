import SwiftUI

public struct ContinueWatchingSection: View {
    public let items: [WatchProgress]
    public let onSelect: (WatchProgress) -> Void

    public init(items: [WatchProgress], onSelect: @escaping (WatchProgress) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Label("Continue watching", systemImage: "clock.arrow.circlepath")
                    .font(.title3.bold())
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { progress in
                            Button { onSelect(progress) } label: {
                                card(progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private func card(_ progress: WatchProgress) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: progress.mediaItem.fullBackdropURL ?? progress.mediaItem.fullPosterURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [.indigo.opacity(0.45), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: 250, height: 142)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)

            Image(systemName: "play.circle.fill")
                .font(.system(size: 38))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(radius: 8)

            VStack(alignment: .leading, spacing: 5) {
                Text(progress.mediaItem.title).font(.subheadline.bold()).lineLimit(1)
                Text(progressLabel(progress)).font(.caption).foregroundStyle(Color.aurifyAccent)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(Color.aurifyAccent)
                            .frame(width: geometry.size.width * progress.progressFraction)
                    }
                }
                .frame(height: 4)
            }
            .padding(12)
        }
        .frame(width: 250, height: 142)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.14)))
    }

    private func progressLabel(_ progress: WatchProgress) -> String {
        if let season = progress.seasonNumber, let episode = progress.episodeNumber {
            return "S\(season) E\(episode) · \(progress.formattedTimeRemaining)"
        }
        return progress.formattedTimeRemaining
    }
}
