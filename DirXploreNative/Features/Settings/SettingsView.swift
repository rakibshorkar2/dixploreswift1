import SwiftUI

struct SettingsView: View {
    @State private var appState = AppSettings.shared
    @State private var theme = AppTheme.shared
    @State private var security = SecurityManager.shared
    @State private var showPinSetup = false
    @State private var showFolderPicker = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                downloadSection
                smartSection
                hapticsSection
                securitySection
                torrentSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPinSetup) { SecuritySetupView() }
            .sheet(isPresented: $showFolderPicker) {
                DocumentPickerView(contentTypes: [.folder]) { url in
                    appState.defaultSavePath = url.path
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("UI & APPEARANCE") {
            Picker("Theme", selection: $theme.colorScheme) {
                ForEach(AppTheme.ColorSchemeOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Toggle("True AMOLED Black", isOn: $theme.useAmoledBlack)
        }
    }

    private var downloadSection: some View {
        Section("DOWNLOAD SETTINGS") {
            Button {
                showFolderPicker = true
            } label: {
                HStack {
                    Text("Default Save Directory")
                    Spacer()
                    Text(URL(fileURLWithPath: appState.defaultSavePath).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Stepper("Max Concurrent: \(appState.maxConcurrentDownloads)", value: $appState.maxConcurrentDownloads, in: 1...10)

            Toggle("Show Notifications", isOn: $appState.showDownloadNotifications)

            VStack(alignment: .leading) {
                Text("Speed Limit: \(appState.speedLimitCap) KB/s")
                Slider(value: $appState.speedLimitCap, in: 0...10000, step: 100)
            }
        }
    }

    private var smartSection: some View {
        Section("SMART AUTOMATION") {
            Toggle("Smart Folder Routing", isOn: $appState.smartFolderRouting)
            Toggle("Wi-Fi Only", isOn: $appState.downloadOnWifiOnly)
            Toggle("Pause on Low Battery", isOn: $appState.pauseLowBattery)

            VStack(alignment: .leading) {
                Text("Keep Screen Awake: \(appState.keepScreenAwakeTimerMinutes) min")
                Toggle("Keep Screen Awake", isOn: $appState.keepScreenAwake)
            }
        }
    }

    private var hapticsSection: some View {
        Section("HAPTICS & FEEDBACK") {
            Toggle("Haptic Feedback", isOn: Binding(get: { HapticFeedback.isEnabled }, set: { HapticFeedback.setEnabled($0) }))
        }
    }

    private var securitySection: some View {
        Section("SECURITY & PRIVACY") {
            Picker("App Lock", selection: $security.lockType) {
                ForEach([LockType.none, .device, .custom], id: \.self) { type in
                    switch type {
                    case .none: Text("None").tag(type)
                    case .device: Text("Device (Face ID / Touch ID)").tag(type)
                    case .custom: Text("Custom PIN").tag(type)
                    }
                }
            }

            if security.lockType != .none {
                Picker("Auto-Lock", selection: $security.autoLockSeconds) {
                    Text("Immediate").tag(TimeInterval(0))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                }
            }

            if security.lockType == .custom {
                Button("Configure PIN") {
                    showPinSetup = true
                }
            }
        }
    }

    private var torrentSection: some View {
        Section("TORRENT SETTINGS") {
            Toggle("Use Proxy for Search", isOn: $appState.useProxyForTorrents)
            Toggle("Wi-Fi Only", isOn: $appState.torrentWifiOnly)
            Toggle("Pause on Low Battery", isOn: $appState.torrentPauseOnLowBattery)
            Toggle("Monitor Clipboard for Magnets", isOn: $appState.monitorClipboardMagnet)

            VStack(alignment: .leading) {
                Text("Download Limit: \(appState.torrentDownloadLimit) KB/s")
                Slider(value: $appState.torrentDownloadLimit, in: 0...10000, step: 100)
            }

            VStack(alignment: .leading) {
                Text("Upload Limit: \(appState.torrentUploadLimit) KB/s")
                Slider(value: $appState.torrentUploadLimit, in: 0...10000, step: 100)
            }
        }
    }

    private var aboutSection: some View {
        Section("ABOUT") {
            LabeledContent("Version", value: "\(AppConfiguration.appVersion) (\(AppConfiguration.buildNumber))")
            Text("Created by RAKIB")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var defaultSavePath: String {
        didSet { UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath") }
    }
    var maxConcurrentDownloads: Int {
        didSet { UserDefaults.standard.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads") }
    }
    var showDownloadNotifications: Bool {
        didSet { UserDefaults.standard.set(showDownloadNotifications, forKey: "showDownloadNotifications") }
    }
    var speedLimitCap: Double {
        didSet { UserDefaults.standard.set(speedLimitCap, forKey: "speedLimitCap") }
    }
    var smartFolderRouting: Bool {
        didSet { UserDefaults.standard.set(smartFolderRouting, forKey: "smartFolderRouting") }
    }
    var downloadOnWifiOnly: Bool {
        didSet { UserDefaults.standard.set(downloadOnWifiOnly, forKey: "downloadOnWifiOnly") }
    }
    var pauseLowBattery: Bool {
        didSet { UserDefaults.standard.set(pauseLowBattery, forKey: "pauseLowBattery") }
    }
    var keepScreenAwake: Bool {
        didSet { UserDefaults.standard.set(keepScreenAwake, forKey: "keepScreenAwake") }
    }
    var keepScreenAwakeTimerMinutes: Int {
        didSet { UserDefaults.standard.set(keepScreenAwakeTimerMinutes, forKey: "keepScreenAwakeTimerMinutes") }
    }
    var useProxyForTorrents: Bool {
        didSet { UserDefaults.standard.set(useProxyForTorrents, forKey: "useProxyForTorrents") }
    }
    var torrentWifiOnly: Bool {
        didSet { UserDefaults.standard.set(torrentWifiOnly, forKey: "torrentWifiOnly") }
    }
    var torrentPauseOnLowBattery: Bool {
        didSet { UserDefaults.standard.set(torrentPauseOnLowBattery, forKey: "torrentPauseOnLowBattery") }
    }
    var torrentDownloadLimit: Double {
        didSet { UserDefaults.standard.set(torrentDownloadLimit, forKey: "torrentDownloadLimit") }
    }
    var torrentUploadLimit: Double {
        didSet { UserDefaults.standard.set(torrentUploadLimit, forKey: "torrentUploadLimit") }
    }
    var monitorClipboardMagnet: Bool {
        didSet { UserDefaults.standard.set(monitorClipboardMagnet, forKey: "monitorClipboardMagnet") }
    }

    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultDir = documentsDir.appendingPathComponent("DirXplore").path
        try? FileManager.default.createDirectory(atPath: defaultDir, withIntermediateDirectories: true)

        defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? defaultDir
        maxConcurrentDownloads = UserDefaults.standard.integer(forKey: "maxConcurrentDownloads").nonZero(or: 3)
        showDownloadNotifications = UserDefaults.standard.bool(forKey: "showDownloadNotifications")
        speedLimitCap = UserDefaults.standard.double(forKey: "speedLimitCap")
        smartFolderRouting = UserDefaults.standard.bool(forKey: "smartFolderRouting")
        downloadOnWifiOnly = UserDefaults.standard.bool(forKey: "downloadOnWifiOnly")
        pauseLowBattery = UserDefaults.standard.bool(forKey: "pauseLowBattery")
        keepScreenAwake = UserDefaults.standard.bool(forKey: "keepScreenAwake")
        keepScreenAwakeTimerMinutes = UserDefaults.standard.integer(forKey: "keepScreenAwakeTimerMinutes")
        useProxyForTorrents = UserDefaults.standard.bool(forKey: "useProxyForTorrents")
        torrentWifiOnly = UserDefaults.standard.bool(forKey: "torrentWifiOnly")
        torrentPauseOnLowBattery = UserDefaults.standard.bool(forKey: "torrentPauseOnLowBattery")
        torrentDownloadLimit = UserDefaults.standard.double(forKey: "torrentDownloadLimit")
        torrentUploadLimit = UserDefaults.standard.double(forKey: "torrentUploadLimit")
        monitorClipboardMagnet = UserDefaults.standard.bool(forKey: "monitorClipboardMagnet")
    }
}

private extension Int {
    func nonZero(or value: Int) -> Int {
        self == 0 ? value : self
    }
}
