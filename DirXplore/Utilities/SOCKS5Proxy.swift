import Foundation
import Network

actor SOCKS5Proxy {
    static let shared = SOCKS5Proxy()

    private var proxyHost: String = ""
    private var proxyPort: Int = 0
    private var proxyUsername: String = ""
    private var proxyPassword: String = ""
    var isEnabled: Bool = false

    func configure(host: String, port: Int, username: String, password: String) {
        proxyHost = host
        proxyPort = port
        proxyUsername = username
        proxyPassword = password
    }

    func createProxyConnection(to host: String, port: Int) async -> NWConnection? {
        guard isEnabled else { return nil }

        let connection = NWConnection(
            host: NWEndpoint.Host(proxyHost),
            port: NWEndpoint.Port(rawValue: UInt16(proxyPort)) ?? 1080,
            using: .tcp
        )

        connection.start(queue: .global())

        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: connection)
                case .failed, .cancelled:
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
        }
    }

    func urlSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        if isEnabled {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesSOCKSEnable as String: true,
                kCFNetworkProxiesSOCKSProxy as String: proxyHost,
                kCFNetworkProxiesSOCKSPort as String: proxyPort,
                kCFStreamPropertySOCKSUser as String: proxyUsername,
                kCFStreamPropertySOCKSPassword as String: proxyPassword,
                kCFStreamPropertySOCKSVersion as String: kCFStreamSocketSOCKSVersion5
            ]
        }
        return config
    }
}
