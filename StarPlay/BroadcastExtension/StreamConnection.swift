import Foundation
import Network

final class StreamConnection {
    let connection: NWConnection
    let queue: DispatchQueue

    var onReady: ((String, UInt16) -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onFrameDropped: (() -> Void)?
    var onStopRequested: (() -> Void)?

    private let decoder = WireFrameDecoder()
    private var handshakeCompleted = false
    private var isSending = false
    private var pendingPacket: PendingPacket?
    private var hasReportedDisconnect = false

    private struct PendingPacket {
        let data: Data
        let isVideo: Bool
    }

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.receiveNext()
            case .waiting(let error):
                // A waiting connection may retain queued bytes for an unknown period.
                // Close it so the receiver can reconnect with a clean keyframe.
                self.reportDisconnected(error)
                self.connection.cancel()
            case .failed(let error):
                self.reportDisconnected(error)
            case .cancelled:
                self.reportDisconnected(nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func send(_ packet: Data, isVideo: Bool = false) {
        queue.async { [weak self] in
            guard let self, !self.hasReportedDisconnect, self.handshakeCompleted else { return }
            if self.isSending {
                if let pending = self.pendingPacket {
                    if pending.isVideo && !isVideo {
                        self.onFrameDropped?()
                        self.pendingPacket = PendingPacket(data: packet, isVideo: false)
                    } else if pending.isVideo && isVideo {
                        self.onFrameDropped?()
                        self.pendingPacket = PendingPacket(data: packet, isVideo: true)
                    } else if !pending.isVideo && isVideo {
                        self.onFrameDropped?()
                    } else {
                        self.pendingPacket = PendingPacket(data: packet, isVideo: false)
                    }
                } else {
                    self.pendingPacket = PendingPacket(data: packet, isVideo: isVideo)
                }
                return
            }
            self.isSending = true
            self.write(packet, isVideo: isVideo)
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.connection.cancel()
        }
    }

    private func write(_ packet: Data, isVideo: Bool) {
        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            self.queue.async {
                if error != nil {
                    self.reportDisconnected(error)
                    return
                }
                self.isSending = false
                guard let pending = self.pendingPacket else { return }
                self.pendingPacket = nil
                self.isSending = true
                self.write(pending.data, isVideo: pending.isVideo)
            }
        })
    }

    private func receiveNext() {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: AppConstants.maximumControlPacketSize
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.reportDisconnected(error)
                return
            }
            if let data, !data.isEmpty {
                do {
                    for packet in try self.decoder.append(data) {
                        try self.handle(packet: packet)
                    }
                } catch {
                    self.reportDisconnected(error)
                    return
                }
            }
            if isComplete {
                self.reportDisconnected(nil)
            } else {
                self.receiveNext()
            }
        }
    }

    private func handle(packet: Data) throws {
        let unpacked = try WirePacket.unpack(packet)
        switch unpacked.kind {
        case .controlJSON:
            let message = try JSONDecoder().decode(ControlMessage.self, from: unpacked.body)
            if !handshakeCompleted {
                guard message.type == "receiverHello" else { throw WireProtocolError.invalidPacket }
                let hello = try JSONDecoder().decode(ReceiverHello.self, from: unpacked.body)
                guard hello.role == "windows-receiver",
                      hello.protocolVersion >= AppConstants.minimumSupportedProtocolVersion,
                      hello.protocolVersion <= AppConstants.protocolVersion else {
                    throw WireProtocolError.invalidPacket
                }
                handshakeCompleted = true
                let remoteName = hello.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
                onReady?(remoteName?.isEmpty == false ? remoteName! : "Windows receiver", 0)
            } else if message.type == "stop" {
                onStopRequested?()
            } else if message.type == "ping" {
                send(WirePacket.simple(kind: .pong))
            }
        case .ping:
            send(WirePacket.simple(kind: .pong))
        case .pong, .videoConfiguration, .videoFrame, .goodbye:
            break
        }
    }

    private func reportDisconnected(_ error: Error?) {
        guard !hasReportedDisconnect else { return }
        hasReportedDisconnect = true
        onDisconnected?(error)
    }
}
