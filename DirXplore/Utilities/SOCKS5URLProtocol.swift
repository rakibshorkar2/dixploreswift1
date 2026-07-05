import Foundation
import Network

class SOCKS5URLProtocol: URLProtocol {
    private static let handledKey = "SOCKS5ProtocolHandled"

    private var proxyConnection: NWConnection?
    private var buffer = Data()
    private var responseDelivered = false
    private var contentLength: Int64 = -1
    private var bodyLength: Int64 = 0

    override class func canInit(with request: URLRequest) -> Bool {
        guard let proxy = proxyConfig, proxy.isEnabled else { return false }
        if URLProtocol.property(forKey: handledKey, in: request) != nil { return false }
        return request.url?.scheme == "http"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let proxy = Self.proxyConfig, proxy.isEnabled,
              let url = request.url, let host = url.host else {
            fail(with: SOCKS5Error.invalidProxyConfig)
            return
        }

        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        let port = url.port ?? 80

        guard let proxyPort = NWEndpoint.Port(rawValue: UInt16(proxy.port)) else {
            fail(with: SOCKS5Error.invalidProxyConfig)
            return
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(proxy.host),
            port: proxyPort,
            using: .tcp
        )
        proxyConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                performHandshake(connection: connection, username: proxy.username,
                                 password: proxy.password, targetHost: host,
                                 targetPort: port, request: mutableRequest as URLRequest)
            case .failed(let error):
                fail(with: error)
            case .cancelled:
                fail(with: SOCKS5Error.connectFailed(replyCode: nil))
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    override func stopLoading() {
        proxyConnection?.cancel()
        proxyConnection = nil
    }

    // MARK: - SOCKS5 Handshake

    private func performHandshake(connection: NWConnection, username: String,
                                   password: String, targetHost: String,
                                   targetPort: Int, request: URLRequest) {
        let handshake = Data([0x05, 0x01, 0x02])
        connection.send(content: handshake, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error = error { fail(with: error); return }
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, error in
                guard let data = data, data.count == 2 else {
                    self.fail(with: error ?? SOCKS5Error.handshakeFailed); return
                }
                switch data[1] {
                case 0x02:
                    self.sendAuth(connection: connection, username: username,
                                  password: password, targetHost: targetHost,
                                  targetPort: targetPort, request: request)
                case 0x00:
                    self.sendConnect(connection: connection, targetHost: targetHost,
                                     targetPort: targetPort, request: request)
                default:
                    self.fail(with: SOCKS5Error.unsupportedAuth)
                }
            }
        })
    }

    private func sendAuth(connection: NWConnection, username: String,
                           password: String, targetHost: String,
                           targetPort: Int, request: URLRequest) {
        var authData = Data([0x01])
        let uData = Data(username.utf8); authData.append(UInt8(uData.count)); authData.append(uData)
        let pData = Data(password.utf8); authData.append(UInt8(pData.count)); authData.append(pData)

        connection.send(content: authData, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error = error { fail(with: error); return }
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, error in
                guard let data = data, data.count == 2, data[1] == 0x00 else {
                    self.fail(with: error ?? SOCKS5Error.authFailed); return
                }
                self.sendConnect(connection: connection, targetHost: targetHost,
                                 targetPort: targetPort, request: request)
            }
        })
    }

    private func sendConnect(connection: NWConnection, targetHost: String,
                              targetPort: Int, request: URLRequest) {
        var req = Data([0x05, 0x01, 0x00])
        if let ipv4 = parseIPv4(targetHost) {
            req.append(0x01)
            req.append(contentsOf: ipv4)
        } else {
            req.append(0x03)
            let hostData = Data(targetHost.utf8)
            req.append(UInt8(hostData.count)); req.append(hostData)
        }
        var portBE = UInt16(targetPort).bigEndian
        withUnsafeBytes(of: &portBE) { req.append(contentsOf: $0) }

        connection.send(content: req, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error = error { fail(with: error); return }
            connection.receive(minimumIncompleteLength: 10, maximumLength: 255) { data, _, _, error in
                guard let data = data else {
                    self.fail(with: error ?? SOCKS5Error.connectFailed(replyCode: nil)); return
                }
                guard data.count >= 2 else {
                    self.fail(with: SOCKS5Error.connectFailed(replyCode: nil)); return
                }
                let reply = data[1]
                guard reply == 0x00 else {
                    self.fail(with: SOCKS5Error.connectFailed(replyCode: reply)); return
                }
                self.sendHTTPRequest(connection: connection, request: request)
            }
        })
    }

    // MARK: - HTTP over tunnel

    private func sendHTTPRequest(connection: NWConnection, request: URLRequest) {
        guard let url = request.url else { fail(with: SOCKS5Error.invalidRequest); return }

        let method = request.httpMethod ?? "GET"
        var path = url.percentEncodedPath.isEmpty ? "/" : url.percentEncodedPath
        if let eq = url.percentEncodedQuery { path += "?\(eq)" }

        var raw = "\(method) \(path) HTTP/1.1\r\n"
        raw += "Host: \(url.host ?? "")"
        if let port = url.port, port != 80 { raw += ":\(port)" }
        raw += "\r\n"
        raw += "Connection: keep-alive\r\n"

        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            let lower = key.lowercased()
            if lower != "host" && lower != "connection" {
                raw += "\(key): \(value)\r\n"
            }
        }

        if let body = request.httpBody {
            raw += "Content-Length: \(body.count)\r\n"
            raw += "\r\n"
            var data = Data(raw.utf8)
            data.append(body)
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error = error { self?.fail(with: error); return }
                self?.readResponse(connection: connection)
            })
        } else {
            raw += "\r\n"
            connection.send(content: Data(raw.utf8), completion: .contentProcessed { [weak self] error in
                if let error = error { self?.fail(with: error); return }
                self?.readResponse(connection: connection)
            })
        }
    }

    private func readResponse(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error = error { fail(with: error); return }
            if let data = data, !data.isEmpty { buffer.append(data) }

            if !responseDelivered {
                if let (code, headers, bodyStart) = parseHTTPHeader(from: buffer) {
                    if (300...399).contains(code),
                       let location = headers["Location"],
                       let currentURL = request.url,
                       let redirectURL = URL(string: location, relativeTo: currentURL),
                       redirectURL.host == currentURL.host,
                       redirectURL.port == currentURL.port,
                       redirectURL.scheme == currentURL.scheme {
                        responseDelivered = false
                        contentLength = -1
                        bodyLength = 0
                        buffer = Data()
                        var newReq = URLRequest(url: redirectURL)
                        newReq.httpMethod = request.httpMethod
                        newReq.allHTTPHeaderFields = request.allHTTPHeaderFields
                        sendHTTPRequest(connection: connection, request: newReq)
                        return
                    }
                    responseDelivered = true
                    let httpVersion = "HTTP/1.1"
                    if let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: code,
                        httpVersion: httpVersion,
                        headerFields: headers
                    ) {
                        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    }
                    if let clStr = headers["Content-Length"], let cl = Int64(clStr) {
                        contentLength = cl
                    }
                    let bodyData = buffer[bodyStart...]
                    if !bodyData.isEmpty {
                        bodyLength += Int64(bodyData.count)
                        client?.urlProtocol(self, didLoad: bodyData)
                    }
                    buffer = Data()
                }
            } else {
                bodyLength += Int64(data?.count ?? 0)
                if let data = data { client?.urlProtocol(self, didLoad: data) }
            }

            if isComplete || (contentLength >= 0 && bodyLength >= contentLength) {
                client?.urlProtocolDidFinishLoading(self)
                cleanup()
            } else {
                readResponse(connection: connection)
            }
        }
    }

    private func parseHTTPHeader(from data: Data) -> (code: Int, headers: [String: String], bodyStart: Data.Index)? {
        guard let headerEnd = data.firstRange(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[data.startIndex..<headerEnd.lowerBound]
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { return nil }
        let statusParts = statusLine.components(separatedBy: " ")
        guard statusParts.count >= 2, let code = Int(statusParts[1]) else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return (code, headers, headerEnd.upperBound)
    }

    // MARK: - Helpers

    private func fail(with error: Error) {
        client?.urlProtocol(self, didFailWithError: error)
        cleanup()
    }

    private func cleanup() {
        proxyConnection?.cancel()
        proxyConnection = nil
    }

    private func parseIPv4(_ host: String) -> Data? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var bytes = Data()
        for p in parts {
            guard let v = UInt8(p) else { return nil }
            bytes.append(v)
        }
        return bytes
    }

    // MARK: - Proxy config

    private static var _proxyConfig: ProxyConfig?
    private static let lock = NSLock()

    static var proxyConfig: ProxyConfig? {
        get { lock.withLock { _proxyConfig } }
        set { lock.withLock { _proxyConfig = newValue } }
    }
}

enum SOCKS5Error: LocalizedError {
    case invalidProxyConfig
    case handshakeFailed
    case unsupportedAuth
    case authFailed
    case connectFailed(replyCode: UInt8?)
    case invalidRequest
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidProxyConfig: return "Invalid proxy configuration"
        case .handshakeFailed: return "SOCKS5 handshake failed"
        case .unsupportedAuth: return "Unsupported authentication method"
        case .authFailed: return "SOCKS5 authentication failed"
        case .connectFailed(let code):
            if let c = code {
                return "SOCKS5 target connection failed (reply \(c))"
            }
            return "SOCKS5 target connection failed"
        case .invalidRequest: return "Invalid HTTP request"
        case .invalidResponse: return "Invalid HTTP response"
        }
    }
}

private extension NSLock {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
}
