import SwiftUI
import BackgroundTasks

@main
struct DirXploreApp: App {
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsVM)
                .preferredColorScheme(settingsVM.isDarkMode ? .dark : .light)
                .onAppear {
                    registerBackgroundTasks()
                }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.rakib.dirxplore.download", using: nil) { task in
            DownloadService.shared.handleBackgroundDownload(task: task as! BGProcessingTask)
        }
    }
}
