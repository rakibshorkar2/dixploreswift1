import Foundation
import Network

class ProxyService: ObservableObject {
    static let shared = ProxyService()

    func testPing(host: String, port: Int, timeout: TimeInterval = 5) async -> TimeInterval? {
        let start = Date()
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port)) ?? 1080,
            using: .tcp
        )

        return await withCheckedContinuation { continuation in
            let guardLock = NSLock()
            var didResume = false

            let timeoutTask = DispatchWorkItem {
                guardLock.lock()
                let shouldResume = !didResume
                if shouldResume { didResume = true }
                guardLock.unlock()
                guard shouldResume else { return }
                connection.cancel()
                continuation.resume(returning: nil)
            }

            connection.stateUpdateHandler = { state in
                guardLock.lock()
                let shouldResume = !didResume
                if shouldResume { didResume = true }
                guardLock.unlock()
                guard shouldResume else { return }

                timeoutTask.cancel()
                connection.cancel()

                switch state {
                case .ready:
                    continuation.resume(returning: Date().timeIntervalSince(start))
                default:
                    continuation.resume(returning: nil)
                }
            }

            connection.start(queue: .global())
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
        }
    }

    func socks5Connect(host: String, port: Int, username: String, password: String,
                       targetHost: String, targetPort: Int) async -> Bool {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port)) ?? 1080,
            using: .tcp
        )

        return await withCheckedContinuation { continuation in
            let guardLock = NSLock()
            var didResume = false

            connection.stateUpdateHandler = { state in
                guardLock.lock()
                let shouldResume = !didResume
                if shouldResume { didResume = true }
                guardLock.unlock()
                guard shouldResume else { return }

                switch state {
                case .ready:
                    self.performSOCKS5Handshake(connection: connection,
                                                  username: username,
                                                  password: password,
                                                  targetHost: targetHost,
                                                  targetPort: targetPort) { success in
                        connection.cancel()
                        continuation.resume(returning: success)
                    }
                case .failed, .cancelled:
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    private func performSOCKS5Handshake(connection: NWConnection, username: String,
                                         password: String, targetHost: String,
                                         targetPort: Int, completion: @escaping (Bool) -> Void) {
        let handshake = Data([0x05, 0x01, 0x02])
        connection.send(content: handshake, completion: .contentProcessed { error in
            guard error == nil else { completion(false); return }
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, _ in
                guard let data = data, data.count == 2 else { completion(false); return }
                let authMethod = data[1]
                switch authMethod {
                case 0x02:
                    self.sendUsernamePasswordAuth(connection: connection,
                                                   username: username,
                                                   password: password,
                                                   targetHost: targetHost,
                                                   targetPort: targetPort,
                                                   completion: completion)
                case 0x00:
                    self.sendConnectRequest(connection: connection,
                                            targetHost: targetHost,
                                            targetPort: targetPort,
                                            completion: completion)
                default:
                    completion(false)
                }
            }
        })
    }

    private func sendUsernamePasswordAuth(connection: NWConnection, username: String,
                                           password: String, targetHost: String,
                                           targetPort: Int,
                                           completion: @escaping (Bool) -> Void) {
        var authData = Data([0x01])
        let unameData = Data(username.utf8)
        authData.append(UInt8(unameData.count))
        authData.append(unameData)
        let passData = Data(password.utf8)
        authData.append(UInt8(passData.count))
        authData.append(passData)

        connection.send(content: authData, completion: .contentProcessed { error in
            guard error == nil else { completion(false); return }
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, _ in
                guard let data = data, data.count == 2, data[1] == 0x00
                else { completion(false); return }
                self.sendConnectRequest(connection: connection,
                                        targetHost: targetHost,
                                        targetPort: targetPort,
                                        completion: completion)
            }
        })
    }

    private func sendConnectRequest(connection: NWConnection, targetHost: String,
                                     targetPort: Int,
                                     completion: @escaping (Bool) -> Void) {
        var request = Data([0x05, 0x01, 0x00, 0x03])
        let hostData = Data(targetHost.utf8)
        request.append(UInt8(hostData.count))
        request.append(hostData)
        var portBE = UInt16(targetPort).bigEndian
        withUnsafeBytes(of: &portBE) { request.append(contentsOf: $0) }

        connection.send(content: request, completion: .contentProcessed { error in
            guard error == nil else { completion(false); return }
            connection.receive(minimumIncompleteLength: 10, maximumLength: 255) { data, _, _, _ in
                guard let data = data, data.count >= 10, data[1] == 0x00
                else { completion(false); return }
                completion(true)
            }
        })
    }
}
