import SwiftUI
import BackgroundTasks
import UIKit
import UserNotifications

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
                    StorageService.shared.ensureDownloadsDirectory()
                    applyLaunchSettings()
                    requestNotificationPermission()
                }
        }
    }

    private func applyLaunchSettings() {
        UIApplication.shared.isIdleTimerDisabled = settingsVM.keepScreenAwake
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.dirBrowser.download", using: nil) { task in
            DownloadService.shared.handleBackgroundDownload(task: task as! BGProcessingTask)
        }
    }
}
