import Foundation

/// Small, deliberately bounded IPC surface between the host app and the broadcast extension.
/// The extension writes status while the host app polls it because the two processes do not share memory.
enum SharedStateStore {
    private static let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    private static let stateKey = "stream.state"
    private static let profileKey = "stream.profile"
    private static let stopRequestKey = "stream.stopRequest"
    private static let metricsLock = NSLock()
    private static var pendingFrameCount: Int64 = 0
    private static var pendingFrameBytes: Int64 = 0

    static func readProfile() -> StreamProfile {
        guard let data = defaults.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(StreamProfile.self, from: data) else {
            return AppConstants.defaultProfile
        }
        return profile
    }

    static func writeProfile(_ profile: StreamProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: profileKey)
        }
    }

    static func snapshot() -> StreamStateSnapshot {
        guard let data = defaults.data(forKey: stateKey),
              let snapshot = try? JSONDecoder().decode(StreamStateSnapshot.self, from: data) else {
            return StreamStateSnapshot()
        }
        return snapshot
    }

    static func resetForNewSession(_ sessionID: String) {
        metricsLock.lock()
        pendingFrameCount = 0
        pendingFrameBytes = 0
        metricsLock.unlock()

        var state = StreamStateSnapshot()
        state.status = .starting
        state.message = "Preparing the system broadcast"
        state.sessionID = sessionID
        state.lastUpdated = Date()
        write(state)
        defaults.removeObject(forKey: stopRequestKey)
    }

    static func update(status: StreamStatus, message: String) {
        var state = snapshot()
        state.status = status
        state.message = message
        state.lastUpdated = Date()
        write(state)
    }

    static func updateReceiver(name: String, port: UInt16) {
        var state = snapshot()
        state.receiverName = name
        state.receiverPort = port
        state.status = .connected
        state.message = "Receiver connected"
        state.lastUpdated = Date()
        write(state)
    }

    static func clearReceiver() {
        var state = snapshot()
        state.receiverName = ""
        state.receiverPort = 0
        state.lastUpdated = Date()
        write(state)
    }

    static func updateVideoFormat(width: Int, height: Int, orientation: StreamOrientation) {
        var state = snapshot()
        state.width = width
        state.height = height
        state.orientation = orientation
        state.lastUpdated = Date()
        write(state)
    }

    static func markStreaming() {
        var state = snapshot()
        guard state.status != .streaming else { return }
        state.status = .streaming
        state.message = "Sending the iPhone screen"
        state.lastUpdated = Date()
        write(state)
    }

    static func markFrameSent(bytes: Int) {
        metricsLock.lock()
        pendingFrameCount += 1
        pendingFrameBytes += Int64(bytes)
        let shouldPersist = pendingFrameCount >= 15
        let frames = pendingFrameCount
        let byteCount = pendingFrameBytes
        if shouldPersist {
            pendingFrameCount = 0
            pendingFrameBytes = 0
        }
        metricsLock.unlock()

        guard shouldPersist else { return }
        var state = snapshot()
        state.framesSent += frames
        state.bytesSent += byteCount
        state.lastUpdated = Date()
        write(state)
    }

    static func flushMetrics() {
        metricsLock.lock()
        let frames = pendingFrameCount
        let byteCount = pendingFrameBytes
        pendingFrameCount = 0
        pendingFrameBytes = 0
        metricsLock.unlock()

        guard frames > 0 else { return }
        var state = snapshot()
        state.framesSent += frames
        state.bytesSent += byteCount
        state.lastUpdated = Date()
        write(state)
    }

    static func markFrameDropped() {
        var state = snapshot()
        state.framesDropped += 1
        state.lastUpdated = Date()
        write(state)
    }

    static func markAudioSeen() {
        var state = snapshot()
        guard !state.audioSeen else { return }
        state.audioSeen = true
        state.lastUpdated = Date()
        write(state)
    }

    static func requestStop() {
        defaults.set(Date().timeIntervalSince1970, forKey: stopRequestKey)
    }

    static func stopWasRequested(after date: Date) -> Bool {
        defaults.double(forKey: stopRequestKey) > date.timeIntervalSince1970
    }

    static func write(_ state: StreamStateSnapshot) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }
}

/// Darwin notifications are one-way and process-wide. They are used only while the
/// broadcast extension is alive, with the shared store remaining the source of truth.
enum BroadcastControlChannel {
    static let stopNotification = "com.c0derz.starplay.stop"

    static func postStop() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: stopNotification as CFString),
            nil,
            nil,
            true
        )
    }
}
