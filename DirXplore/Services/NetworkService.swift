import Foundation

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    private var session: URLSession
    private var proxyConfig: ProxyConfig?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    private func rebuildSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        if let proxy = proxyConfig, proxy.isEnabled {
            config.protocolClasses = [SOCKS5URLProtocol.self]
            SOCKS5URLProtocol.proxyConfig = proxy
        } else {
            config.protocolClasses = nil
            SOCKS5URLProtocol.proxyConfig = nil
        }

        session.invalidateAndCancel()
        session = URLSession(configuration: config)
    }

    func setProxy(_ config: ProxyConfig?) {
        proxyConfig = config
        rebuildSession()
    }

    func fetchDirectoryListing(url: URL) async throws -> [DirectoryEntry] {
        var currentURL = url
        for attempt in 0..<5 {
            let request = URLRequest(url: currentURL, timeoutInterval: 15)
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                if attempt == 0 {
                    let altURL = currentURL.absoluteString.hasSuffix("/")
                        ? URL(string: String(currentURL.absoluteString.dropLast())) ?? currentURL
                        : URL(string: currentURL.absoluteString + "/") ?? currentURL
                    if altURL != currentURL {
                        currentURL = altURL
                    } else {
                        throw error
                    }
                    continue
                }
                throw error
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if (300...399).contains(httpResponse.statusCode),
               let location = httpResponse.allHeaderFields["Location"] as? String,
               let redirectURL = URL(string: location, relativeTo: currentURL) {
                currentURL = redirectURL
                continue
            }

            guard httpResponse.statusCode == 200 else {
                if attempt == 0 {
                    let altURL = currentURL.absoluteString.hasSuffix("/")
                        ? URL(string: String(currentURL.absoluteString.dropLast())) ?? currentURL
                        : URL(string: currentURL.absoluteString + "/") ?? currentURL
                    if altURL != currentURL {
                        currentURL = altURL
                        continue
                    }
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }

            guard let html = String(data: data, encoding: .utf8) else {
                throw NetworkError.invalidData
            }

            let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""

            let baseURL = httpResponse.url ?? currentURL

            if contentType.contains("text/html") || html.contains("<html") || html.contains("<HTML") {
                return DirectoryParser.shared.parseApacheDirectoryListing(html: html, baseURL: baseURL)
            } else if contentType.contains("text/plain") || contentType.contains("application/octet-stream") {
                return DirectoryParser.shared.parseFTPStyleListing(text: html, baseURL: baseURL)
            }

            return DirectoryParser.shared.parseApacheDirectoryListing(html: html, baseURL: baseURL)
        }
        throw NetworkError.invalidResponse
    }

    func downloadFile(url: URL, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        let request = URLRequest(url: url, timeoutInterval: 3600)
        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let expectedLength = httpResponse.expectedContentLength
        var downloaded: Int64 = 0
        var data = Data()

        for try await byte in asyncBytes {
            data.append(byte)
            downloaded += 1
            if expectedLength > 0 {
                let progress = Double(downloaded) / Double(expectedLength)
                progressHandler(min(progress, 1.0))
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)
        try data.write(to: tempURL)
        return tempURL
    }
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .invalidData:
            return "Invalid data received"
        }
    }
}
