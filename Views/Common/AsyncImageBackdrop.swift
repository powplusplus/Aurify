import SwiftUI

public struct AsyncImageBackdrop: View {
    public let url: URL?
    public let height: CGFloat
    public let contentMode: ContentMode

    public init(url: URL?, height: CGFloat = 360, contentMode: ContentMode = .fill) {
        self.url = url
        self.height = height
        self.contentMode = contentMode
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure, .empty:
                    LinearGradient(
                        colors: [Color(white: 0.15), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: height)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.black.opacity(0.5), location: 0.5),
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.07), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
    }
}
