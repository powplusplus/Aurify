import SwiftUI

public struct SeasonEpisodeSelector: View {
    public let totalSeasons: Int
    @Binding public var selectedSeasonNumber: Int
    public let episodes: [Episode]
    @Binding public var selectedEpisode: Episode?
    public let onSeasonChange: (Int) -> Void

    public init(
        totalSeasons: Int,
        selectedSeasonNumber: Binding<Int>,
        episodes: [Episode],
        selectedEpisode: Binding<Episode?>,
        onSeasonChange: @escaping (Int) -> Void
    ) {
        self.totalSeasons = totalSeasons
        self._selectedSeasonNumber = selectedSeasonNumber
        self.episodes = episodes
        self._selectedEpisode = selectedEpisode
        self.onSeasonChange = onSeasonChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Season Selector Picker
            HStack {
                Text("Episodes")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Menu {
                    ForEach(1...max(totalSeasons, 1), id: \.self) { sNum in
                        Button("Season \(sNum)") {
                            onSeasonChange(sNum)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Season \(selectedSeasonNumber)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }

            // Episode horizontal list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(episodes) { ep in
                        let isSelected = selectedEpisode?.id == ep.id
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedEpisode = ep
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topLeading) {
                                    AsyncImage(url: ep.fullStillURL) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        default:
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 160, height: 95)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    Text("E\(ep.episodeNumber)")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Capsule())
                                        .padding(6)
                                }

                                Text(ep.name)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .cyan : .white)
                                    .lineLimit(1)
                            }
                            .frame(width: 160)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected ? Color.cyan.opacity(0.15) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}
