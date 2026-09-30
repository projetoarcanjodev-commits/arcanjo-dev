import SwiftUI
import UniformTypeIdentifiers

public struct WorkspaceView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFile: WorkspaceFile?

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(model.workspaceURL.path)
                        .font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    Text("O agente só lê e altera arquivos dentro deste diretório. Escritas e exclusões pedem aprovação.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Arquivos") {
                    if model.workspaceFiles.isEmpty {
                        ContentUnavailableView("Workspace vazio", systemImage: "folder", description: Text("Peça ao agente para criar arquivos ou importe um item."))
                    }
                    ForEach(model.workspaceFiles) { file in
                        Button { selectedFile = file } label: {
                            HStack {
                                Image(systemName: file.isDirectory ? "folder.fill" : "doc.text")
                                VStack(alignment: .leading) {
                                    Text(file.name).foregroundStyle(.primary)
                                    if !file.isDirectory { Text("\(file.bytes) bytes").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                if file.name == "index.html" { Image(systemName: "safari").foregroundStyle(.indigo) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workspace")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.showWorkspaceImporter = true } label: { Label("Importar", systemImage: "square.and.arrow.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await model.refreshWorkspace() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .fileImporter(isPresented: $model.showWorkspaceImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { Task { await model.importWorkspaceItem(from: url) } }
                case .failure(let error): model.setError(error.localizedDescription)
                }
            }
            .sheet(item: $selectedFile) { file in
                FilePreviewSheet(file: file)
            }
        }
    }
}

private struct FilePreviewSheet: View {
    let file: WorkspaceFile
    @Environment(\.dismiss) private var dismiss
    @State private var contents = ""
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if file.isDirectory {
                    ContentUnavailableView("Pasta", systemImage: "folder", description: Text(file.url.path))
                } else if file.name.lowercased().hasSuffix(".html") {
                    WebPreview(url: file.url)
                } else {
                    ScrollView { Text(contents).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                }
            }
            .navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } } }
            .task {
                guard !file.isDirectory, !file.name.lowercased().hasSuffix(".html") else { return }
                do {
                    let data = try Data(contentsOf: file.url)
                    guard data.count <= 512 * 1024 else { loadError = "Prévia limitada a 512 KiB."; return }
                    contents = String(decoding: data, as: UTF8.self)
                } catch { loadError = error.localizedDescription }
            }
            .alert("Não foi possível abrir", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
                Button("OK", role: .cancel) { loadError = nil }
            } message: { Text(loadError ?? "") }
        }
    }
}

private struct MemoryBucketSnapshot: Identifiable {
    let name: String
    let events: [MemoryEvent]
    var id: String { name }
}

public struct MemoryView: View {
    let memory: LocalMemoryStore
    @State private var buckets: [MemoryBucketSnapshot] = []
    @State private var error: String?

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Memória guardada localmente em Application Support, dividida por finalidade. Não há sincronização remota.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(buckets) { bucket in
                    Section("\(bucket.name) (\(bucket.events.count))") {
                        if bucket.events.isEmpty { Text("Sem registros").foregroundStyle(.secondary) }
                        ForEach(Array(bucket.events.suffix(50).reversed().enumerated()), id: \.offset) { _, event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.category.capitalized).font(.caption.bold())
                                Text(event.content).font(.caption).lineLimit(5)
                                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memória")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") } } }
            .task { await load() }
            .alert("Memória", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    @MainActor private func load() async {
        do {
            var loaded: [MemoryBucketSnapshot] = []
            for bucket in LocalMemoryStore.Bucket.allCases {
                loaded.append(MemoryBucketSnapshot(name: bucket.rawValue, events: try await memory.readAll(from: bucket)))
            }
            buckets = loaded
        } catch { error = error.localizedDescription }
    }
}
