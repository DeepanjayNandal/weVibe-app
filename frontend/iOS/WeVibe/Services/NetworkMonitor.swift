import Foundation
import Network
import Observation

/// Monitors device network connectivity using NWPathMonitor.
/// Inject at app level and observe `isConnected` to show offline UI.
@Observable
final class NetworkMonitor {

    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.wevibe.NetworkMonitor", qos: .utility)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
