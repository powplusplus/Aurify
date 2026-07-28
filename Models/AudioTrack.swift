import Foundation

/// A selectable audio rendition exposed by the current AVFoundation media item.
public struct AudioTrack: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let languageCode: String?

    public init(id: String, label: String, languageCode: String? = nil) {
        self.id = id
        self.label = label
        self.languageCode = languageCode
    }
}
