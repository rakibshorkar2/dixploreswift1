import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsVM: SettingsViewModel

    var body: some View {
        NavigationView {
            Form {
                appearanceSection
                storageSection
                downloadSettingsSection
                advancedSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            HStack {
                Label("Dark Mode", systemImage: settingsVM.isDarkMode ? "moon.fill" : "sun.max")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { settingsVM.isDarkMode },
                    set: { _ in settingsVM.toggleDarkMode() }
                ))
                .labelsHidden()
            }
        }
    }

    private var storageSection: some View {
        Section("iPhone Storage") {
            VStack(spacing: 8) {
                HStack {
                    Text("Total")
                    Spacer()
                    Text(settingsVM.totalStorage)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Used")
                    Spacer()
                    Text(settingsVM.usedStorage)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Free")
                    Spacer()
                    Text(settingsVM.freeStorage)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: settingsVM.storageUsagePercent)
                    .tint(settingsVM.storageUsagePercent > 0.9 ? .red : .blue)

                Text("\(Int(settingsVM.storageUsagePercent * 100))% used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var downloadSettingsSection: some View {
        Section("Download Settings") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Max Download Limit")
                    Spacer()
                    Text("\(Int(settingsVM.maxDownloadLimit)) MB")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settingsVM.maxDownloadLimit, in: 0...1000, step: 10)
                    .onChange(of: settingsVM.maxDownloadLimit) { _, _ in
                        settingsVM.saveSettings()
                    }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Speed Limit")
                    Spacer()
                    Text("\(Int(settingsVM.speedLimit)) KB/s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settingsVM.speedLimit, in: 0...10000, step: 100)
                    .onChange(of: settingsVM.speedLimit) { _, _ in
                        settingsVM.saveSettings()
                    }
            }

            HStack {
                Label("Download Path", systemImage: "folder")
                Spacer()
                Text(settingsVM.downloadPath)
                    .foregroundColor(.secondary)
            }

            Toggle(isOn: $settingsVM.notificationsEnabled) {
                Label("Download Notifications", systemImage: "bell")
            }
            .onChange(of: settingsVM.notificationsEnabled) { _, _ in
                settingsVM.saveSettings()
            }

            Toggle(isOn: $settingsVM.wifiOnly) {
                Label("Wi-Fi Only", systemImage: "wifi")
            }
            .onChange(of: settingsVM.wifiOnly) { _, _ in
                settingsVM.saveSettings()
            }

            Toggle(isOn: $settingsVM.pauseAtBattery20) {
                Label("Pause at 20% Battery", systemImage: "battery.25")
            }
            .onChange(of: settingsVM.pauseAtBattery20) { _, _ in
                settingsVM.saveSettings()
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            Toggle(isOn: $settingsVM.keepScreenAwake) {
                Label("Keep Screen Awake", systemImage: "sun.max")
            }
            .onChange(of: settingsVM.keepScreenAwake) { _, _ in
                settingsVM.saveSettings()
                UIApplication.shared.isIdleTimerDisabled = settingsVM.keepScreenAwake
                if settingsVM.keepScreenAwake {
                    settingsVM.scheduleAwakeTimer()
                } else {
                    settingsVM.cancelAwakeTimer()
                }
            }

            if settingsVM.keepScreenAwake {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Timer (minutes)")
                        Spacer()
                        Text("\(Int(settingsVM.screenAwakeTimer))")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settingsVM.screenAwakeTimer, in: 0...60, step: 1)
                        .onChange(of: settingsVM.screenAwakeTimer) { _, _ in
                            settingsVM.saveSettings()
                            settingsVM.scheduleAwakeTimer()
                        }
                }
            }

            Toggle(isOn: $settingsVM.hapticFeedback) {
                Label("Haptic Feedback", systemImage: "hand.tap")
            }
            .onChange(of: settingsVM.hapticFeedback) { _, _ in
                settingsVM.saveSettings()
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(settingsVM.appVersion)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Developer", systemImage: "person")
                Spacer()
                Text(settingsVM.developerName)
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)
            }

            HStack {
                Label("App", systemImage: "app")
                Spacer()
                Text("DirXplore")
                    .foregroundColor(.secondary)
            }
        }
    }
}
