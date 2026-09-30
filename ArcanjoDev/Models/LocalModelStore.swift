import Foundation

/// Guarda referências a modelos importados pelo usuário no contêiner privado do app.
/// Não baixa pesos automaticamente e não contém qualquer modelo no bundle.
public final class LocalModelStore: @unchecked Sendable {
    public let root: URL
    private let activeReference: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        self.root = documents.appendingPathComponent("ArcanjoDev/Models", isDirectory: true)
        self.activeReference = root.appendingPathComponent("active-model.txt")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public var activeURL: URL? {
        guard let raw = try? String(contentsOf: activeReference, encoding: .utf8) else { return nil }
        let relative = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard relative.hasPrefix("local:") else { return nil }
        let path = String(relative.dropFirst("local:".count))
        guard !path.isEmpty, !path.contains(".."), !path.hasPrefix("/") else { return nil }
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/"), fileManager.fileExists(atPath: url.path) else { return nil }
        return url
    }

    public var activeHubModelID: String? {
        guard let raw = try? String(contentsOf: activeReference, encoding: .utf8) else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("hub:") else { return nil }
        let identifier = String(value.dropFirst("hub:".count))
        guard identifier.range(of: #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil else { return nil }
        return identifier
    }

    public func importItem(from sourceURL: URL) throws -> URL {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else { throw ToolExecutionError.invalidArguments("O item selecionado não existe.") }
        guard isDirectory.boolValue else { throw ModelRuntimeError.unsupportedModelFile("Escolha a pasta completa de um modelo MLX; GGUF e arquivos isolados não são suportados neste runtime.") }
        let safeName = sourceURL.lastPathComponent.replacingOccurrences(of: "/", with: "_")
        var destination = root.appendingPathComponent(safeName, isDirectory: isDirectory.boolValue)
        if fileManager.fileExists(atPath: destination.path) {
            let stem = sourceURL.deletingPathExtension().lastPathComponent
            let suffix = sourceURL.pathExtension.isEmpty ? "" : "." + sourceURL.pathExtension
            destination = root.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(8))\(suffix)", isDirectory: isDirectory.boolValue)
        }
        let staging = root.appendingPathComponent(".import-\(UUID().uuidString)", isDirectory: isDirectory.boolValue)
        do {
            try fileManager.copyItem(at: sourceURL, to: staging)
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
        return destination
    }

    public func setActive(_ url: URL) throws {
        let normalized = url.standardizedFileURL
        guard normalized.path.hasPrefix(root.standardizedFileURL.path + "/") else { throw ToolExecutionError.outsideWorkspace }
        let relative = String(normalized.path.dropFirst(root.standardizedFileURL.path.count + 1))
        try Data(("local:" + relative + "\n").utf8).write(to: activeReference, options: .atomic)
    }

    public func setActiveHubModelID(_ id: String) throws {
        guard id.range(of: #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil else {
            throw ToolExecutionError.invalidArguments("ID de modelo inválido.")
        }
        try Data(("hub:" + id + "\n").utf8).write(to: activeReference, options: .atomic)
    }

    public func listImportedItems() throws -> [URL] {
        try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
            .filter { $0.lastPathComponent != activeReference.lastPathComponent }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}
