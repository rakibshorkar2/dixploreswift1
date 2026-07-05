import Foundation
import Network

final class GuardFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func claim() -> Bool {
        lock.lock()
        if _value {
            lock.unlock()
            return false
        }
        _value = true
        lock.unlock()
        return true
    }
}

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
            let flag = GuardFlag()
            let timeoutTask = DispatchWorkItem {
                guard flag.claim() else { return }
                connection.cancel()
                continuation.resume(returning: nil)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard flag.claim() else { return }
                    timeoutTask.cancel()
                    connection.cancel()
                    continuation.resume(returning: Date().timeIntervalSince(start))
                case .failed, .cancelled:
                    guard flag.claim() else { return }
                    timeoutTask.cancel()
                    connection.cancel()
                    continuation.resume(returning: nil)
                case .setup, .preparing, .waiting:
                    break
                @unknown default:
                    break
                }
            }

            connection.start(queue: .global())
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
        }
    }

    func socks5Connect(host: String, port: Int, username: String, password: String,
                       targetHost: String, targetPort: Int, timeout: TimeInterval = 10) async -> Bool {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port)) ?? 1080,
            using: .tcp
        )

        return await withCheckedContinuation { continuation in
            let flag = GuardFlag()

            let timeoutTask = DispatchWorkItem {
                guard flag.claim() else { return }
                connection.cancel()
                continuation.resume(returning: false)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard flag.claim() else { return }
                    timeoutTask.cancel()
                    self.performSOCKS5Handshake(connection: connection,
                                                  username: username,
                                                  password: password,
                                                  targetHost: targetHost,
                                                  targetPort: targetPort) { success in
                        connection.cancel()
                        continuation.resume(returning: success)
                    }
                case .failed, .cancelled:
                    guard flag.claim() else { return }
                    timeoutTask.cancel()
                    connection.cancel()
                    continuation.resume(returning: false)
                case .setup, .preparing:
                    break
                default:
                    break
                }
            }

            connection.start(queue: .global())
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
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
        var request = Data([0x05, 0x01, 0x00])
        if let ipv4 = parseIPv4(targetHost) {
            request.append(0x01)
            request.append(contentsOf: ipv4)
        } else {
            request.append(0x03)
            let hostData = Data(targetHost.utf8)
            request.append(UInt8(hostData.count))
            request.append(hostData)
        }
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
}
