import Foundation
import Darwin

// MARK: - Error type

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

// MARK: - POSIX SOCKS5 tunnel

struct Socks5Client {
    /// Connect to proxy, perform SOCKS5 handshake, return connected fd.
    /// Caller must close() the fd when done.
    static func tunnel(proxyHost: String, proxyPort: UInt16,
                       targetHost: String, targetPort: UInt16,
                       username: String?, password: String?,
                       timeout: TimeInterval) throws -> Int32 {
        let fd = try makeSocket()
        do {
            try tcpConnect(fd: fd, host: proxyHost, port: proxyPort, timeout: timeout)
            try handshake(fd: fd, targetHost: targetHost, targetPort: targetPort,
                          username: username, password: password, timeout: timeout)
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    // MARK: - Socket I/O (public for use by URLProtocol)

    @discardableResult
    static func sendAll(fd: Int32, data: Data, timeout: TimeInterval) throws -> Int {
        var remaining = data.count
        var offset = 0
        while remaining > 0 {
            try waitWritable(fd: fd, timeout: timeout)
            let n = data.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!.advanced(by: offset), remaining, 0)
            }
            if n < 0 { throw systemError("send") }
            remaining -= n
            offset += n
        }
        return offset
    }

    static func recvExact(fd: Int32, count: Int, timeout: TimeInterval) throws -> Data {
        var data = Data(count: count)
        var remaining = count
        var offset = 0
        while remaining > 0 {
            try waitReadable(fd: fd, timeout: timeout)
            let n = data.withUnsafeMutableBytes { ptr in
                Darwin.recv(fd, ptr.baseAddress!.advanced(by: offset), remaining, 0)
            }
            if n < 0 { throw systemError("recv") }
            if n == 0 { throw SocksError.connectFailed(replyCode: nil) }
            remaining -= n
            offset += n
        }
        return data
    }

    static func recvSome(fd: Int32, maxLength: Int, timeout: TimeInterval) throws -> Data {
        try waitReadable(fd: fd, timeout: timeout)
        var buf = [UInt8](repeating: 0, count: maxLength)
        let n = Darwin.recv(fd, &buf, maxLength, 0)
        if n < 0 { throw systemError("recv") }
        if n == 0 { throw SocksError.connectFailed(replyCode: nil) }
        return Data(buf[0..<n])
    }

    // MARK: - Socket creation

