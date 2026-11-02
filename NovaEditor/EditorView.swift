import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct EditorView: View {
    @StateObject private var model = EditorModel()
    @State private var importing = false
    @State private var trimming: TimelineClip?
    private var selected: TimelineClip? { model.clips.first { $0.id == model.selection } }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack {
                            Color.black
                            if model.clips.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "film.stack").font(.largeTitle)
                                    Text("Importe vídeos para começar")
                                    Text("Os arquivos são copiados para o projeto neste dispositivo.")
                                        .font(.caption).multilineTextAlignment(.center)
                                }.foregroundStyle(.white)
                            } else {
                                VideoPlayer(player: model.player)
                            }
                        }
                        .frame(height: min(geometry.size.height * 0.47, 480))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        if !model.clips.isEmpty {
                            HStack {
                                Text("Timeline").font(.headline)
                                Spacer()
                                Text("\(model.position, specifier: "%.1f") / \(model.clips.totalDuration, specifier: "%.1f") s")
                                    .monospacedDigit().font(.caption)
                            }
                            Slider(value: Binding(get: { model.position }, set: { model.seek($0) }),
                                   in: 0...max(0.1, model.clips.totalDuration),
                                   onEditingChanged: { editing in if editing { model.player.pause() } })
                                .accessibilityLabel("Posição na timeline")
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(Array(model.clips.enumerated()), id: \.element.id) { index, clip in
                                        Button { model.select(clip) } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("\(index + 1). \(clip.title)").lineLimit(1)
                                                Text("\(clip.duration, specifier: "%.1f") s · \(clip.effect.title)").font(.caption)
                                            }
                                            .padding(12).frame(width: max(130, min(240, clip.duration * 10)), alignment: .leading)
                                            .background(model.selection == clip.id ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.selection == clip.id ? Color.accentColor : .clear, lineWidth: 2))
                                        }.buttonStyle(.plain)
                                        .accessibilityLabel("Clipe \(index + 1), \(clip.title), \(clip.duration) segundos")
                                    }
                                }.padding(3)
                            }
                            if let clip = selected {
                                controls(clip)
                            }
                        }
                        Text("MVP local · MP4 · canvas 720p · 30 quadros/s")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding().frame(maxWidth: 1100).frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("NovaEditor")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { importing = true } label: { Label("Importar", systemImage: "plus") }
                    Button { Task { await model.export() } } label: { Label("Exportar", systemImage: "square.and.arrow.up") }
                        .disabled(model.clips.isEmpty)
                }
            }
            .disabled(model.busy)
            .overlay {
                if model.busy {
                    VStack(spacing: 12) { ProgressView(); Text(model.status).font(.callout) }
                        .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await model.importFiles(urls) }
                case .failure(let error): model.error = error.localizedDescription
                }
            }
            .sheet(item: $trimming) { clip in
                TrimView(clip: clip) { updated in
                    var clips = model.clips
                    if let index = clips.firstIndex(where: { $0.id == updated.id }) { clips[index] = updated }
                    Task { await model.change(clips) }
                }
            }
            .sheet(isPresented: Binding(get: { model.shareURL != nil }, set: { if !$0 { model.shareURL = nil } })) {
                if let url = model.shareURL { ShareSheet(url: url) }
            }
            .alert("Não foi possível concluir", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }

    @ViewBuilder private func controls(_ clip: TimelineClip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack { editButtons(clip) }
                VStack(alignment: .leading) { editButtons(clip) }
            }
            Picker("Efeito do clipe", selection: Binding(get: { clip.effect }, set: { effect in
                var clips = model.clips
                if let index = clips.firstIndex(where: { $0.id == clip.id }) { clips[index].effect = effect }
                Task { await model.change(clips) }
            })) {
                ForEach(VideoEffect.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.menu)
            Text("Cortar divide o clipe selecionado na posição do cursor. Ajustar trecho define a entrada e a saída.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func editButtons(_ clip: TimelineClip) -> some View {
        Button("Cortar", systemImage: "scissors") { Task { await model.split() } }
        Button("Ajustar trecho", systemImage: "slider.horizontal.3") { trimming = clip }
        Button("Mover antes", systemImage: "arrow.left") { move(clip, delta: -1) }
            .disabled(model.clips.first?.id == clip.id)
        Button("Mover depois", systemImage: "arrow.right") { move(clip, delta: 1) }
            .disabled(model.clips.last?.id == clip.id)
        Button("Remover", systemImage: "trash", role: .destructive) {
            Task { await model.change(model.clips.filter { $0.id != clip.id }) }
        }
    }

    private func move(_ clip: TimelineClip, delta: Int) {
        var clips = model.clips
        guard let index = clips.firstIndex(where: { $0.id == clip.id }), clips.indices.contains(index + delta) else { return }
        clips.swapAt(index, index + delta)
        Task { await model.change(clips) }
    }
}

private struct TrimView: View {
    @Environment(\.dismiss) private var dismiss
    @State var clip: TimelineClip
    let apply: (TimelineClip) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Entrada: \(clip.start, specifier: "%.2f") s") {
                    Slider(value: $clip.start, in: clip.sourceStart...max(clip.sourceStart, clip.end - TimelineClip.minimumDuration))
                }
                Section("Saída: \(clip.end, specifier: "%.2f") s") {
                    Slider(value: $clip.end, in: min(clip.sourceDuration, clip.start + TimelineClip.minimumDuration)...clip.sourceDuration)
                }
                Text("Duração do trecho: \(clip.duration, specifier: "%.2f") s")
            }
            .navigationTitle("Ajustar trecho")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Aplicar") { apply(clip); dismiss() } }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
