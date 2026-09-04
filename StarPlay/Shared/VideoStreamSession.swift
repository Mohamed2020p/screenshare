import CoreMedia
import CoreVideo
import Foundation

/// Capture-source independent video sender. ReplayKit and ScreenCaptureKit both hand
/// CMSampleBuffer values to this type, so the network and encoding pipeline stays identical.
final class VideoStreamSession {
    var onStopRequested: (() -> Void)?
    var onFatalError: ((Error) -> Void)?

    private let sessionID = UUID().uuidString
    private let deviceName: String
    private var server: BonjourStreamServer?
    private var encoder: H264VideoEncoder?
    private var scaler: PixelBufferScaler?
    private var profile = AppConstants.defaultProfile
    private var lastSourceSize: (width: Int, height: Int)?
    private var outputSize: (width: Int, height: Int)?
    private var currentOrientation: StreamOrientation = .unknown
    private var latestConfiguration: VideoConfiguration?
    private var lastSubmittedSeconds: Double?
    private var isPaused = false
    private var isRunning = false

    init(deviceName: String) {
        self.deviceName = deviceName.isEmpty ? "iPhone" : deviceName
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        profile = SharedStateStore.readProfile()
        SharedStateStore.resetForNewSession(sessionID)

        let server = BonjourStreamServer(deviceName: deviceName)
        server.onWaiting = { port in
            SharedStateStore.clearReceiver()
            var state = SharedStateStore.snapshot()
            state.receiverPort = port
            state.status = .waitingForReceiver
            state.message = "Visible to Windows receivers"
            SharedStateStore.write(state)
        }
        server.onReceiverConnected = { [weak self] name, port in
            guard let self else { return }
            self.invalidateEncoder()
            SharedStateStore.updateReceiver(name: name, port: port)
            self.sendStreamHello()
        }
        server.onReceiverDisconnected = { [weak self] error in
            guard let self else { return }
            self.invalidateEncoder()
            SharedStateStore.clearReceiver()
            let detail = error.map { ": \($0.localizedDescription)" } ?? ""
            SharedStateStore.update(status: .waitingForReceiver, message: "Receiver disconnected\(detail)")
        }
        server.onFrameDropped = { [weak self] in
            self?.encoder?.requestKeyFrame()
            SharedStateStore.markFrameDropped()
        }
        server.onStopRequested = { [weak self] in
            self?.onStopRequested?()
        }
        server.onFailure = { [weak self] error in
            SharedStateStore.update(status: .failed, message: error.localizedDescription)
            self?.onFatalError?(error)
        }
        self.server = server
        server.start()
    }

    func pause() {
        isPaused = true
        SharedStateStore.update(status: .paused, message: "Broadcast paused by the system")
    }

    func resume() {
        isPaused = false
        if server?.hasReceiver == true {
            SharedStateStore.markStreaming()
        } else {
            SharedStateStore.update(status: .waitingForReceiver, message: "Visible to Windows receivers")
        }
    }

    func stop() {
        guard isRunning || server != nil else { return }
        isRunning = false
        invalidateEncoder()
        SharedStateStore.flushMetrics()
        server?.stop()
        server = nil
        if SharedStateStore.snapshot().status != .failed {
            SharedStateStore.update(status: .idle, message: "Ready to mirror")
        }
    }

    func processVideo(_ sampleBuffer: CMSampleBuffer, orientationHint: StreamOrientation? = nil) {
        guard isRunning, !isPaused,
              sampleBuffer.isValid,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              server?.hasReceiver == true else { return }

        let sourceWidth = CVPixelBufferGetWidth(imageBuffer)
        let sourceHeight = CVPixelBufferGetHeight(imageBuffer)
        guard sourceWidth > 0, sourceHeight > 0 else { return }

        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let seconds = CMTimeGetSeconds(presentationTimeStamp)
        guard seconds.isFinite else { return }
        if let lastSubmittedSeconds,
           seconds - lastSubmittedSeconds < (1.0 / Double(max(1, profile.frameRate))) {
            return
        }
        lastSubmittedSeconds = seconds

        let orientation = orientationHint ?? Self.orientation(from: sampleBuffer)
        let target = StreamGeometry.targetSize(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            maxDimension: profile.maxDimension
        )

        if lastSourceSize?.width != sourceWidth || lastSourceSize?.height != sourceHeight || outputSize?.width != target.width || outputSize?.height != target.height {
            rebuildEncoder(sourceWidth: sourceWidth, sourceHeight: sourceHeight, outputSize: target, orientation: orientation)
        } else if currentOrientation != orientation {
            currentOrientation = orientation
            SharedStateStore.updateVideoFormat(width: target.width, height: target.height, orientation: orientation)
            sendOrientationChange(width: target.width, height: target.height, orientation: orientation)
        }

        guard let encoder, let scaler, let bufferToEncode = scaler.scale(imageBuffer) else { return }
        encoder.encode(pixelBuffer: bufferToEncode, presentationTimeStamp: presentationTimeStamp)
    }