    private static func makeSocket() throws -> Int32 {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw systemError("socket") }
        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))
        return fd
    }

    // MARK: - TCP connect with poll() timeout

    private static func tcpConnect(fd: Int32, host: String, port: UInt16, timeout: TimeInterval) throws {
        var addr = try resolve(host: host, port: port)
        // non-blocking connect
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0 else { throw systemError("fcntl(F_GETFL)") }
        guard fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else { throw systemError("fcntl(F_SETFL)") }
        defer { fcntl(fd, F_SETFL, flags) }

        let rc = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.connect(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if rc == 0 { return } // immediate connect
        guard errno == EINPROGRESS else { throw SocksError.proxyConnectFailed("connect: \(errnoDesc())") }

        try waitWritable(fd: fd, timeout: timeout)
        var err: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len) >= 0, err == 0 else {
            throw SocksError.proxyConnectFailed("after connect: \(errnoDesc(Int(err)))")
        }
    }

    private static func resolve(host: String, port: UInt16) throws -> sockaddr_in {
        if let ipv4 = parseIPv4(host) {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = CFSwapInt16HostToBig(port)
            addr.sin_addr = ipv4
            return addr
        }
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(host, nil, &hints, &res)
        guard rc == 0, let r = res else { throw SocksError.proxyConnectFailed("getaddrinfo(\(host))") }
        defer { freeaddrinfo(res) }
        var addr = r.pointee.ai_addr!.withMemoryRebound(to: sockaddr_in.self, capacity: 1, { $0.pointee })
        addr.sin_port = CFSwapInt16HostToBig(port)
        return addr
    }

    // MARK: - poll() helpers

    private static let POLL_IN: Int16 = 0x0001
    private static let POLL_OUT: Int16 = 0x0004
    private static let POLL_ERR: Int16 = 0x0008
    private static let POLL_HUP: Int16 = 0x0010

    private static func waitWritable(fd: Int32, timeout: TimeInterval) throws {
        try poll(fd: fd, events: POLL_OUT, timeout: timeout)
    }

    private static func waitReadable(fd: Int32, timeout: TimeInterval) throws {
        try poll(fd: fd, events: POLL_IN, timeout: timeout)
    }

    private static func poll(fd: Int32, events: Int16, timeout: TimeInterval) throws {
        var pfd = pollfd(fd: fd, events: events, revents: 0)
        let ms = Int32(min(timeout * 1000, Double(Int32.max)))
        let rc = Darwin.poll(&pfd, 1, max(ms, 0))
        if rc < 0 { throw systemError("poll") }
        if rc == 0 { throw SocksError.timeout(timeout) }
        if pfd.revents & POLL_ERR != 0 {
            var err: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len)
            throw SocksError.proxyConnectFailed("socket error: \(errnoDesc(Int(err)))")
        }
        if pfd.revents & POLL_HUP != 0 {
            throw SocksError.connectFailed(replyCode: nil)
        }
    }

    // MARK: - SOCKS5 handshake

    private static func handshake(fd: Int32, targetHost: String, targetPort: UInt16,
                                   username: String?, password: String?,
                                   timeout: TimeInterval) throws {
        try sendAll(fd: fd, data: Data([0x05, 0x01, 0x02]), timeout: timeout)
        let sr = try recvExact(fd: fd, count: 2, timeout: timeout)
        guard sr[0] == 0x05 else { throw SocksError.handshakeFailed }
        switch sr[1] {
        case 0x00: break
        case 0x02:
            guard let u = username, let p = password else { throw SocksError.unsupportedAuth }
            try auth(fd: fd, username: u, password: p, timeout: timeout)
        default:
            throw SocksError.unsupportedAuth
        }
        try connect(fd: fd, targetHost: targetHost, targetPort: targetPort, timeout: timeout)
    }

    private static func auth(fd: Int32, username: String, password: String, timeout: TimeInterval) throws {
        var msg = Data([0x01])
        let uData = Data(username.utf8)
        msg.append(UInt8(uData.count)); msg.append(uData)
        let pData = Data(password.utf8)
        msg.append(UInt8(pData.count)); msg.append(pData)
        try sendAll(fd: fd, data: msg, timeout: timeout)
        let r = try recvExact(fd: fd, count: 2, timeout: timeout)
        guard r[0] == 0x01, r[1] == 0x00 else { throw SocksError.authFailed }
    }

    private static func connect(fd: Int32, targetHost: String, targetPort: UInt16, timeout: TimeInterval) throws {
        var msg = Data([0x05, 0x01, 0x00])
        if let ipv4 = parseIPv4(targetHost) {
            msg.append(0x01)
            var s_addr = ipv4.s_addr
            withUnsafeBytes(of: &s_addr) { msg.append(contentsOf: $0) }
        } else {
            msg.append(0x03)
            let hd = Data(targetHost.utf8)
            msg.append(UInt8(hd.count))
            msg.append(hd)
        }
        var portBE = targetPort.bigEndian
        withUnsafeBytes(of: &portBE) { msg.append(contentsOf: $0) }
        try sendAll(fd: fd, data: msg, timeout: timeout)

        // Read response: 4 bytes header + variable address + 2 bytes port
        let header = try recvExact(fd: fd, count: 4, timeout: timeout)
        guard header[0] == 0x05 else { throw SocksError.connectFailed(replyCode: nil) }
        guard header[1] == 0x00 else { throw SocksError.connectFailed(replyCode: header[1]) }
        let addrLen: Int
        switch header[3] {
        case 0x01: addrLen = 4
        case 0x03: addrLen = Int(header[4]) + 1
        case 0x04: addrLen = 16
        default: throw SocksError.connectFailed(replyCode: nil)
        }
        if addrLen > 0 {
            let _ = try recvExact(fd: fd, count: addrLen, timeout: timeout)
        }
        let _ = try recvExact(fd: fd, count: 2, timeout: timeout) // port
    }

    // MARK: - Helpers

    private static func parseIPv4(_ host: String) -> in_addr? {
        var addr = in_addr()
        let rc = host.withCString { inet_pton(AF_INET, $0, &addr) }
        return rc == 1 ? addr : nil
    }

    private static func systemError(_ op: String) -> SocksError {
        .systemError(errno, "\(op): \(String(cString: strerror(errno)))")
    }

    private static func errnoDesc(_ code: Int? = nil) -> String {
        let e = code ?? Int(errno)
        return "\(e) (\(String(cString: strerror(Int32(e)))))"
    }
}
