import Foundation

/// Wire framing used between the Broadcast Upload Extension and the future Windows receiver.
/// Every packet is: uint32 big-endian payload length, uint8 packet kind, payload bytes.
enum WirePacketKind: UInt8 {
    case controlJSON = 0x01
    case videoConfiguration = 0x02
    case videoFrame = 0x03
    case ping = 0x04
    case pong = 0x05
    case goodbye = 0x06
}

enum WireProtocolError: Error {
    case invalidLength
    case invalidPacket
    case invalidJSON
}

struct WirePacket {
    static func control<T: Encodable>(_ value: T) throws -> Data {
        let json = try JSONEncoder().encode(value)
        return frame(kind: .controlJSON, body: json)
    }

    static func videoConfiguration(_ configuration: VideoConfiguration) throws -> Data {
        let json = try JSONEncoder().encode(configuration)
        return frame(kind: .videoConfiguration, body: json)
    }

    static func orientationChange(_ change: OrientationChange) throws -> Data {
        let json = try JSONEncoder().encode(change)
        return frame(kind: .controlJSON, body: json)
    }

    static func videoFrame(_ encodedFrame: EncodedVideoFrame) -> Data {
        var body = Data()
        body.appendBigEndian(encodedFrame.presentationTimeMicroseconds)
        body.append(encodedFrame.isKeyFrame ? 0x01 : 0x00)
        body.appendBigEndian(UInt32(encodedFrame.width))
        body.appendBigEndian(UInt32(encodedFrame.height))
        body.append(encodedFrame.annexBData)
        return Self.frame(kind: .videoFrame, body: body)
    }

    static func simple(kind: WirePacketKind) -> Data {
        frame(kind: kind, body: Data())
    }

    static func unpack(_ packet: Data) throws -> (kind: WirePacketKind, body: Data) {
        guard let rawKind = packet.first, let kind = WirePacketKind(rawValue: rawKind) else {
            throw WireProtocolError.invalidPacket
        }
        return (kind, Data(packet.dropFirst()))
    }

    private static func frame(kind: WirePacketKind, body: Data) -> Data {
        var payload = Data([kind.rawValue])
        payload.append(body)
        var packet = Data()
        packet.appendBigEndian(UInt32(payload.count))
        packet.append(payload)
        return packet
    }
}

final class WireFrameDecoder {
    private var buffer = Data()

    func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var packets: [Data] = []

        while buffer.count >= 4 {
            let length = buffer.readUInt32(at: 0)
            guard length > 0, length <= UInt32(AppConstants.maximumVideoPacketSize) else {
                throw WireProtocolError.invalidLength
            }
            let packetLength = 4 + Int(length)
            guard buffer.count >= packetLength else { break }
            packets.append(Data(buffer[4..<packetLength]))
            buffer.removeSubrange(0..<packetLength)
        }
        return packets
    }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset]) << 24
            | UInt32(self[offset + 1]) << 16
            | UInt32(self[offset + 2]) << 8
            | UInt32(self[offset + 3])
    }
}
