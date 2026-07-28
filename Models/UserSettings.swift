import Foundation
import Combine

public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    private enum Keys {
        static let primaryProvider = "aurify_primary_provider_v2"
        static let preferredSubtitleLang = "aurify_subtitle_lang"
        static let subtitlesEnabled = "aurify_subtitles_enabled"
        static let autoPlayNextEpisode = "aurify_autoplay_next"
        static let defaultQuality = "aurify_default_quality"
        static let customTMDBKey = "aurify_tmdb_key"
        static let customResolverURL = "aurify_custom_resolver_url"
        static let subtitleFontSize = "aurify_sub_font_size"
        static let subtitleBgOpacity = "aurify_sub_bg_opacity"
        static let playbackSpeed = "aurify_playback_speed"
        static let allowsCellular = "aurify_allows_cellular"
        static let includeAdult = "aurify_include_adult"
        static let metadataLanguage = "aurify_metadata_language"
    }

    @Published public var primaryProvider: ServerProvider {
        didSet { defaults.set(primaryProvider.rawValue, forKey: Keys.primaryProvider) }
    }
    @Published public var preferredSubtitleLanguage: String {
        didSet { defaults.set(preferredSubtitleLanguage, forKey: Keys.preferredSubtitleLang) }
    }
    @Published public var subtitlesEnabled: Bool {
        didSet { defaults.set(subtitlesEnabled, forKey: Keys.subtitlesEnabled) }
    }
    @Published public var autoPlayNextEpisode: Bool {
        didSet { defaults.set(autoPlayNextEpisode, forKey: Keys.autoPlayNextEpisode) }
    }
    @Published public var defaultQuality: StreamQuality {
        didSet { defaults.set(defaultQuality.rawValue, forKey: Keys.defaultQuality) }
    }
    @Published public var customTMDBKey: String {
        didSet { KeychainStore.shared.set(customTMDBKey.trimmingCharacters(in: .whitespacesAndNewlines), for: Keys.customTMDBKey) }
    }
    @Published public var customResolverURL: String {
        didSet { defaults.set(customResolverURL, forKey: Keys.customResolverURL) }
    }
    @Published public var subtitleFontSize: Double {
        didSet { defaults.set(subtitleFontSize, forKey: Keys.subtitleFontSize) }
    }
    @Published public var subtitleBgOpacity: Double {
        didSet { defaults.set(subtitleBgOpacity, forKey: Keys.subtitleBgOpacity) }
    }
    @Published public var playbackSpeed: Double {
        didSet { defaults.set(playbackSpeed, forKey: Keys.playbackSpeed) }
    }
    @Published public var allowsCellularStreaming: Bool {
        didSet { defaults.set(allowsCellularStreaming, forKey: Keys.allowsCellular) }
    }
    @Published public var includeAdultContent: Bool {
        didSet { defaults.set(includeAdultContent, forKey: Keys.includeAdult) }
    }
    @Published public var metadataLanguage: String {
        didSet { defaults.set(metadataLanguage, forKey: Keys.metadataLanguage) }
    }

    private let defaults = UserDefaults.standard

    private init() {
        let provider = defaults.string(forKey: Keys.primaryProvider)
        primaryProvider = ServerProvider(rawValue: provider ?? "") ?? .zstreamAuto
        preferredSubtitleLanguage = defaults.string(forKey: Keys.preferredSubtitleLang) ?? "en"
        subtitlesEnabled = defaults.object(forKey: Keys.subtitlesEnabled) as? Bool ?? true
        autoPlayNextEpisode = defaults.object(forKey: Keys.autoPlayNextEpisode) as? Bool ?? true
        defaultQuality = StreamQuality(rawValue: defaults.string(forKey: Keys.defaultQuality) ?? "") ?? .auto
        customResolverURL = defaults.string(forKey: Keys.customResolverURL) ?? ""
        subtitleFontSize = defaults.object(forKey: Keys.subtitleFontSize) as? Double ?? 20
        subtitleBgOpacity = defaults.object(forKey: Keys.subtitleBgOpacity) as? Double ?? 0.68
        playbackSpeed = defaults.object(forKey: Keys.playbackSpeed) as? Double ?? 1
        allowsCellularStreaming = defaults.object(forKey: Keys.allowsCellular) as? Bool ?? true
        includeAdultContent = defaults.object(forKey: Keys.includeAdult) as? Bool ?? false
        metadataLanguage = defaults.string(forKey: Keys.metadataLanguage) ?? Locale.current.language.languageCode?.identifier ?? "en-US"

        if let secureValue = KeychainStore.shared.string(for: Keys.customTMDBKey) {
            customTMDBKey = secureValue
        } else {
            let legacyValue = defaults.string(forKey: Keys.customTMDBKey) ?? ""
            customTMDBKey = legacyValue
            if !legacyValue.isEmpty {
                KeychainStore.shared.set(legacyValue, for: Keys.customTMDBKey)
                defaults.removeObject(forKey: Keys.customTMDBKey)
            }
        }
    }

    public var hasTMDBCredential: Bool {
        !customTMDBKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
