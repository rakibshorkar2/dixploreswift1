import Foundation

actor SOCKS5Proxy {
    static let shared = SOCKS5Proxy()

    private var proxyHost: String = ""
    private var proxyPort: Int = 0
    var isEnabled: Bool = false

    func configure(host: String, port: Int) {
        proxyHost = host
        proxyPort = port
    }

    func urlSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        if isEnabled && !proxyHost.isEmpty {
            config.connectionProxyDictionary = [
                "SOCKSEnable": NSNumber(value: true),
                "SOCKSProxy": proxyHost,
                "SOCKSPort": NSNumber(value: proxyPort)
            ]
        }
        return config
    }
}
