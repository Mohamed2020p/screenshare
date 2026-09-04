import Foundation
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let session = BroadcastSession()

    override init() {
        super.init()
        session.onHostStopRequested = { [weak self] in
            guard let self else { return }
            let error = NSError(
                domain: "com.c0derz.starplay.broadcast",
                code: 1,
                userInfo: [NSLocalizedFailureReasonErrorKey: "StarPlay mirroring was stopped by the user."]
            )
            self.finishBroadcastWithError(error)
        }
        session.onFatalError = { [weak self] error in
            self?.finishBroadcastWithError(error)
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        session.start()
    }

    override func broadcastPaused() {
        session.pause()
    }

    override func broadcastResumed() {
        session.resume()
    }

    override func broadcastFinished() {
        session.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            session.processVideo(sampleBuffer)
        case .audioApp, .audioMic:
            session.processAudio(sampleBuffer)
        @unknown default:
            break
        }
    }
}
