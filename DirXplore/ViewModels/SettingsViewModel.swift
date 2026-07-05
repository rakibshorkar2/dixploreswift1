import Foundation
import SwiftUI
import UIKit

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    @Published var maxDownloadLimit: Double = 0
    @Published var speedLimit: Double = 0
    @Published var downloadPath: String = "Downloads"
    @Published var notificationsEnabled: Bool = true
    @Published var wifiOnly: Bool = false
    @Published var pauseAtBattery20: Bool = true
    @Published var keepScreenAwake: Bool = false
    @Published var hapticFeedback: Bool = true
    @Published var screenAwakeTimer: Double = 0

    @Published var totalStorage: String = ""
    @Published var usedStorage: String = ""
    @Published var freeStorage: String = ""
    @Published var storageUsagePercent: Double = 0

    let appVersion = "v.1.0.0"
    let developerName = "RAKIB"

    private let storage = StorageService.shared
    private let defaults = UserDefaults.standard

    init() {
        isDarkMode = defaults.bool(forKey: "isDarkMode")
        loadSettings()
        updateStorageInfo()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStorageInfo),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc func updateStorageInfo() {
        let total = storage.totalDiskSpace
        let free = storage.freeDiskSpace
        let used = storage.usedDiskSpace

        totalStorage = total.formattedBytes
        usedStorage = used.formattedBytes
        freeStorage = free.formattedBytes
        storageUsagePercent = total > 0 ? Double(used) / Double(total) : 0
    }

    func toggleDarkMode() {
        isDarkMode.toggle()
    }

    func loadSettings() {
        maxDownloadLimit = defaults.double(forKey: "maxDownloadLimit")
        speedLimit = defaults.double(forKey: "speedLimit")
        downloadPath = defaults.string(forKey: "downloadPath") ?? "Downloads"
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        wifiOnly = defaults.bool(forKey: "wifiOnly")
        pauseAtBattery20 = defaults.object(forKey: "pauseAtBattery20") as? Bool ?? true
        keepScreenAwake = defaults.bool(forKey: "keepScreenAwake")
        hapticFeedback = defaults.object(forKey: "hapticFeedback") as? Bool ?? true
        screenAwakeTimer = defaults.double(forKey: "screenAwakeTimer")
    }

    private var awakeTimerWorkItem: DispatchWorkItem?

    func scheduleAwakeTimer() {
        awakeTimerWorkItem?.cancel()
        guard keepScreenAwake, screenAwakeTimer > 0 else { return }
        let item = DispatchWorkItem { UIApplication.shared.isIdleTimerDisabled = false }
        awakeTimerWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + screenAwakeTimer * 60, execute: item)
    }

    func cancelAwakeTimer() {
        awakeTimerWorkItem?.cancel()
        awakeTimerWorkItem = nil
    }

    func saveSettings() {
        defaults.set(maxDownloadLimit, forKey: "maxDownloadLimit")
        defaults.set(speedLimit, forKey: "speedLimit")
        defaults.set(downloadPath, forKey: "downloadPath")
        defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
        defaults.set(wifiOnly, forKey: "wifiOnly")
        defaults.set(pauseAtBattery20, forKey: "pauseAtBattery20")
        defaults.set(keepScreenAwake, forKey: "keepScreenAwake")
        defaults.set(hapticFeedback, forKey: "hapticFeedback")
        defaults.set(screenAwakeTimer, forKey: "screenAwakeTimer")
    }
}
