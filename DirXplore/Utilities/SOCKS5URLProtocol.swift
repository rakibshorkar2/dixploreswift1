import Foundation

class SOCKS5URLProtocol: URLProtocol {
    private static let handledKey = "SOCKS5ProtocolHandled"
    static let proxyTimeout: TimeInterval = 30

    private static let workQueue = DispatchQueue(label: "com.dirxplore.socks5.io", qos: .userInitiated)

    private var isCancelled = false
    private var tunnelFd: Int32 = -1

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
            failClient(with: SocksError.invalidProxyConfig)
            return
        }

        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        let finalRequest = mutableRequest as URLRequest
        let timeout = Self.proxyTimeout

        Self.workQueue.async { [weak self] in
            guard let self else { return }

            let fd: Int32
            do {
                fd = try Socks5Client.tunnel(
                    proxyHost: proxy.host, proxyPort: UInt16(proxy.port),
                    targetHost: host, targetPort: UInt16(url.port ?? 80),
                    username: proxy.username, password: proxy.password,
                    timeout: timeout
                )
            } catch {
                self.deliverError(error as? SocksError ?? .systemError(0, error.localizedDescription))
                return
            }

            guard !self.isCancelled else { close(fd); return }
            self.tunnelFd = fd

            let responseData: Data
            do {
                responseData = try self.fetchHTTP(fd: fd, url: url,
                                                   request: finalRequest,
                                                   timeout: timeout)
            } catch {
                close(fd)
                self.tunnelFd = -1
                self.deliverError(error as? SocksError ?? .systemError(0, error.localizedDescription))
                return
            }

            close(fd)
            self.tunnelFd = -1

            guard !self.isCancelled else { return }

            do {
                try self.deliverResponse(data: responseData, url: url)
            } catch {
                self.deliverError(error as? SocksError ?? .systemError(0, error.localizedDescription))
            }
        }
    }

    override func stopLoading() {
        isCancelled = true
        let fd = tunnelFd
        if fd >= 0 {
            shutdown(fd, SHUT_RDWR)
        }
    }

    // MARK: - HTTP over tunnel

    private func fetchHTTP(fd: Int32, url: URL, request: URLRequest,
                           timeout: TimeInterval) throws -> Data {
        let httpReq = buildHTTPRequest(url: url, request: request)
        try Socks5Client.sendAll(fd: fd, data: httpReq, timeout: timeout)
        return try readFullResponse(fd: fd, timeout: timeout)
    }

    private func buildHTTPRequest(url: URL, request: URLRequest) -> Data {
        let method = request.httpMethod ?? "GET"
        var path = url.absoluteURL.path
        if !path.hasPrefix("/") { path = "/" + path }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        path = encoded.isEmpty ? "/" : encoded
        if let query = url.query {
            let eq = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            path += "?\(eq)"
        }

        var raw = "\(method) \(path) HTTP/1.1\r\n"
        raw += "Host: \(url.host ?? "")"
        if let port = url.port, port != 80 { raw += ":\(port)" }
        raw += "\r\n"
        raw += "Connection: close\r\n"

        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            let lower = key.lowercased()
            if lower != "host" && lower != "connection" {
                raw += "\(key): \(value)\r\n"
            }
        }

        if let body = request.httpBody {
            raw += "Content-Length: \(body.count)\r\n\r\n"
            var data = Data(raw.utf8)
            data.append(body)
            return data
        } else {
            raw += "\r\n"
            return Data(raw.utf8)
        }
    }

    // MARK: - Response reading

    private let headerEndMarker = Data("\r\n\r\n".utf8)

    private func readFullResponse(fd: Int32, timeout: TimeInterval) throws -> Data {
        var data = try readHeaders(fd: fd, timeout: timeout)
        let body = try readBody(fd: fd, from: data, timeout: timeout)
        data.append(body)
        return data
    }

    private func readHeaders(fd: Int32, timeout: TimeInterval) throws -> Data {
        var data = Data()
        while data.range(of: headerEndMarker) == nil {
            let chunk = try Socks5Client.recvSome(fd: fd, maxLength: 65536, timeout: timeout)
            data.append(chunk)
        }
        return data
    }

    private func readBody(fd: Int32, from responseData: Data, timeout: TimeInterval) throws -> Data {
        guard let headerEnd = responseData.firstRange(of: headerEndMarker) else { return Data() }
        let headerPart = String(data: responseData[..<headerEnd.lowerBound], encoding: .utf8) ?? ""
        let headers = parseHeaderFields(from: headerPart)
        let alreadyRead = Data(responseData[headerEnd.upperBound...])

        // Content-Length
        if let clStr = headers["Content-Length"], let cl = Int(clStr) {
            let remaining = cl - alreadyRead.count
            if remaining > 0 {
                let more = try Socks5Client.recvExact(fd: fd, count: remaining, timeout: timeout)
                return alreadyRead + more
            }
            return alreadyRead
        }

        // No Content-Length: read until connection closes
        var body = alreadyRead
        while true {
            do {
                let chunk = try Socks5Client.recvSome(fd: fd, maxLength: 65536, timeout: timeout)
                body.append(chunk)
            } catch SocksError.connectFailed {
                break
            } catch SocksError.timeout {
                break
            }
        }

        // Decode chunked if needed
        if (headers["Transfer-Encoding"] ?? "").lowercased().contains("chunked") {
            return try decodeChunked(body)
        }
        return body
    }

    private func decodeChunked(_ data: Data) throws -> Data {
        var result = Data()
        var offset = 0
        while offset < data.count {
            guard let crlf = data[offset...].firstRange(of: Data("\r\n".utf8)) else {
                throw SocksError.invalidResponse
            }
            let sizeStr = String(data: data[offset..<crlf.lowerBound], encoding: .utf8) ?? ""
            let size = Int(sizeStr, radix: 16) ?? 0
            offset = crlf.upperBound
            if size == 0 { break }
            guard offset + size <= data.count else { throw SocksError.invalidResponse }
            result.append(data[offset..<offset + size])
            offset += size
            guard offset + 2 <= data.count,
                  data[offset..<offset + 2] == Data("\r\n".utf8) else {
                throw SocksError.invalidResponse
            }
            offset += 2
        }
        return result
    }

    // MARK: - Parsing

    private func parseHeaderFields(from headerString: String) -> [String: String] {
        let lines = headerString.components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                headers[parts[0].trimmingCharacters(in: .whitespaces)] =
                    parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return headers
    }

    private func parseResponse(from data: Data) throws
        -> (statusCode: Int, headers: [String: String], body: Data) {
        guard let headerEnd = data.firstRange(of: headerEndMarker) else {
            throw SocksError.invalidResponse
        }
        let headerPart = data[data.startIndex..<headerEnd.lowerBound]
        guard let headerString = String(data: headerPart, encoding: .utf8) else {
            throw SocksError.invalidResponse
        }
        let lines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { throw SocksError.invalidResponse }
        let statusParts = statusLine.components(separatedBy: " ")
        guard statusParts.count >= 2, let code = Int(statusParts[1]) else {
            throw SocksError.invalidResponse
        }

        let headers = parseHeaderFields(from: headerString)
        let body = Data(data[headerEnd.upperBound...])
        return (code, headers, body)
    }

    // MARK: - Client delivery

    private func deliverResponse(data: Data, url: URL) throws {
        let (code, headers, body) = try parseResponse(from: data)

        guard let response = HTTPURLResponse(
            url: url, statusCode: code, httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            throw SocksError.invalidResponse
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCancelled else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !body.isEmpty {
                self.client?.urlProtocol(self, didLoad: body)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    private func deliverError(_ error: SocksError) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCancelled else { return }
            self.failClient(with: error)
        }
    }

    private func failClient(with error: Error) {
        client?.urlProtocol(self, didFailWithError: error)
    }

    // MARK: - Proxy config

    private static var _proxyConfig: ProxyConfig?
    private static let lock = NSLock()

    static var proxyConfig: ProxyConfig? {
        get { lock.withLock { _proxyConfig } }
        set { lock.withLock { _proxyConfig = newValue } }
    }
}

private extension NSLock {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
}
