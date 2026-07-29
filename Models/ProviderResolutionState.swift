import Foundation

public enum ProviderResolutionState: Equatable {
    case idle
    case searching
    case available
    case unavailable(String)

    public var label: String {
        switch self {
        case .idle: return "Ready to check"
        case .searching: return "Searching"
        case .available: return "Stream found"
        case .unavailable: return "Unavailable"
        }
    }

    public var systemImage: String {
        switch self {
        case .idle: return "circle.dotted"
        case .searching: return "waveform.path.ecg"
        case .available: return "checkmark.circle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }
}
