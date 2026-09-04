import Foundation

/// Identifiers shared by the application and its Broadcast Upload Extension.
/// The application group must be enabled for both targets in the Apple Developer portal.
enum AppConstants {
    static let appName = "StarPlay"
    static let developerName = "c0derz"
    static let appBundleIdentifier = "com.c0derz.starplay"
    static let broadcastExtensionBundleIdentifier = "com.c0derz.starplay.broadcast"
    static let appGroupIdentifier = "group.com.c0derz.starplay"

    static let protocolVersion = 1
    static let serviceType = "_starplay._tcp"
    static let receiverServiceType = "_starplay-receiver._tcp"

    static let defaultProfile = StreamProfile(
        maxDimension: 1280,
        frameRate: 30,
        bitrate: 4_500_000,
        keyFrameInterval: 60
    )

    static let minimumSupportedProtocolVersion = 1
    static let maximumControlPacketSize = 64 * 1024
    static let maximumVideoPacketSize = 4 * 1024 * 1024
    static let stateExpirationInterval: TimeInterval = 15
}
