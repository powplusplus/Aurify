import Foundation

public enum ServerProvider: String, Codable, CaseIterable, Identifiable {
    case zstream = "ZStream Primary"
    case vidsrcPro = "VidSrc Pro"
    case embedSu = "EmbedSu Fast"
    case autoFallback = "Auto Resolver (Smart)"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .zstream: return "sparkles.tv"
        case .vidsrcPro: return "play.circle.fill"
        case .embedSu: return "bolt.horizontal.fill"
        case .autoFallback: return "arrow.triangle.2.circlepath"
        }
    }
}

public enum StreamQuality: String, Codable, CaseIterable, Comparable {
    case q1080p = "1080p"
    case q720p = "720p"
    case q480p = "480p"
    case auto = "Auto"
    
    public static func < (lhs: StreamQuality, rhs: StreamQuality) -> Bool {
        let order: [StreamQuality] = [.q480p, .q720p, .q1080p, .auto]
        let leftIndex = order.firstIndex(of: lhs) ?? 0
        let rightIndex = order.firstIndex(of: rhs) ?? 0
        return leftIndex < rightIndex
    }
}

public struct StreamSource: Identifiable, Codable {
    public let id: UUID
    public let url: URL
    public let quality: StreamQuality
    public let isHLS: Bool
    public let provider: ServerProvider
    public let headers: [String: String]?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        quality: StreamQuality = .auto,
        isHLS: Bool = true,
        provider: ServerProvider = .zstream,
        headers: [String: String]? = nil
    ) {
        self.id = id
        self.url = url
        self.quality = quality
        self.isHLS = isHLS
        self.provider = provider
        self.headers = headers
    }
}
