import Foundation
@preconcurrency import Yams

@Observable
@MainActor
final class ProxyManager {
    static let shared = ProxyManager()

    var proxies: [ProxyModel] = []
    var activeProxy: ProxyModel?
    var bypassList: [String] = []

    private let bypassKey = "proxy_bypass_list"

    private init() {
        loadProxies()
        loadBypassList()
    }

    func addBypass(_ domain: String) {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !bypassList.contains(trimmed) else { return }
        bypassList.append(trimmed)
        saveBypassList()
    }

    func removeBypass(_ domain: String) {
        bypassList.removeAll { $0 == domain }
        saveBypassList()
    }

    private func loadBypassList() {
        bypassList = UserDefaults.standard.stringArray(forKey: bypassKey) ?? []
    }

    private func saveBypassList() {
        UserDefaults.standard.set(bypassList, forKey: bypassKey)
    }

    func loadProxies() {
        let entities = ProxyRepository.shared.getAll()
        proxies = entities.map { entity in
            ProxyModel(
                id: entity.id,
                protocolType: entity.protocolType,
                host: entity.host,
                port: entity.port,
                username: entity.username,
                password: entity.password,
                isActive: entity.isActive,
                latencyMs: entity.latencyMs
            )
        }
        activeProxy = proxies.first { $0.isActive }
    }

    func addProxy(protocolType: ProxyProtocol, host: String, port: Int, username: String = "", password: String = "") {
        ProxyRepository.shared.save(protocolType: protocolType, host: host, port: port, username: username, password: password)
        loadProxies()
    }

    func updateProxy(_ proxy: ProxyModel) {
        guard let entity = ProxyRepository.shared.getAll().first(where: { $0.id == proxy.id }) else { return }
        entity.protocolType = proxy.protocolType
        entity.host = proxy.host
        entity.port = proxy.port
        entity.username = proxy.username
        entity.password = proxy.password
        entity.isActive = proxy.isActive
        ProxyRepository.shared.update(entity)
        loadProxies()
    }

    func deleteProxy(id: String) {
        ProxyRepository.shared.delete(id: id)
        loadProxies()
    }

    func deleteAllProxies() {
        ProxyRepository.shared.deleteAll()
        loadProxies()
    }

    func setActive(_ proxy: ProxyModel?) {
        ProxyRepository.shared.deactivateAll()
        if let proxy, let entity = ProxyRepository.shared.getAll().first(where: { $0.id == proxy.id }) {
            entity.isActive = true
            ProxyRepository.shared.update(entity)
        }
        loadProxies()
        updateDownloadManagerProxy()
    }

    func testProxy(_ proxy: ProxyModel) async -> Double? {
        let latency = await HTTPClient.shared.testProxy(host: proxy.host, port: proxy.port)
        if let entity = ProxyRepository.shared.getAll().first(where: { $0.id == proxy.id }) {
            entity.latencyMs = latency
            ProxyRepository.shared.update(entity)
        }
        loadProxies()
        return latency
    }

    func importFromYAML(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let yamlString = String(data: data, encoding: .utf8),
              let yaml = try? Yams.load(yaml: yamlString) as? [String: Any],
              let proxyList = yaml["proxies"] as? [[String: Any]] else { return }

        for proxyDict in proxyList {
            guard let type = proxyDict["type"] as? String,
                  let host = proxyDict["host"] as? String,
                  let port = proxyDict["port"] as? Int else { continue }
            let proto: ProxyProtocol
            switch type.lowercased() {
            case "socks5": proto = .socks5
            case "socks4": proto = .socks4
            case "https": proto = .https
            default: proto = .http
            }
            addProxy(protocolType: proto, host: host, port: port,
                     username: proxyDict["username"] as? String ?? "",
                     password: proxyDict["password"] as? String ?? "")
        }
    }

    func bulkImport(uris: [String]) {
        ProxyRepository.shared.bulkImport(uris: uris)
        loadProxies()
    }

    private func updateDownloadManagerProxy() {
        guard let active = activeProxy else {
            DownloadManager.shared.proxyConfig = nil
            return
        }
        DownloadManager.shared.proxyConfig = ProxyConfiguration(
            host: active.host,
            port: active.port,
            username: active.username,
            password: active.password,
            enabled: true,
            protocolType: active.protocolType.rawValue.lowercased()
        )
    }
}
