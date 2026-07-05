import Foundation

struct ProxyConfig: Codable, Identifiable {
    let id = UUID()
    var host: String
    var port: Int
    var username: String
    var password: String
    var isEnabled: Bool
    var latency: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id, host, port, username, password, isEnabled, latency
    }

    static let `default` = ProxyConfig(
        host: "103.166.253.92",
        port: 1088,
        username: "test",
        password: "test",
        isEnabled: false
    )
}
