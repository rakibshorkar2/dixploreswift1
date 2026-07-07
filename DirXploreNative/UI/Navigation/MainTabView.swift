import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showLockScreen = false
    @State private var isLocked = false

    var body: some View {
        Group {
            if isLocked {
                PinLockScreen(isLocked: $isLocked)
                    .transition(.blurReplace)
            } else {
                TabView(selection: $selectedTab) {
                    BrowserView()
                        .tabItem {
                            Image(systemName: "globe")
                            Text("Browser")
                        }
                        .tag(0)

                    DownloadsView()
                        .tabItem {
                            Image(systemName: "arrow.down.circle")
                            Text("Downloads")
                        }
                        .tag(1)

                    DeepCrawlerView()
                        .tabItem {
                            Image(systemName: "sensor.tag.radiowaves.forward")
                            Text("Crawler")
                        }
                        .tag(2)

                    ProxyView()
                        .tabItem {
                            Image(systemName: "shield.lefthalf.filled")
                            Text("Proxy")
                        }
                        .tag(3)

                    TorrentView()
                        .tabItem {
                            Image(systemName: "link.icloud")
                            Text("Torrents")
                        }
                        .tag(4)

                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(5)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    Task { @MainActor in
                        if SecurityManager.shared.lockType != .none {
                            isLocked = true
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task { @MainActor in
                        if SecurityManager.shared.lockType != .none {
                            await authenticateUser()
                        }
                    }
                }
            }
        }
    }

    private func authenticateUser() async {
        switch SecurityManager.shared.lockType {
        case .none:
            isLocked = false
        case .device:
            let success = await SecurityManager.shared.authenticateDevice()
            isLocked = !success
        case .custom:
            break
        }
    }
}

#Preview {
    MainTabView()
}
