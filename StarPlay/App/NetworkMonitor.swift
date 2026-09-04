import Combine
import Foundation
import Network

struct NetworkStatusSnapshot: Equatable {
    var isConnected = false
    var isWiFi = false
    var label = "Checking network"
}

final class NetworkMonitor: ObservableObject {
    @Published private(set) var snapshot = NetworkStatusSnapshot()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.c0derz.starplay.network-monitor", qos: .utility)

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot = NetworkStatusSnapshot(
                isConnected: path.status == .satisfied,
                isWiFi: path.usesInterfaceType(.wifi),
                label: Self.label(for: path)
            )
            DispatchQueue.main.async {
                self?.snapshot = snapshot
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private static func label(for path: NWPath) -> String {
        guard path.status == .satisfied else { return "No network connection" }
        if path.usesInterfaceType(.wifi) { return "Connected over Wi-Fi" }
        if path.usesInterfaceType(.wiredEthernet) { return "Connected over Ethernet" }
        if path.usesInterfaceType(.cellular) { return "Cellular network" }
        return "Connected"
    }
}

struct ReceiverDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

final class ReceiverDiscovery: ObservableObject {
    @Published private(set) var devices: [ReceiverDevice] = []
    @Published private(set) var isSearching = false
    @Published private(set) var lastError: String?

    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(
            for: .bonjour(type: AppConstants.receiverServiceType, domain: nil),
            using: .tcp
        )
        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready, .setup:
                    self?.isSearching = true
                    self?.lastError = nil
                case .failed(let error):
                    self?.isSearching = false
                    self?.lastError = error.localizedDescription
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let devices = results.compactMap { result -> ReceiverDevice? in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return ReceiverDevice(id: name, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async {
                self?.devices = devices
            }
        }
        self.browser = browser
        browser.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        devices = []
        isSearching = false
    }

    deinit {
        browser?.cancel()
    }
}
