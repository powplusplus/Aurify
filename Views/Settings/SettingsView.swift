import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var history = WatchHistoryManager.shared
    @ObservedObject private var watchlist = WatchlistManager.shared
    @State private var confirmation: Confirmation?
    @State private var showConfirmation = false

    private enum Confirmation: String, Identifiable {
        case history, watchlist
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("TMDB Read Access Token", text: $settings.customTMDBKey)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Link("Create a free TMDB token", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                } header: {
                    Text("Catalog")
                } footer: {
                    Text("Aurify first reads Z-Stream's public runtime configuration. Your own TMDB token is the reliable fallback and is stored in this device's Keychain.")
                }

                Section("Streaming") {
                    Picker("Provider", selection: $settings.primaryProvider) {
                        ForEach(ServerProvider.allCases) { provider in
                            Label(provider.rawValue, systemImage: provider.iconName).tag(provider)
                        }
                    }
                    if settings.primaryProvider == .custom {
                        TextField("https://your-resolver.example/resolve", text: $settings.customResolverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Picker("Preferred quality", selection: $settings.defaultQuality) {
                        ForEach(StreamQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    Picker("Default speed", selection: $settings.playbackSpeed) {
                        ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { speed in
                            Text(String(format: "%gx", speed)).tag(speed)
                        }
                    }
                    Toggle("Autoplay next episode", isOn: $settings.autoPlayNextEpisode)
                    Toggle("Allow cellular streaming", isOn: $settings.allowsCellularStreaming)
                }

                Section("Subtitles") {
                    Toggle("Enable by default", isOn: $settings.subtitlesEnabled)
                    Picker("Preferred language", selection: $settings.preferredSubtitleLanguage) {
                        ForEach(subtitleLanguages, id: \.code) { language in
                            Text(language.name).tag(language.code)
                        }
                    }
                    LabeledContent("Text size", value: "\(Int(settings.subtitleFontSize)) pt")
                    Slider(value: $settings.subtitleFontSize, in: 14...34, step: 1)
                    LabeledContent("Background", value: "\(Int(settings.subtitleBgOpacity * 100))%")
                    Slider(value: $settings.subtitleBgOpacity, in: 0...1, step: 0.05)
                }

                Section("Discovery") {
                    Picker("Metadata language", selection: $settings.metadataLanguage) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("Español").tag("es-ES")
                        Text("Français").tag("fr-FR")
                        Text("Deutsch").tag("de-DE")
                        Text("日本語").tag("ja-JP")
                    }
                    Toggle("Include adult titles", isOn: $settings.includeAdultContent)
                }

                Section("Local data") {
                    LabeledContent("Watch history", value: "\(history.history.count) entries")
                    Button("Clear watch history", role: .destructive) {
                        confirmation = .history
                        showConfirmation = true
                    }
                    LabeledContent("Watchlist", value: "\(watchlist.items.count) titles")
                    Button("Clear watchlist", role: .destructive) {
                        confirmation = .watchlist
                        showConfirmation = true
                    }
                }

                Section("About") {
                    LabeledContent("Aurify", value: "1.2")
                    LabeledContent("Playback", value: "AVFoundation")
                    Link("Open Z-Stream", destination: URL(string: "https://zstream.mov/")!)
                    Link("Z-Stream source", destination: URL(string: "https://github.com/xp-technologies-dev/p-stream")!)
                    Text("Aurify does not host media. Provider availability and your right to view a title depend on your region and the third-party source.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.aurifyBackground)
            .navigationTitle("Settings")
            .confirmationDialog("Clear local data?", isPresented: $showConfirmation, presenting: confirmation) { target in
                Button("Clear", role: .destructive) {
                    if target == .history { history.clearAllHistory() }
                    else { watchlist.clear() }
                }
                Button("Cancel", role: .cancel) {}
            } message: { target in
                Text(target == .history ? "All playback progress will be removed." : "All saved titles will be removed.")
            }
        }
    }

    private let subtitleLanguages: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Spanish"), ("fr", "French"), ("de", "German"),
        ("it", "Italian"), ("pt", "Portuguese"), ("ja", "Japanese"), ("ko", "Korean"),
        ("zh", "Chinese"), ("ar", "Arabic"), ("hi", "Hindi"), ("ru", "Russian")
    ]
}
