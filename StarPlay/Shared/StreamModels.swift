import Foundation

struct StreamProfile: Codable, Equatable, Sendable {
    var maxDimension: Int
    var frameRate: Int
    var bitrate: Int
    var keyFrameInterval: Int

    static let availableDimensions = [960, 1280, 1920]
    static let availableFrameRates = [24, 30]

    var displayName: String {
        switch maxDimension {
        case 960: return "Balanced"
        case 1920: return "High detail"
        default: return "Standard"
        }
    }
}

enum StreamStatus: String, Codable, Sendable {
    case idle
    case starting
    case waitingForReceiver
    case connected
    case streaming
    case paused
    case stopping
    case failed

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .starting: return "Starting"
        case .waitingForReceiver: return "Waiting for receiver"
        case .connected: return "Receiver connected"
        case .streaming: return "Mirroring"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        case .failed: return "Needs attention"
        }
    }
}

enum StreamOrientation: String, Codable, Sendable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    case unknown

    var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait upside down"
        case .landscapeLeft: return "Landscape left"
        case .landscapeRight: return "Landscape right"
        case .unknown: return "Unknown"
        }
    }
}

struct StreamStateSnapshot: Codable, Sendable {
    var status: StreamStatus = .idle
    var message = "Ready to mirror"
    var sessionID = ""
    var receiverName = ""
    var receiverPort: UInt16 = 0
    var width = 0
    var height = 0
    var orientation: StreamOrientation = .unknown
    var framesSent: Int64 = 0
    var framesDropped: Int64 = 0
    var bytesSent: Int64 = 0
    var lastUpdated = Date.distantPast
    var audioSeen = false

    var isActive: Bool {
        switch status {
        case .starting, .waitingForReceiver, .connected, .streaming, .paused, .stopping:
            return true
        case .idle, .failed:
            return false
        }
    }
}

struct ReceiverHello: Codable, Sendable {
    var type: String
    var protocolVersion: Int
    var role: String
    var deviceName: String?
    var requestedVideoCodec: String?
    var pairingCode: String?

    static func make(deviceName: String?) -> ReceiverHello {
        ReceiverHello(
            type: "receiverHello",
            protocolVersion: AppConstants.protocolVersion,
            role: "windows-receiver",
            deviceName: deviceName,
            requestedVideoCodec: "h264",
            pairingCode: nil
        )
    }
}

struct StreamHello: Codable, Sendable {
    var type = "streamHello"
    var protocolVersion = AppConstants.protocolVersion
    var role = "iphone-starplay"
    var deviceName: String
    var sessionID: String
    var videoCodec = "h264"
    var videoFormat = "annex-b"
    var videoTransport = "tcp-length-prefixed"
    var orientationMetadata = "stream-header-and-change-events"
    var audioAvailable = false
    var audioTransport = "reserved"
}

struct VideoConfiguration: Codable, Sendable, Equatable {
    var type = "videoConfiguration"
    var codec = "h264"
    var format = "annex-b"
    var width: Int
    var height: Int
    var frameRate: Int
    var bitrate: Int
    var orientation: StreamOrientation
    var spsBase64: String
    var ppsBase64: String
}

struct OrientationChange: Codable, Sendable {
    var type = "orientationChanged"
    var orientation: StreamOrientation
    var width: Int
    var height: Int
}

struct ControlMessage: Codable, Sendable {
    var type: String
    var reason: String?
}
