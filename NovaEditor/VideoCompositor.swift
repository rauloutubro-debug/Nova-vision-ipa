import AVFoundation
import CoreImage
import Metal

// Each instruction owns one segment; the same instruction graph feeds preview and export.
final class ClipInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = false
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let trackID: CMPersistentTrackID
    let transform: CGAffineTransform
    let effect: VideoEffect

    init(range: CMTimeRange, trackID: CMPersistentTrackID,
         transform: CGAffineTransform, effect: VideoEffect) {
        self.timeRange = range
        self.trackID = trackID
        self.requiredSourceTrackIDs = [NSNumber(value: trackID)]
        self.transform = transform
        self.effect = effect
    }
}

final class VideoCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
         kCVPixelBufferMetalCompatibilityKey as String: true]
    }
    private let queue = DispatchQueue(label: "NovaEditor.compositor")
    private let lock = NSLock()
    private var generation = 0
    private let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: device) }
        return CIContext(options: nil)
    }()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func cancelAllPendingVideoCompositionRequests() {
        lock.lock()
        generation += 1
        lock.unlock()
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock()
        let ticket = generation
        lock.unlock()
        queue.async { [self] in
            autoreleasepool {
                lock.lock()
                let cancelled = ticket != generation
                lock.unlock()
                guard !cancelled else { request.finishCancelledRequest(); return }
                guard let instruction = request.videoCompositionInstruction as? ClipInstruction,
                      let source = request.sourceFrame(byTrackID: instruction.trackID),
                      let output = request.renderContext.newPixelBuffer() else {
                    request.finish(with: NSError(domain: "NovaEditor.Render", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Não foi possível renderizar o quadro."]))
                    return
                }
                let bounds = CGRect(origin: .zero, size: request.renderContext.size)
                var frame = CIImage(cvPixelBuffer: source).transformed(by: instruction.transform)
                switch instruction.effect {
                case .original: break
                case .monochrome: frame = frame.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                case .sepia: frame = frame.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.85])
                case .invert: frame = frame.applyingFilter("CIColorInvert")
                }
                let image = frame.composited(over: CIImage(color: .black).cropped(to: bounds)).cropped(to: bounds)
                context.render(image, to: output, bounds: bounds, colorSpace: colorSpace)
                request.finish(withComposedVideoFrame: output)
            }
        }
    }
}
