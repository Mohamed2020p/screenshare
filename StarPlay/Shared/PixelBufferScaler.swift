import CoreVideo
import Foundation
import VideoToolbox

/// Resizes ReplayKit's source buffer before encoding when the selected profile has a lower limit.
/// VTPixelTransferSession performs the color conversion and scaling without creating Core Image objects per frame.
final class PixelBufferScaler {
    private let transferSession: VTPixelTransferSession
    private let pool: CVPixelBufferPool
    private let width: Int
    private let height: Int

    init(width: Int, height: Int) throws {
        self.width = width
        self.height = height

        var session: VTPixelTransferSession?
        guard VTPixelTransferSessionCreate(allocator: kCFAllocatorDefault, pixelTransferSessionOut: &session) == noErr,
              let session else {
            throw NSError(domain: "com.c0derz.starplay.scaler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "The video scaler could not be created."
            ])
        }
        transferSession = session

        let attributes: CFDictionary = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary
        var createdPool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes, &createdPool) == kCVReturnSuccess,
              let createdPool else {
            throw NSError(domain: "com.c0derz.starplay.scaler", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "The video buffer pool could not be created."
            ])
        }
        pool = createdPool
    }

    func scale(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        var destination: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &destination) == kCVReturnSuccess,
              let destination else { return nil }
        guard VTPixelTransferSessionTransferImage(transferSession, from: source, to: destination) == noErr else {
            return nil
        }
        return destination
    }

    var outputSize: (width: Int, height: Int) { (width, height) }
}

struct StreamGeometry {
    static func targetSize(sourceWidth: Int, sourceHeight: Int, maxDimension: Int) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0, maxDimension > 0 else {
            return (sourceWidth, sourceHeight)
        }
        let sourceMax = max(sourceWidth, sourceHeight)
        guard sourceMax > maxDimension else {
            return (max(2, sourceWidth - sourceWidth % 2), max(2, sourceHeight - sourceHeight % 2))
        }

        let scale = Double(maxDimension) / Double(sourceMax)
        var width = max(2, Int((Double(sourceWidth) * scale).rounded()))
        var height = max(2, Int((Double(sourceHeight) * scale).rounded()))
        width -= width % 2
        height -= height % 2
        return (max(2, width), max(2, height))
    }
}