    func processAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning, sampleBuffer.isValid else { return }
        SharedStateStore.markAudioSeen()
    }

    private func rebuildEncoder(sourceWidth: Int, sourceHeight: Int, outputSize: (width: Int, height: Int), orientation: StreamOrientation) {
        invalidateEncoder()
        lastSourceSize = (sourceWidth, sourceHeight)
        self.outputSize = outputSize
        currentOrientation = orientation

        do {
            // ReplayKit and ScreenCaptureKit can produce different source pixel formats.
            // The transfer session normalizes both to an encoder-friendly NV12 buffer.
            scaler = try PixelBufferScaler(width: outputSize.width, height: outputSize.height)
            encoder = try H264VideoEncoder(
                width: outputSize.width,
                height: outputSize.height,
                profile: profile,
                onConfiguration: { [weak self] parameterSets in
                    guard let self else { return }
                    let configuration = VideoConfiguration(
                        width: outputSize.width,
                        height: outputSize.height,
                        frameRate: self.profile.frameRate,
                        bitrate: self.profile.bitrate,
                        orientation: self.currentOrientation,
                        spsBase64: parameterSets.sps.base64EncodedString(),
                        ppsBase64: parameterSets.pps.base64EncodedString()
                    )
                    self.latestConfiguration = configuration
                    SharedStateStore.updateVideoFormat(width: outputSize.width, height: outputSize.height, orientation: self.currentOrientation)
                    self.sendVideoConfiguration(configuration)
                },
                onFrame: { [weak self] frame in
                    guard let self, let server = self.server, server.hasReceiver else { return }
                    server.send(WirePacket.videoFrame(frame), isVideo: true)
                    SharedStateStore.markFrameSent(bytes: frame.annexBData.count)
                    SharedStateStore.markStreaming()
                }
            )
            SharedStateStore.updateVideoFormat(width: outputSize.width, height: outputSize.height, orientation: orientation)
            sendOrientationChange(width: outputSize.width, height: outputSize.height, orientation: orientation)
        } catch {
            SharedStateStore.update(status: .failed, message: error.localizedDescription)
            onFatalError?(error)
        }
    }

    private func invalidateEncoder() {
        encoder?.invalidate()
        encoder = nil
        scaler = nil
        lastSourceSize = nil
        outputSize = nil
        latestConfiguration = nil
        lastSubmittedSeconds = nil
    }

    private func sendStreamHello() {
        let hello = StreamHello(deviceName: deviceName, sessionID: sessionID)
        guard let packet = try? WirePacket.control(hello) else { return }
        server?.send(packet)
        if let latestConfiguration {
            sendVideoConfiguration(latestConfiguration)
        }
    }

    private func sendVideoConfiguration(_ configuration: VideoConfiguration) {
        guard let packet = try? WirePacket.videoConfiguration(configuration) else { return }
        server?.send(packet)
    }

    private func sendOrientationChange(width: Int, height: Int, orientation: StreamOrientation) {
        let change = OrientationChange(orientation: orientation, width: width, height: height)
        guard let packet = try? WirePacket.orientationChange(change) else { return }
        server?.send(packet)
    }

    private static func orientation(from sampleBuffer: CMSampleBuffer) -> StreamOrientation {
        // The ReplayKit compatibility path publishes this public attachment key. The
        // ScreenCaptureKit path generally changes output dimensions, so the geometry
        // fallback below still keeps the receiver's display orientation correct.
        if let value = CMGetAttachment(
            sampleBuffer,
            key: "RPSampleBufferVideoOrientation" as CFString,
            attachmentModeOut: nil
        ) as? NSNumber {
            switch value.uint32Value {
            case 1, 2: return .portrait
            case 3, 4: return .portraitUpsideDown
            case 5, 8: return .landscapeLeft
            case 6, 7: return .landscapeRight
            default: break
            }
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return .unknown }
        return CVPixelBufferGetWidth(imageBuffer) >= CVPixelBufferGetHeight(imageBuffer)
            ? .landscapeRight
            : .portrait
    }
}
