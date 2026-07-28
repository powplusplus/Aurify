import SwiftUI

public struct SubtitleOverlayView: View {
    public let text: String?
    public let fontSize: CGFloat
    public let backgroundOpacity: Double

    public init(text: String?, fontSize: CGFloat = 18, backgroundOpacity: Double = 0.65) {
        self.text = text
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
    }

    public var body: some View {
        if let subtitleText = text, !subtitleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack {
                Spacer()
                Text(subtitleText)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(backgroundOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 24)
            .allowsHitTesting(false)
            .accessibilityLabel("Subtitles")
            .accessibilityValue(subtitleText)
        }
    }
}
