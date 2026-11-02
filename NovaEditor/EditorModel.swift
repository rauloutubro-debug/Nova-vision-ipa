import SwiftUI
import AVKit

@MainActor
final class EditorModel: ObservableObject {
    @Published private(set) var clips: [TimelineClip] = []
    @Published var selection: UUID?
    @Published var position: Double = 0
    @Published private(set) var busy = false
    @Published private(set) var status = ""
    @Published var error: String?
    @Published var shareURL: URL?
    let player = AVPlayer()
    private var edit: EditComposition?
    private var observer: Any?
    private let directory: URL
    private let projectURL: URL

    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NovaEditor", isDirectory: true)
        directory = root.appendingPathComponent("Media", isDirectory: true)
        projectURL = root.appendingPathComponent("project.json")
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, time.seconds.isFinite else { return }
                self.position = min(max(0, time.seconds), self.clips.totalDuration)
            }
        }
        Task { await restore() }
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
    }

    private func begin(_ message: String) -> Bool {
        guard !busy else { return false }
        busy = true
        status = message
        player.pause()
        return true
    }

    private func restore() async {
        guard begin("Abrindo projeto…") else { return }
        defer { busy = false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: projectURL.path) {
                let saved = try JSONDecoder().decode([TimelineClip].self, from: Data(contentsOf: projectURL))
                try await commit(saved)
            }
            // Remove interrupted imports and obsolete media only after a successful project load.
            cleanUnusedMedia()
        } catch { self.error = "Não foi possível abrir o projeto: \(error.localizedDescription)" }
    }

    private func commit(_ candidates: [TimelineClip]) async throws {
        let built: EditComposition?
        if candidates.isEmpty {
            built = nil
        } else {
            built = try await MediaEngine.build(candidates, directory: directory)
        }
        let data = try JSONEncoder().encode(candidates)
        try data.write(to: projectURL, options: .atomic)
        let oldPosition = position
        clips = candidates
        edit = built
        if let built {
            let item = AVPlayerItem(asset: built.asset)
            item.videoComposition = built.video
            player.replaceCurrentItem(with: item)
            seek(min(oldPosition, candidates.totalDuration))
        } else {
            player.replaceCurrentItem(with: nil)
            position = 0
        }
        if !candidates.contains(where: { $0.id == selection }) { selection = candidates.first?.id }
    }

    func importFiles(_ urls: [URL]) async {
        guard !urls.isEmpty, begin("Importando vídeos…") else { return }
        defer { busy = false }
        var copied: [URL] = []
        do {
            var candidates = clips
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let name = UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                let destination = directory.appendingPathComponent(name)
                copied.append(destination)
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.copyItem(at: url, to: destination)
                }.value
                let asset = AVURLAsset(url: destination)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard !tracks.isEmpty else { throw MediaError.noVideo }
                let duration = try await asset.load(.duration).seconds
                let videoRange = try await tracks[0].load(.timeRange)
                let sourceStart = max(0, videoRange.start.seconds)
                let sourceEnd = min(duration, videoRange.end.seconds)
                let clip = TimelineClip(fileName: name, title: url.deletingPathExtension().lastPathComponent,
                                        sourceDuration: sourceEnd, sourceStart: sourceStart,
                                        start: sourceStart, end: sourceEnd)
                candidates.append(try clip.validated())
            }
            try await commit(candidates)
            selection = candidates.last?.id
        } catch {
            for url in copied { try? FileManager.default.removeItem(at: url) }
            self.error = "Falha na importação. O projeto anterior foi preservado. \(error.localizedDescription)"
        }
    }

    func seek(_ seconds: Double) {
        let value = min(max(0, seconds), clips.totalDuration)
        position = value
        player.seek(to: CMTime(seconds: value, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func select(_ clip: TimelineClip) {
        selection = clip.id
        player.pause()
        seek(clips.offset(of: clip.id))
    }

    func change(_ updated: [TimelineClip]) async {
        guard begin("Atualizando edição…") else { return }
        defer { busy = false }
        do { try await commit(updated); cleanUnusedMedia() }
        catch { self.error = error.localizedDescription }
    }

    func split() async {
        guard let id = selection, let index = clips.firstIndex(where: { $0.id == id }) else { return }
        do {
            let (left, right) = try clips[index].split(at: position - clips.offset(of: id))
            var updated = clips
            updated.replaceSubrange(index...index, with: [left, right])
            await change(updated)
        } catch { self.error = error.localizedDescription }
    }

    func export() async {
        guard let edit, begin("Exportando vídeo… Aguarde.") else { return }
        defer { busy = false }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NovaEditor-\(UUID().uuidString).mp4")
        do {
            try await MediaEngine.export(edit, to: url)
            shareURL = url
        } catch {
            try? FileManager.default.removeItem(at: url)
            self.error = error.localizedDescription
        }
    }

    private func cleanUnusedMedia() {
        let used = Set(clips.map(\.fileName))
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            if !used.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at: url) }
        }
    }
}
