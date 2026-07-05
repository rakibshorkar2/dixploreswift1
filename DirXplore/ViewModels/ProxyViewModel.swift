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

    private let proxyService = ProxyService.shared
    private let defaults = UserDefaults.standard

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
        loadConfig()
    }

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
            } else {
                pingResult = "Connection failed"
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
    }

    private func loadConfig() {
        guard let dict = defaults.dictionary(forKey: "proxyConfig") else { return }
        host = dict["host"] as? String ?? "103.166.253.92"
        port = dict["port"] as? String ?? "1088"
        username = dict["username"] as? String ?? "test"
        password = dict["password"] as? String ?? "test"
        isEnabled = dict["isEnabled"] as? Bool ?? false
    }
}
