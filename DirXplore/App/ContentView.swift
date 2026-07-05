import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
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

            ProxyView()
                .tabItem {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("Proxy")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}
