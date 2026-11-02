import Foundation
import Darwin
import AVFoundation
import CoreImage

// Runs on macOS in CI. Does not establish iOS device/ESign compatibility.
@main
struct MediaSmokeTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "NovaEditor.Tests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func fixture(at url: URL, rotated: Bool) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320, AVVideoHeightKey: 180
        ])
        if rotated { input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0) }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180
        ])
        writer.add(input)
        try check(writer.startWriting(), "Fixture start failed")
        writer.startSession(atSourceTime: .zero)
        let ci = CIContext()
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error ?? MediaError.exportFailed }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var pixel: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel)
            try check(result == kCVReturnSuccess && pixel != nil, "Fixture pixel allocation failed")
            let image = CIImage(color: CIColor(red: 0.8, green: 0.2, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 180))
            ci.render(image, to: pixel!)
            try check(adaptor.append(pixel!, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)), "Fixture append failed")
        }
        input.markAsFinished()
        await writer.finishWriting()
        try check(writer.status == .completed, "Fixture finalization failed")
    }

    static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static func main() async {
        do { try await run() }
        catch {
            log("FAIL: \(String(reflecting: error))")
            exit(EXIT_FAILURE)
        }
    }

    static func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let clip = TimelineClip(fileName: "source.mov", title: "Test", sourceDuration: 2, start: 0.2, end: 1.8)
        let (left, right) = try clip.split(at: 0.6)
        try check(abs(left.duration - 0.6) < 0.001 && abs(right.start - 0.8) < 0.001, "Split must retain source offset")
        try check(left.id != right.id && left.fileName == right.fileName, "Split identity/source incorrect")
        try check(abs([right, left].totalDuration - 1.6) < 0.001, "Split changed total duration")
        try check(abs([right, left].offset(of: left.id) - right.duration) < 0.001, "Reorder offset incorrect")
        do { _ = try clip.split(at: 0.01); throw MediaError.exportFailed }
        catch TimelineError.invalidSplit {} // Other errors propagate.
        var invalid = clip
        invalid.end = .nan
        do { _ = try invalid.validated(); throw MediaError.exportFailed }
        catch TimelineError.invalidRange {}
        let decoded = try JSONDecoder().decode([TimelineClip].self, from: JSONEncoder().encode([right, left]))
        try check(decoded == [right, left], "Project round trip failed")
        print("PASS: timeline ranges, splits, reorder and persistence")

        for rotated in [false, true] {
            let source = root.appendingPathComponent("source.mov")
            try? FileManager.default.removeItem(at: source)
            log("STAGE: create fixture, rotated=\(rotated)")
            try await fixture(at: source, rotated: rotated)
            var first = left
            first.effect = .monochrome
            var second = right
            second.effect = .sepia
            log("STAGE: compose fixture, rotated=\(rotated)")
            let edit = try await MediaEngine.build([first, second], directory: root)
            let expectedSize = rotated ? CGSize(width: 720, height: 1280) : CGSize(width: 1280, height: 720)
            try check(edit.video.renderSize == expectedSize, "Orientation canvas incorrect")
            let output = root.appendingPathComponent("out-\(rotated).mp4")
            log("STAGE: export fixture, rotated=\(rotated)")
            try await MediaEngine.export(edit, to: output)
            log("STAGE: decode export, rotated=\(rotated)")
            let exported = AVURLAsset(url: output)
            let duration = try await exported.load(.duration).seconds
            try check(abs(duration - 1.6) < 0.08, "Export duration changed")
            let tracks = try await exported.loadTracks(withMediaType: .video)
            try check(tracks.count == 1, "Missing exported video")
            let reader = try AVAssetReader(asset: exported)
            let frames = AVAssetReaderTrackOutput(track: tracks[0], outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            reader.add(frames)
            try check(reader.startReading(), "Export cannot be decoded")
            guard let sample = frames.copyNextSampleBuffer(), let pixels = CMSampleBufferGetImageBuffer(sample) else { throw MediaError.noVideo }
            CVPixelBufferLockBaseAddress(pixels, .readOnly)
            let width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels)
            let stride = CVPixelBufferGetBytesPerRow(pixels)
            let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
            let offset = (height / 2) * stride + (width / 2) * 4
            let b = Int(base[offset]), g = Int(base[offset + 1]), r = Int(base[offset + 2])
            CVPixelBufferUnlockBaseAddress(pixels, .readOnly)
            reader.cancelReading()
            try check(width == Int(expectedSize.width) && height == Int(expectedSize.height), "Export dimensions changed")
            try check(r > 20 && abs(r - g) < 12 && abs(g - b) < 12, "Monochrome render incorrect or frame black")
            print("PASS: \(rotated ? "portrait" : "landscape") fixture, trimmed/effected MP4, duration, dimensions and decoded monochrome frame")
        }
    }
}
