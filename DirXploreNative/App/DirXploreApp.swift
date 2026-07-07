import SwiftUI

@main
struct DirXploreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var theme = AppTheme.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(theme.resolvedColorScheme)
                .environment(\.appTheme, theme)
                .onAppear {
                    BackgroundAudioService.shared.start()
                    configureAppearance()
                }
        }
    }

    private func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
