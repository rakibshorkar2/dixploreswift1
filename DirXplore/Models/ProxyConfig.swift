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

struct ProxyProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var password: String
    var dateAdded: Date

    init(id: UUID = UUID(), name: String, host: String, port: Int,
         username: String, password: String, dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.dateAdded = dateAdded
    }

    var displayString: String {
        "\(host):\(port)"
    }
}
