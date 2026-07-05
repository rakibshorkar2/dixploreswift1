import Foundation

enum SocksError: LocalizedError {
    case invalidProxyConfig
    case proxyConnectFailed(String)
    case handshakeFailed
    case unsupportedAuth
    case authFailed
    case connectFailed(replyCode: UInt8?)
    case invalidRequest
    case invalidResponse
    case timeout(TimeInterval)
    case systemError(Int32, String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidProxyConfig: return "Invalid proxy configuration"
        case .proxyConnectFailed(let detail): return "Proxy connection failed: \(detail)"
        case .handshakeFailed: return "SOCKS5 handshake failed"
        case .unsupportedAuth: return "Unsupported authentication method"
        case .authFailed: return "SOCKS5 authentication failed"
        case .connectFailed(let code):
            if let c = code { return "SOCKS5 target connection failed (reply \(c))" }
            return "SOCKS5 target connection failed"
        case .invalidRequest: return "Invalid HTTP request"
        case .invalidResponse: return "Invalid HTTP response"
        case .timeout(let t): return "SOCKS5 proxy timed out after \(Int(t))s"
        case .systemError(let code, let desc):
            return "\(desc) (errno \(code))"
        case .cancelled: return "Request cancelled"
        }
    }
}
