import Foundation
import Network

@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var isConnected = true
    var isExpensive = false
    var isConstrained = false
    var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, ethernet, unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.dirxplore.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
                if path.usesInterfaceType(.wifi) { self?.connectionType = .wifi }
                else if path.usesInterfaceType(.cellular) { self?.connectionType = .cellular }
                else if path.usesInterfaceType(.wiredEthernet) { self?.connectionType = .ethernet }
                else { self?.connectionType = .unknown }
            }
        }
        monitor.start(queue: queue)
    }
}
