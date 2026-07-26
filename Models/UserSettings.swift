import Foundation
import Combine

public class UserSettings: ObservableObject {
    public static let shared = UserSettings()
    
    private enum Keys {
        static let primaryProvider = "aurify_primary_provider"
        static let preferredSubtitleLang = "aurify_subtitle_lang"
        static let autoPlayNextEpisode = "aurify_autoplay_next"
        static let defaultQuality = "aurify_default_quality"
        static let customTMDBKey = "aurify_tmdb_key"
        static let subtitleFontSize = "aurify_sub_font_size"
        static let subtitleBgOpacity = "aurify_sub_bg_opacity"
        static let hardwareAcceleration = "aurify_hardware_accel"
    }

    @Published public var primaryProvider: ServerProvider {
        didSet {
            UserDefaults.standard.set(primaryProvider.rawValue, forKey: Keys.primaryProvider)
        }
    }

    @Published public var preferredSubtitleLanguage: String {
        didSet {
            UserDefaults.standard.set(preferredSubtitleLanguage, forKey: Keys.preferredSubtitleLang)
        }
    }

    @Published public var autoPlayNextEpisode: Bool {
        didSet {
            UserDefaults.standard.set(autoPlayNextEpisode, forKey: Keys.autoPlayNextEpisode)
        }
    }

    @Published public var defaultQuality: StreamQuality {
        didSet {
            UserDefaults.standard.set(defaultQuality.rawValue, forKey: Keys.defaultQuality)
        }
    }

    @Published public var customTMDBKey: String {
        didSet {
            UserDefaults.standard.set(customTMDBKey, forKey: Keys.customTMDBKey)
        }
    }

    @Published public var subtitleFontSize: Double {
        didSet {
            UserDefaults.standard.set(subtitleFontSize, forKey: Keys.subtitleFontSize)
        }
    }

    @Published public var subtitleBgOpacity: Double {
        didSet {
            UserDefaults.standard.set(subtitleBgOpacity, forKey: Keys.subtitleBgOpacity)
        }
    }
    
    @Published public var hardwareAcceleration: Bool {
        didSet {
            UserDefaults.standard.set(hardwareAcceleration, forKey: Keys.hardwareAcceleration)
        }
    }

    private init() {
        let savedProviderStr = UserDefaults.standard.string(forKey: Keys.primaryProvider) ?? ServerProvider.zstream.rawValue
        self.primaryProvider = ServerProvider(rawValue: savedProviderStr) ?? .zstream
        
        self.preferredSubtitleLanguage = UserDefaults.standard.string(forKey: Keys.preferredSubtitleLang) ?? "en"
        self.autoPlayNextEpisode = UserDefaults.standard.object(forKey: Keys.autoPlayNextEpisode) as? Bool ?? true
        
        let savedQualStr = UserDefaults.standard.string(forKey: Keys.defaultQuality) ?? StreamQuality.auto.rawValue
        self.defaultQuality = StreamQuality(rawValue: savedQualStr) ?? .auto
        
        self.customTMDBKey = UserDefaults.standard.string(forKey: Keys.customTMDBKey) ?? ""
        self.subtitleFontSize = UserDefaults.standard.double(forKey: Keys.subtitleFontSize) == 0 ? 18.0 : UserDefaults.standard.double(forKey: Keys.subtitleFontSize)
        self.subtitleBgOpacity = UserDefaults.standard.object(forKey: Keys.subtitleBgOpacity) as? Double ?? 0.65
        self.hardwareAcceleration = UserDefaults.standard.object(forKey: Keys.hardwareAcceleration) as? Bool ?? true
    }
}
