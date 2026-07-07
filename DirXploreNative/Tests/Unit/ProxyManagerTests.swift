import XCTest
@testable import DirXplore

final class ProxyManagerTests: XCTestCase {
    func testProxyModelURI() {
        let proxy = ProxyModel(id: "1", protocolType: .socks5, host: "127.0.0.1", port: 1080, username: "user", password: "pass", isActive: false)
        XCTAssertTrue(proxy.uri.contains("socks5://user:pass@127.0.0.1:1080"))
        XCTAssertTrue(proxy.displayUri.contains("socks5://user:****@127.0.0.1:1080"))
    }

    func testProxyFromURI() {
        let proxy = ProxyModel.from(uri: "socks5://user:pass@192.168.1.1:1080")
        XCTAssertNotNil(proxy)
        XCTAssertEqual(proxy?.protocolType, .socks5)
        XCTAssertEqual(proxy?.host, "192.168.1.1")
        XCTAssertEqual(proxy?.port, 1080)
        XCTAssertEqual(proxy?.username, "user")
        XCTAssertEqual(proxy?.password, "pass")
    }

    func testProxyFromHTTPURI() {
        let proxy = ProxyModel.from(uri: "http://proxy.example.com:8080")
        XCTAssertNotNil(proxy)
        XCTAssertEqual(proxy?.protocolType, .http)
        XCTAssertEqual(proxy?.host, "proxy.example.com")
        XCTAssertEqual(proxy?.port, 8080)
    }

    func testProxyWithNoAuth() {
        let proxy = ProxyModel(id: "2", protocolType: .http, host: "10.0.0.1", port: 3128, username: "", password: "", isActive: true)
        XCTAssertTrue(proxy.uri == "http://10.0.0.1:3128")
    }

    func testProxyModelEquality() {
        let a = ProxyModel(id: "1", protocolType: .socks5, host: "a.com", port: 1080)
        let b = ProxyModel(id: "1", protocolType: .socks5, host: "a.com", port: 1080)
        XCTAssertEqual(a, b)
    }

    func testProxyModelInequality() {
        let a = ProxyModel(id: "1", protocolType: .socks5, host: "a.com", port: 1080)
        let b = ProxyModel(id: "2", protocolType: .http, host: "b.com", port: 8080)
        XCTAssertNotEqual(a, b)
    }
}
