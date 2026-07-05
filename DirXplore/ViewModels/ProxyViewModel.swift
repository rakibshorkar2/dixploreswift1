import Foundation
import SwiftUI

@MainActor
class ProxyViewModel: ObservableObject {
    @Published var host: String = "103.166.253.92"
    @Published var port: String = "1088"
    @Published var username: String = "test"
    @Published var password: String = "test"
    @Published var isEnabled: Bool = false
    @Published var latency: String?
    @Published var isTestingPing = false
    @Published var pingResult: String?
    @Published var connectionTestResult: String?
    @Published var profiles: [ProxyProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var connectionHistory: [String] = []

    private let proxyService = ProxyService.shared
    private let defaults = UserDefaults.standard

    var selectedProfile: ProxyProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var proxyConfig: ProxyConfig {
        ProxyConfig(
            host: host,
            port: Int(port) ?? 1088,
            username: username,
            password: password,
            isEnabled: isEnabled
        )
    }

    init() {
        loadProfiles()
        loadConfig()
        if isEnabled {
            NetworkService.shared.setProxy(proxyConfig)
        }
    }

    // MARK: - Profile Management

    func loadProfile(_ profile: ProxyProfile) {
        host = profile.host
        port = String(profile.port)
        username = profile.username
        password = profile.password
        selectedProfileID = profile.id
        saveConfig()
    }

    func saveAsProfile(name: String) {
        let profile = ProxyProfile(
            name: name,
            host: host,
            port: Int(port) ?? 1088,
            username: username,
            password: password
        )
        profiles.append(profile)
        selectedProfileID = profile.id
        saveProfiles()
    }

    func deleteProfile(_ profile: ProxyProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }
        saveProfiles()
    }

    func copyConfigToClipboard() {
        let text = "\(host):\(port)@\(username):\(password)"
        UIPasteboard.general.string = text
    }

    // MARK: - Test Actions

    func testPing() {
        guard !host.isEmpty, let portInt = Int(port) else {
            pingResult = "Invalid host or port"
            return
        }

        isTestingPing = true
        pingResult = nil

        Task {
            let result = await proxyService.testPing(host: host, port: portInt)
            isTestingPing = false

            if let latency = result {
                pingResult = String(format: "%.1f ms", latency * 1000)
                connectionHistory.insert("Ping: \(pingResult!) at \(Date().formatted(date: .omitted, time: .shortened))", at: 0)
            } else {
                pingResult = "Connection failed"
                connectionHistory.insert("Ping failed at \(Date().formatted(date: .omitted, time: .shortened))", at: 0)
            }
        }
    }

    func testSOCKS5Connection() {
        guard !host.isEmpty, let portInt = Int(port) else {
            connectionTestResult = "Invalid host or port"
            return
        }

        connectionTestResult = "Testing..."

        Task {
            let success = await proxyService.socks5Connect(
                host: host,
                port: portInt,
                username: username,
                password: password,
                targetHost: "httpbin.org",
                targetPort: 80
            )

            connectionTestResult = success ? "SOCKS5 connection successful" : "SOCKS5 connection failed"
            connectionHistory.insert("SOCKS5: \(connectionTestResult!) at \(Date().formatted(date: .omitted, time: .shortened))", at: 0)
        }
    }

    func toggleProxy(_ enabled: Bool) {
        isEnabled = enabled
        NetworkService.shared.setProxy(enabled ? proxyConfig : nil)
        saveConfig()
    }

    func saveConfig() {
        let dict: [String: Any] = [
            "host": host,
            "port": port,
            "username": username,
            "password": password,
            "isEnabled": isEnabled
        ]
        defaults.set(dict, forKey: "proxyConfig")
        if let id = selectedProfileID {
            defaults.set(id.uuidString, forKey: "selectedProfileID")
        }
    }

    private func loadConfig() {
        guard let dict = defaults.dictionary(forKey: "proxyConfig") else { return }
        host = dict["host"] as? String ?? "103.166.253.92"
        port = dict["port"] as? String ?? "1088"
        username = dict["username"] as? String ?? "test"
        password = dict["password"] as? String ?? "test"
        isEnabled = dict["isEnabled"] as? Bool ?? false
        if let idString = defaults.string(forKey: "selectedProfileID"),
           let id = UUID(uuidString: idString) {
            selectedProfileID = id
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "proxyProfiles")
        }
    }

    private func loadProfiles() {
        guard let data = defaults.data(forKey: "proxyProfiles"),
              let items = try? JSONDecoder().decode([ProxyProfile].self, from: data) else {
            return
        }
        profiles = items
    }
}
