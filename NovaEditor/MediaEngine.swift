import AVFoundation

struct EditComposition {
    let asset: AVMutableComposition
    let video: AVMutableVideoComposition
}

enum MediaError: LocalizedError {
    case noVideo, exportUnavailable, exportFailed, invalidGeometry
    var errorDescription: String? {
        switch self {
        case .noVideo: return "O arquivo não tem uma faixa de vídeo legível."
        case .exportUnavailable: return "Este dispositivo não disponibilizou exportação MP4 para o projeto."
        case .exportFailed: return "A exportação não foi concluída."
        case .invalidGeometry: return "Dimensões de vídeo inválidas."
        }
    }
}

enum MediaEngine {
    static func build(_ clips: [TimelineClip], directory: URL) async throws -> EditComposition {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid) else { throw MediaError.noVideo }
        let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid)
        var instructions: [ClipInstruction] = []
        var cursor = CMTime.zero
        var canvas = CGSize(width: 1280, height: 720)
        for (index, candidate) in clips.enumerated() {
            let clip = try candidate.validated()
            let asset = AVURLAsset(url: directory.appendingPathComponent(clip.fileName))
            guard let source = try await asset.loadTracks(withMediaType: .video).first else { throw MediaError.noVideo }
            let naturalSize = try await source.load(.naturalSize)
            let preferred = try await source.load(.preferredTransform)
            let oriented = CGRect(origin: .zero, size: naturalSize).applying(preferred).standardized
            guard oriented.width.isFinite, oriented.height.isFinite,
                  oriented.width > 0, oriented.height > 0 else { throw MediaError.invalidGeometry }
            if index == 0, oriented.height > oriented.width { canvas = CGSize(width: 720, height: 1280) }
            let range = CMTimeRange(start: CMTime(seconds: clip.start, preferredTimescale: 600),
                                    duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
            try videoTrack.insertTimeRange(range, of: source, at: cursor)
            if let audio = try await asset.loadTracks(withMediaType: .audio).first, let target = audioTrack {
                // The audio track can start late or finish before the video. Preserve its relative offset.
                let audioRange = try await audio.load(.timeRange)
                let intersection = CMTimeRangeGetIntersection(range, otherRange: audioRange)
                if intersection.isValid, intersection.duration > .zero {
                    let audioCursor = cursor + intersection.start - range.start
                    try target.insertTimeRange(intersection, of: audio, at: audioCursor)
                }
            }
            let scale = min(canvas.width / oriented.width, canvas.height / oriented.height)
            let normalized = preferred.concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
            let transform = normalized.concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: (canvas.width - oriented.width * scale) / 2,
                                                y: (canvas.height - oriented.height * scale) / 2))
            instructions.append(ClipInstruction(range: CMTimeRange(start: cursor, duration: range.duration),
                trackID: videoTrack.trackID, transform: transform, effect: clip.effect))
            cursor = cursor + range.duration
        }
        let video = AVMutableVideoComposition()
        video.customVideoCompositorClass = VideoCompositor.self
        video.renderSize = canvas
        video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = instructions
        return EditComposition(asset: composition, video: video)
    }

    static func export(_ edit: EditComposition, to url: URL) async throws {
        guard let session = AVAssetExportSession(asset: edit.asset, presetName: AVAssetExportPresetHighestQuality),
              session.supportedFileTypes.contains(.mp4) else { throw MediaError.exportUnavailable }
        session.outputURL = url
        session.outputFileType = .mp4
        session.videoComposition = edit.video
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else { throw session.error ?? MediaError.exportFailed }
    }
}
