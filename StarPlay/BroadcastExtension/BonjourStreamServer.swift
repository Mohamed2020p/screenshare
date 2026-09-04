import Foundation
import Network

final class BonjourStreamServer {
    private let deviceName: String
    private let queue = DispatchQueue(label: "com.c0derz.starplay.bonjour-server", qos: .userInitiated)
    private var listener: NWListener?
    private var activeConnection: StreamConnection?
    private var receiverReady = false
    private let stateLock = NSLock()
    private var isStopped = false

    var onWaiting: ((UInt16) -> Void)?
    var onReceiverConnected: ((String, UInt16) -> Void)?
    var onReceiverDisconnected: ((Error?) -> Void)?
    var onFrameDropped: (() -> Void)?
    var onStopRequested: (() -> Void)?
    var onFailure: ((Error) -> Void)?

    init(deviceName: String) {
        self.deviceName = deviceName
    }

    var hasReceiver: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return receiverReady
    }

    func start() {
        queue.async { [weak self] in
            self?.startListener()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isStopped = true
            self.activeConnection?.cancel()
            self.activeConnection = nil
            self.stateLock.lock()
            self.receiverReady = false
            self.stateLock.unlock()
            self.listener?.cancel()
            self.listener = nil
        }
    }

    func send(_ packet: Data, isVideo: Bool = false) {
        queue.async { [weak self] in
            self?.activeConnection?.send(packet, isVideo: isVideo)
        }
    }

    private func startListener() {
        guard !isStopped else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters)
            var txtRecord = NWTXTRecord([
                "role": "iphone",
                "protocol": String(AppConstants.protocolVersion),
                "video": "h264",
                "format": "annex-b",
                "audio": "reserved"
            ])
            txtRecord["device"] = deviceName
            listener.service = NWListener.Service(
                name: deviceName,
                type: AppConstants.serviceType,
                domain: nil,
                txtRecord: txtRecord
            )
            listener.stateUpdateHandler = { [weak self] state in
                guard let self, !self.isStopped else { return }
                switch state {
                case .ready:
                    self.onWaiting?(listener.port?.rawValue ?? 0)
                case .failed(let error):
                    self.onFailure?(error)
                case .cancelled:
                    break
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            onFailure?(error)
        }
    }

    private func accept(_ connection: NWConnection) {
        guard !isStopped else {
            connection.cancel()
            return
        }
        if activeConnection != nil {
            connection.cancel()
            return
        }

        let streamConnection = StreamConnection(connection: connection, queue: queue)
        streamConnection.onReady = { [weak self, weak streamConnection] name, _ in
            guard let self, let streamConnection, self.activeConnection === streamConnection else { return }
            self.stateLock.lock()
            self.receiverReady = true
            self.stateLock.unlock()
            let port = self.listener?.port?.rawValue ?? 0
            self.onReceiverConnected?(name, port)
        }
        streamConnection.onDisconnected = { [weak self, weak streamConnection] error in
            guard let self, let streamConnection, self.activeConnection === streamConnection else { return }
            self.activeConnection = nil
            self.stateLock.lock()
            self.receiverReady = false
            self.stateLock.unlock()
            self.onReceiverDisconnected?(error)
        }
        streamConnection.onFrameDropped = { [weak self] in
            self?.onFrameDropped?()
        }
        streamConnection.onStopRequested = { [weak self] in
            self?.onStopRequested?()
        }
        activeConnection = streamConnection
        streamConnection.start()
    }
}
