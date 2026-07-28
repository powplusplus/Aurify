import SwiftUI

public struct GlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let padding: CGFloat
    public let borderColor: Color
    public let borderWidth: CGFloat
    public let content: () -> Content

    public init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        borderColor: Color = Color.white.opacity(0.18),
        borderWidth: CGFloat = 1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.content = content
    }

    public var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content()
                .padding(padding)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content()
                .padding(padding)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(borderColor, lineWidth: borderWidth))
                .shadow(color: .black.opacity(0.25), radius: 15, y: 8)
        }
    }
}
