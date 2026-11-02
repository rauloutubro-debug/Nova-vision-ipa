import Foundation

enum VideoEffect: String, Codable, CaseIterable, Identifiable {
    case original, monochrome, sepia, invert
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .monochrome: return "Preto e branco"
        case .sepia: return "Sépia"
        case .invert: return "Negativo"
        }
    }
}

struct TimelineClip: Identifiable, Codable, Equatable {
    var id = UUID()
    let fileName: String
    let title: String
    let sourceDuration: Double
    var sourceStart: Double = 0
    var start: Double
    var end: Double
    var effect: VideoEffect = .original
    var duration: Double { end - start }
    static let minimumDuration = 0.1

    func validated() throws -> TimelineClip {
        guard sourceDuration.isFinite, sourceStart.isFinite, sourceStart >= 0, start.isFinite, end.isFinite,
              start >= sourceStart, end <= sourceDuration + 0.001,
              duration >= Self.minimumDuration else { throw TimelineError.invalidRange }
        return self
    }

    func split(at localTime: Double) throws -> (TimelineClip, TimelineClip) {
        guard localTime.isFinite, localTime >= Self.minimumDuration,
              duration - localTime >= Self.minimumDuration else { throw TimelineError.invalidSplit }
        var left = self
        var right = self
        left.end = start + localTime
        right.id = UUID()
        right.start = left.end
        return (try left.validated(), try right.validated())
    }
}

enum TimelineError: LocalizedError {
    case invalidRange, invalidSplit
    var errorDescription: String? {
        switch self {
        case .invalidRange: return "O trecho deve ter pelo menos 0,1 s e ficar dentro do vídeo."
        case .invalidSplit: return "Posicione o cursor dentro do clipe, a pelo menos 0,1 s das bordas."
        }
    }
}

extension Array where Element == TimelineClip {
    var totalDuration: Double { reduce(0) { $0 + $1.duration } }
    func offset(of id: UUID) -> Double {
        prefix(while: { $0.id != id }).reduce(0) { $0 + $1.duration }
    }
}
