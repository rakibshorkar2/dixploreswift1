import Foundation
import Network

@Observable
@MainActor
final class ProxyTunnel {
    static let shared = ProxyTunnel()

    var isRunning = false
    var port: UInt16 = AppConfiguration.proxyTunnelPort

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.dirxplore.proxytunnel", qos: .utility)

    private init() {}

    func start() throws {
        guard !isRunning else { return }
        let parameters = NWParameters.tcp
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? .init(rawValue: 9090)!)
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleConnection(connection)
            }
        }
        listener?.start(queue: queue)
        isRunning = true
        AppLogger.info("Proxy tunnel started on port \(port)", category: AppLogger.proxy)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        isRunning = false
        AppLogger.info("Proxy tunnel stopped", category: AppLogger.proxy)
    }

    func tunnelURL(for originalURL: String) -> String {
        let encoded = originalURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? originalURL
        return "http://127.0.0.1:\(port)/proxy?url=\(encoded)"
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data = data else {
                connection.cancel()
                return
            }
            Task { @MainActor in
                let request = String(data: data, encoding: .utf8) ?? ""
                if let url = self.extractTargetURL(from: request) {
                    self.proxyRequest(to: url, originalRequest: request, connection: connection)
                } else {
                    let response = "HTTP/1.1 400 Bad Request\r\n\r\n"
                    connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }
        }
    }

    private func extractTargetURL(from request: String) -> String? {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return nil }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }

        if parts[0] == "GET" || parts[0] == "HEAD" {
            let path = parts[1]
            if let urlComponents = URLComponents(string: path) {
                return urlComponents.queryItems?.first(where: { $0.name == "url" })?.value?
                    .removingPercentEncoding
            }
            return nil
        }
        return nil
    }

    private func proxyRequest(to urlString: String, originalRequest: String, connection: NWConnection) {
        guard let url = URL(string: urlString) else {
            let response = "HTTP/1.1 400 Bad Request\r\n\r\n"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        let lines = originalRequest.components(separatedBy: "\r\n")
        let hasRange = lines.contains { $0.lowercased().hasPrefix("range:") }
        let rangeHeader = lines.first { $0.lowercased().hasPrefix("range:") }

        var request = URLRequest(url: url)
        request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        if hasRange, let range = rangeHeader {
            let rangeValue = range.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
            request.setValue(rangeValue, forHTTPHeaderField: "Range")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let resp = "HTTP/1.1 502 Bad Gateway\r\n\r\n\(error.localizedDescription)"
                connection.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                let resp = "HTTP/1.1 502 Bad Gateway\r\n\r\n"
                connection.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            var responseHeader = "HTTP/1.1 \(httpResponse.statusCode) OK\r\n"
            let mirrorHeaders = ["Content-Type", "Content-Length", "Accept-Ranges", "Content-Range", "Last-Modified"]
            for header in mirrorHeaders {
                if let value = httpResponse.value(forHTTPHeaderField: header) {
                    responseHeader += "\(header): \(value)\r\n"
                }
            }
            responseHeader += "\r\n"

            var responseData = Data()
            responseData.append(responseHeader.data(using: .utf8) ?? Data())
            responseData.append(data)

            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
        task.resume()
    }
}
