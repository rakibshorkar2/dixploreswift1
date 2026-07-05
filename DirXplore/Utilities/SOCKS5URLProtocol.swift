import Foundation

class SOCKS5URLProtocol: URLProtocol {
    private static let handledKey = "SOCKS5ProtocolHandled"
    static let proxyTimeout: TimeInterval = 30

    private static let workQueue = DispatchQueue(label: "com.dirxplore.socks5.io", qos: .userInitiated)
    private var isCancelled = false

    private let headerEndMarker = Data("\r\n\r\n".utf8)

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

        Self.workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let httpReq = self.buildHTTPRequest(url: url, request: finalRequest)
                var result = try httpReq.withUnsafeBytes { rawBuf in
                    try self.fetch(proxy: proxy, host: host, port: UInt16(url.port ?? 80),
                                   requestBody: rawBuf.baseAddress!, requestLen: httpReq.count)
                }
                defer { socks5_free_result(&result) }
                guard !self.isCancelled else { return }
                try self.deliver(result: &result, url: url)
            } catch let e as SocksError {
                self.deliverError(e)
            } catch {
                self.deliverError(.systemError(0, error.localizedDescription))
            }
        }
    }

    override func stopLoading() {
        isCancelled = true
    }

    // MARK: - C bridge

    private func fetch(proxy: ProxyConfig, host: String, port: UInt16,
                       requestBody: UnsafeRawPointer, requestLen: Int) throws -> socks5_result_t {
        let timeout = Self.proxyTimeout
        let pHost = proxy.host.withCString { strdup($0) }
        let tHost = host.withCString { strdup($0) }
        let pUser = proxy.username?.withCString { strdup($0) }
        let pPass = proxy.password?.withCString { strdup($0) }
        defer {
            free(pHost); free(tHost)
            if let p = pUser { free(p) }
            if let p = pPass { free(p) }
        }

        var result = socks5_fetch(
            pHost, UInt16(proxy.port),
            pUser, pPass,
            tHost, port,
            requestBody, requestLen,
            timeout
        )
        if result.success == 0 {
            let msg = String(cString: &result.error_msg.0)
            socks5_free_result(&result)
            throw SocksError.proxyConnectFailed(msg)
        }
        return result
    }

    // MARK: - HTTP request

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

    // MARK: - Response

    private func deliver(result: inout socks5_result_t, url: URL) throws {
        guard let respPtr = result.response else {
            throw SocksError.invalidResponse
        }
        let data = Data(bytes: respPtr, count: result.response_len)
        let (code, headers, body) = try parseResponse(from: data)

        guard let httpResp = HTTPURLResponse(
            url: url, statusCode: code, httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            throw SocksError.invalidResponse
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCancelled else { return }
            self.client?.urlProtocol(self, didReceive: httpResp, cacheStoragePolicy: .notAllowed)
            if !body.isEmpty {
                self.client?.urlProtocol(self, didLoad: body)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
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
        let parts = statusLine.components(separatedBy: " ")
        guard parts.count >= 2, let code = Int(parts[1]) else {
            throw SocksError.invalidResponse
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if kv.count == 2 {
                headers[kv[0].trimmingCharacters(in: .whitespaces)] =
                    kv[1].trimmingCharacters(in: .whitespaces)
            }
        }

        var body = Data(data[headerEnd.upperBound...])
        if (headers["Transfer-Encoding"] ?? "").lowercased().contains("chunked") {
            body = try decodeChunked(body)
        }
        return (code, headers, body)
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

    // MARK: - Client

    private func deliverError(_ error: SocksError) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCancelled else { return }
            self.failClient(with: error)
        }
    }

    private func failClient(with error: Error) {
        client?.urlProtocol(self, didFailWithError: error)
    }

    // MARK: - Config

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
