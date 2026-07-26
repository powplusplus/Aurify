import SwiftUI

public struct PosterCard: View {
    public let mediaItem: MediaItem
    public let progressFraction: Double?
    public let width: CGFloat
    public let height: CGFloat

    public init(
        mediaItem: MediaItem,
        progressFraction: Double? = nil,
        width: CGFloat = 145,
        height: CGFloat = 215
    ) {
        self.mediaItem = mediaItem
        self.progressFraction = progressFraction
        self.width = width
        self.height = height
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: mediaItem.fullPosterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        ZStack {
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.black.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "film")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Rating pill overlay
                if mediaItem.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", mediaItem.voteAverage))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                    .padding(8)
                }

                // Bottom progress bar overlay if present
                if let progress = progressFraction, progress > 0 {
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.black.opacity(0.6))
                                .frame(height: 4)
                            Rectangle()
                                .fill(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: width * CGFloat(progress), height: 4)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(mediaItem.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(mediaItem.displayDate)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: width, alignment: .leading)
        }
    }
}
