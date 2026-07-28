import Foundation

public struct SubtitleCue: Identifiable, Codable, Hashable {
    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

public enum SubtitleFormat: String, Codable {
    case webVTT
    case subRip
}

public struct SubtitleTrack: Identifiable, Codable, Hashable {
    public let id: String
    public let language: String
    public let label: String
    public let url: URL
    public let format: SubtitleFormat
    public let source: String
    public let isHearingImpaired: Bool

    public init(
        id: String = UUID().uuidString,
        language: String,
        label: String,
        url: URL,
        format: SubtitleFormat = .webVTT,
        source: String = "Provider",
        isHearingImpaired: Bool = false
    ) {
        self.id = id
        self.language = language
        self.label = label
        self.url = url
        self.format = format
        self.source = source
        self.isHearingImpaired = isHearingImpaired
    }
}
