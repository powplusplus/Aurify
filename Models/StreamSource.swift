import Foundation

public enum ServerProvider: String, Codable, CaseIterable, Identifiable {
    case zstreamAuto = "Z-Stream Auto"
    case granite = "Granite"
    case vidLink = "VidLink"
    case custom = "Custom Resolver"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .zstreamAuto: return "sparkles.tv"
        case .granite: return "mountain.2.fill"
        case .vidLink: return "play.rectangle.fill"
        case .custom: return "server.rack"
        }
    }

    public var detail: String {
        switch self {
        case .zstreamAuto:
            return "Checks each native Z-Stream provider in order until a playable stream is found."
        case .granite:
            return "Fast multi-mirror source from Z-Stream's current provider engine."
        case .vidLink:
            return "Uses the VidLink provider contract from Z-Stream's open-source engine."
        case .custom:
            return "Uses a resolver endpoint that you control."
        }
    }

    public var shortName: String {
        self == .zstreamAuto ? "Auto" : rawValue
    }

    public static var nativePlaybackOrder: [ServerProvider] {
        [.granite, .vidLink]
    }

    public static var carouselProviders: [ServerProvider] {
        var providers: [ServerProvider] = [.zstreamAuto] + nativePlaybackOrder
        if !UserSettings.shared.customResolverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            providers.append(.custom)
        }
        return providers
    }
}

public enum StreamQuality: String, Codable, CaseIterable, Comparable, Identifiable {
    case q2160p = "2160p"
    case q1080p = "1080p"
    case q720p = "720p"
    case q480p = "480p"
    case q360p = "360p"
    case auto = "Auto"

    public var id: String { rawValue }

    private var rank: Int {
        switch self {
        case .q360p: return 360
        case .q480p: return 480
        case .q720p: return 720
        case .q1080p: return 1080
        case .q2160p: return 2160
        case .auto: return Int.max
        }
    }

    public static func < (lhs: StreamQuality, rhs: StreamQuality) -> Bool {
        lhs.rank < rhs.rank
    }

    public static func from(providerValue value: String) -> StreamQuality {
        let normalized = value.lowercased().replacingOccurrences(of: "p", with: "")
        switch normalized {
        case "2160", "4k": return .q2160p
        case "1080": return .q1080p
        case "720": return .q720p
        case "480": return .q480p
        case "360": return .q360p
        default: return .auto
        }
    }
}

public struct StreamSource: Identifiable, Codable, Hashable {
    public let id: UUID
    public let url: URL
    public let quality: StreamQuality
    public let isHLS: Bool
    public let provider: ServerProvider
    public let name: String
    public let headers: [String: String]

    public init(
        id: UUID = UUID(),
        url: URL,
        quality: StreamQuality = .auto,
        isHLS: Bool = true,
        provider: ServerProvider = .zstreamAuto,
        name: String? = nil,
        headers: [String: String] = [:]
    ) {
        self.id = id
        self.url = url
        self.quality = quality
        self.isHLS = isHLS
        self.provider = provider
        self.name = name ?? quality.rawValue
        self.headers = headers
    }
}
