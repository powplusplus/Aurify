import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var historyManager = WatchHistoryManager.shared
    @State private var showClearHistoryAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Playback, Provider & Subtitle Preferences")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        // Streaming Provider Section
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Stream Resolver Provider", systemImage: "server.rack")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)

                                Picker("Primary Provider", selection: $settings.primaryProvider) {
                                    ForEach(ServerProvider.allCases) { prov in
                                        Text(prov.rawValue).tag(prov)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())

                                Text("ZStream Primary targets zstream.mov native embed extraction with automatic fallback to high-speed stream sources.")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 20)

                        // Subtitle Preferences Section
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Subtitle Styling & Default", systemImage: "captions.bubble.fill")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)

                                HStack {
                                    Text("Default Language")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("Language", selection: $settings.preferredSubtitleLanguage) {
                                        Text("English").tag("en")
                                        Text("Spanish").tag("es")
                                        Text("French").tag("fr")
                                        Text("German").tag("de")
                                        Text("Japanese").tag("ja")
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .tint(.cyan)
                                }

                                Divider().background(Color.white.opacity(0.1))

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Font Size")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(settings.subtitleFontSize)) pt")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.cyan)
                                    }
                                    Slider(value: $settings.subtitleFontSize, in: 14...28, step: 1)
                                        .tint(.cyan)
                                }

                                Divider().background(Color.white.opacity(0.1))

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Background Opacity")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(settings.subtitleBgOpacity * 100))%")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.cyan)
                                    }
                                    Slider(value: $settings.subtitleBgOpacity, in: 0.2...1.0, step: 0.05)
                                        .tint(.cyan)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Data & Watch History Section
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Watch History & Progress", systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Stored History Entries")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("\(historyManager.history.count) titles saved")
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundColor(.white.opacity(0.5))
                                    }

                                    Spacer()

                                    Button(action: { showClearHistoryAlert = true }) {
                                        Text("Clear History")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.red.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // TMDB Custom API Key Section
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("TMDB Integration", systemImage: "key.fill")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)

                                Text("Custom TMDB API Key (Optional)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))

                                TextField("Leave blank to use built-in fallback key", text: $settings.customTMDBKey)
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)

                        // About App
                        VStack(spacing: 6) {
                            Text("Aurify • iOS 27 Design Language")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Version 1.0.0 (Build 2026.1) • Swift & AVPlayer")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .alert("Clear Watch History", isPresented: $showClearHistoryAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    historyManager.clearAllHistory()
                }
            } message: {
                Text("Are you sure you want to remove all saved playback progress?")
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
}
