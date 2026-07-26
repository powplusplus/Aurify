import SwiftUI

public struct CategoryPills: View {
    public let categories: [String]
    @Binding public var selectedCategory: String
    
    public init(categories: [String], selectedCategory: Binding<String>) {
        self.categories = categories
        self._selectedCategory = selectedCategory
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { cat in
                    let isSelected = cat == selectedCategory
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedCategory = cat
                        }
                    }) {
                        Text(cat)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? .black : .white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(LinearGradient(colors: [Color.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                    }
                                }
                            )
                            .shadow(color: isSelected ? Color.white.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}
