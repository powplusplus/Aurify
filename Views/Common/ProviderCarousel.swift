import SwiftUI

public struct ProviderCarousel: View {
    @Binding private var selection: ServerProvider
    private let providers: [ServerProvider]
    private let states: [ServerProvider: ProviderResolutionState]
    private let isEnabled: Bool
    private let onSelect: ((ServerProvider) -> Void)?

    public init(
        selection: Binding<ServerProvider>,
        providers: [ServerProvider] = ServerProvider.carouselProviders,
        states: [ServerProvider: ProviderResolutionState] = [:],
        isEnabled: Bool = true,
        onSelect: ((ServerProvider) -> Void)? = nil
    ) {
        _selection = selection
        self.providers = providers
        self.states = states
        self.isEnabled = isEnabled
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(providers) { provider in
                    providerCard(provider)
                        .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }

    private func providerCard(_ provider: ServerProvider) -> some View {
        let state = states[provider] ?? .idle
        let selected = selection == provider
        return Button {
            selection = provider
            onSelect?(provider)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: provider.iconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(selected ? .white : Color.aurifyAccent)
                    Spacer()
                    statusIcon(state)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.shortName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(statusText(for: provider, state: state))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Color.aurifyAccent.opacity(0.34) : Color.white.opacity(0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.aurifyAccent : Color.white.opacity(0.13), lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.72)
        .accessibilityLabel("\(provider.rawValue), \(state.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func statusIcon(_ state: ProviderResolutionState) -> some View {
        switch state {
        case .searching:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .available:
            Image(systemName: state.systemImage).foregroundStyle(.green)
        case .unavailable:
            Image(systemName: state.systemImage).foregroundStyle(.orange)
        case .idle:
            Image(systemName: state.systemImage).foregroundStyle(.white.opacity(0.42))
        }
    }

    private func statusText(for provider: ServerProvider, state: ProviderResolutionState) -> String {
        if state != .idle { return state.label }
        return provider == .zstreamAuto ? "Automatic fallback" : "Native source"
    }
}
