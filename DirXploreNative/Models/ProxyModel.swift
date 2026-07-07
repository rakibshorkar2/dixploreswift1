import Foundation

enum ProxyProtocol: String, Codable, Sendable {
    case socks5 = "SOCKS5"
    case socks4 = "SOCKS4"
    case http = "HTTP"
    case https = "HTTPS"

    var systemKey: String {
        switch self {
        case .socks5, .socks4: return "SOCKS"
        case .http: return "HTTP"
        case .https: return "HTTPS"
        }
    }
}

struct ProxyModel: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var protocolType: ProxyProtocol
    var host: String
    var port: Int
    var username: String
    var password: String
    var isActive: Bool
    var latencyMs: Double?

    var uri: String {
        var result = "\(protocolType.rawValue.lowercased())://"
        if !username.isEmpty {
            result += "\(username):\(password)@"
        }
        result += "\(host):\(port)"
        return result
    }

    var displayUri: String {
        var result = "\(protocolType.rawValue.lowercased())://"
        if !username.isEmpty {
            result += "\(username):****@"
        }
        result += "\(host):\(port)"
        return result
    }

    static func from(uri: String) -> ProxyModel? {
        guard let url = URL(string: uri) else { return nil }
        let proto: ProxyProtocol
        switch url.scheme?.lowercased() {
        case "socks5": proto = .socks5
        case "socks4": proto = .socks4
        case "https": proto = .https
        default: proto = .http
        }
        return ProxyModel(
            id: UUID().uuidString,
            protocolType: proto,
            host: url.host ?? "",
            port: url.port ?? 1080,
            username: url.user ?? "",
            password: url.password ?? "",
            isActive: false,
            latencyMs: nil
        )
    }
}
