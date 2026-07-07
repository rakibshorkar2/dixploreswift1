import Foundation

enum HTTPError: LocalizedError {
    case invalidURL
    case noData
    case httpError(statusCode: Int, message: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .httpError(let code, let message): return "HTTP \(code): \(message)"
        case .cancelled: return "Request was cancelled"
        }
    }
}

actor HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": AppConfiguration.userAgent
        ]
        session = URLSession(configuration: config)
    }

    func get(_ urlString: String, headers: [String: String] = [:]) async throws -> Data {
        guard let url = URL(string: urlString) else { throw HTTPError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw HTTPError.noData }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.httpError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    func getString(_ urlString: String, headers: [String: String] = [:]) async throws -> String {
        let data = try await get(urlString, headers: headers)
        guard let str = String(data: data, encoding: .utf8) else {
            throw HTTPError.noData
        }
        return str
    }

    func headMetadata(_ urlString: String) async throws -> [String: String] {
        guard let url = URL(string: urlString) else { throw HTTPError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw HTTPError.noData }
        var metadata: [String: String] = [:]
        metadata["content-type"] = httpResponse.value(forHTTPHeaderField: "Content-Type")
        metadata["content-length"] = httpResponse.value(forHTTPHeaderField: "Content-Length")
        metadata["content-disposition"] = httpResponse.value(forHTTPHeaderField: "Content-Disposition")
        metadata["accept-ranges"] = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")
        metadata["last-modified"] = httpResponse.value(forHTTPHeaderField: "Last-Modified")
        metadata["transfer-encoding"] = httpResponse.value(forHTTPHeaderField: "Transfer-Encoding")
        metadata["status-code"] = "\(httpResponse.statusCode)"
        return metadata
    }

    func checkResumeSupport(_ urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 206 || httpResponse.value(forHTTPHeaderField: "Content-Range") != nil
    }

    func testProxy(host: String, port: Int, timeout: TimeInterval = 5) async -> TimeInterval? {
        let start = Date()
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: URL(string: "http://\(host):\(port)")!) { _, response, error in
                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    continuation.resume(returning: elapsed)
                }
            }
            task.resume()
        }
    }
}
