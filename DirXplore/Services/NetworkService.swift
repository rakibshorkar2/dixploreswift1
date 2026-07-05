import Foundation

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    private let session: URLSession
    private var proxyConfig: ProxyConfig?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func setProxy(_ config: ProxyConfig?) {
        proxyConfig = config
    }

    func fetchDirectoryListing(url: URL) async throws -> [DirectoryEntry] {
        let request = URLRequest(url: url, timeoutInterval: 30)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidData
        }

        let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""

        if contentType.contains("text/html") || html.contains("<html") || html.contains("<HTML") {
            return DirectoryParser.shared.parseApacheDirectoryListing(html: html, baseURL: url)
        } else if contentType.contains("text/plain") || contentType.contains("application/octet-stream") {
            return DirectoryParser.shared.parseFTPStyleListing(text: html, baseURL: url)
        }

        return DirectoryParser.shared.parseApacheDirectoryListing(html: html, baseURL: url)
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
