import SwiftUI

@main
public struct AurifyApp: App {
    @StateObject private var settings = UserSettings.shared
    @StateObject private var historyManager = WatchHistoryManager.shared
    @StateObject private var watchlistManager = WatchlistManager.shared

    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(historyManager)
                .environmentObject(watchlistManager)
                .preferredColorScheme(.dark)
        }
    }
}

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "sparkles.tv.fill")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "rectangle.stack.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.aurifyAccent)
    }
}

public extension Color {
    static let aurifyBackground = Color(red: 0.035, green: 0.035, blue: 0.055)
    static let aurifyAccent = Color(red: 0.43, green: 0.42, blue: 1.0)
}
