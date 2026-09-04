#if canImport(ScreenCaptureKit)
import CoreMedia
import Foundation
import ScreenCaptureKit

@available(iOS 27.0, *)
final class ModernScreenCaptureController: NSObject, SCContentSharingPickerObserver, SCStreamOutput, SCStreamDelegate {
    private let picker = SCContentSharingPicker.shared
    private let captureQueue = DispatchQueue(label: "com.c0derz.starplay.screen-capture", qos: .userInitiated)
    private let session: VideoStreamSession
    private var stream: SCStream?
    private var isStopping = false

    init(deviceName: String) {
        session = VideoStreamSession(deviceName: deviceName)
        super.init()
        session.onFatalError = { [weak self] error in
            self?.stop {
                SharedStateStore.update(status: .failed, message: error.localizedDescription)
            }
        }
        session.onStopRequested = { [weak self] in
            self?.stop()
        }
    }

    func presentPicker() {
        guard stream == nil else { return }
        isStopping = false
        session.start()

        var configuration = SCContentSharingPickerConfiguration()
        // On iOS, present() is the full-display entry point. The optional microphone
        // control stays hidden because version 1 publishes video only.
        configuration.showsMicrophoneControl = false
        configuration.showsCameraControl = false
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.present()
    }

    func stop() {
        stop(completion: nil)
    }

    private func stop(completion: (@escaping () -> Void)?) {
        isStopping = true
        picker.remove(self)
        guard let stream else {
            session.stop()
            completion?()
            return
        }
        self.stream = nil
        stream.stopCapture { [weak self] _ in
            self?.session.stop()
            completion?()
        }
    }

    func contentSharingPicker(
        _ picker: SCContentSharingPicker,
        didUpdateWith filter: SCContentFilter,
        for stream: SCStream?
    ) {
        // The iOS entry point starts a new full-display selection. The macOS-only
        // updateContentFilter API is intentionally not used here.
        guard self.stream == nil else { return }

        let configuration = makeStreamConfiguration(for: filter)
        do {
            let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            self.stream = newStream
            newStream.startCapture { [weak self] error in
                guard let self else { return }
                if let error {
                    self.stop {
                        SharedStateStore.update(status: .failed, message: error.localizedDescription)
                    }
                }
            }
        } catch {
            picker.remove(self)
            session.stop()
            SharedStateStore.update(status: .failed, message: error.localizedDescription)
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        guard self.stream == nil else { return }
        picker.remove(self)
        session.stop()
        SharedStateStore.update(status: .idle, message: "Ready to mirror")
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        picker.remove(self)
        session.stop()
        SharedStateStore.update(status: .failed, message: error.localizedDescription)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        switch outputType {
        case .screen:
            guard Self.isUsableVideoFrame(sampleBuffer) else { return }
            session.processVideo(sampleBuffer)
        case .audio:
            session.processAudio(sampleBuffer)
        @unknown default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
        session.stop()
        if !isStopping {
            SharedStateStore.update(status: .failed, message: error.localizedDescription)
        }
    }

    func streamDidBecomeActive(_ stream: SCStream) {
        session.resume()
    }

    func streamDidBecomeInactive(_ stream: SCStream) {
        session.pause()
    }

    private static func isUsableVideoFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachmentArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachmentArray.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else {
            return true
        }
        return status == .complete || status == .started
    }

    private func makeStreamConfiguration(for filter: SCContentFilter) -> SCStreamConfiguration {
        let profile = SharedStateStore.readProfile()
        let sourceWidth = max(2, Int((filter.contentRect.width * CGFloat(filter.pointPixelScale)).rounded()))
        let sourceHeight = max(2, Int((filter.contentRect.height * CGFloat(filter.pointPixelScale)).rounded()))
        let target = StreamGeometry.targetSize(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            maxDimension: profile.maxDimension
        )

        let configuration = SCStreamConfiguration()
        // iOS 27 exposes width and height for screen output. The additional
        // pixel-format, cursor, queue, and frame-interval knobs are macOS-only;
        // VideoStreamSession normalizes the iOS buffer before encoding.
        configuration.width = target.width
        configuration.height = target.height
        configuration.capturesAudio = false
        return configuration
    }
}
#endif
