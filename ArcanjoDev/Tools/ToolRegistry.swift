import Foundation

public enum ToolRisk: String, Codable, Sendable { case readOnly, workspaceWrite, externalSideEffect, destructive, privileged }

public struct ToolDefinition: Codable, Sendable, Identifiable {
    public let id: String
    public let description: String
    public let inputSchema: String
    public let risk: ToolRisk
    public let requiresApproval: Bool
    public let approvalText: String?
}

public struct ToolResult: Codable, Sendable, Identifiable {
    public let id: String
    public let toolID: String
    public let success: Bool
    public let output: String
    public let timestamp: Date
    public init(id: String = UUID().uuidString, toolID: String, success: Bool, output: String, timestamp: Date = Date()) {
        self.id = id; self.toolID = toolID; self.success = success; self.output = output; self.timestamp = timestamp
    }
}

public enum ToolExecutionError: LocalizedError {
    case unknownTool(String)
    case forbidden(String)
    case approvalDenied(String)
    case invalidArguments(String)
    case outsideWorkspace
    case fileTooLarge

    public var errorDescription: String? {
        switch self {
        case .unknownTool(let id): "Ferramenta inexistente: \(id)"
        case .forbidden(let id): "O papel atual não tem permissão para usar \(id)."
        case .approvalDenied(let id): "A aprovação necessária foi recusada para \(id)."
        case .invalidArguments(let reason): "Argumentos inválidos: \(reason)"
        case .outsideWorkspace: "O caminho solicitado está fora do workspace permitido."
        case .fileTooLarge: "O arquivo ultrapassa o limite de 512 KiB desta versão."
        }
    }
}

public typealias ToolHandler = @Sendable ([String: JSONValue]) async throws -> String
public typealias ApprovalRequestHandler = @Sendable (_ title: String, _ detail: String) async -> Bool

/// Registro em memória com política de chamada centralizada; tool desconhecida nunca é simulada.
public actor ToolRegistry {
    private struct Entry: Sendable { let definition: ToolDefinition; let handler: ToolHandler }
    private var entries: [String: Entry] = [:]
    private let approval: ApprovalRequestHandler?

    public init(approval: ApprovalRequestHandler? = nil) { self.approval = approval }

    public func register(_ definition: ToolDefinition, handler: @escaping ToolHandler) {
        entries[definition.id] = Entry(definition: definition, handler: handler)
    }

    public func definitions() -> [ToolDefinition] { entries.values.map(\.definition).sorted { $0.id < $1.id } }

    public func execute(toolID: String, arguments: [String: JSONValue], as role: AgentRole) async throws -> ToolResult {
        guard let entry = entries[toolID] else { throw ToolExecutionError.unknownTool(toolID) }
        guard AgentCatalog.profile(for: role).allowedTools.contains(toolID) else { throw ToolExecutionError.forbidden(toolID) }
        if entry.definition.requiresApproval {
            guard let approval else { throw ToolExecutionError.approvalDenied(toolID) }
            let payload = JSONValue.object(arguments).encodedString(pretty: true)
            let detail = (entry.definition.approvalText ?? entry.definition.description) + "\n\nPayload enviado pela ferramenta:\n" + payload
            guard await approval("Aprovar ferramenta: \(toolID)", detail) else { throw ToolExecutionError.approvalDenied(toolID) }
        }
        let output = try await entry.handler(arguments)
        return ToolResult(toolID: toolID, success: true, output: output)
    }
}

public final class WorkspaceToolSet: @unchecked Sendable {
    public let root: URL
    private let fm: FileManager
    private let session: URLSession
    private let maxBytes = 512 * 1024

    public init(root: URL, fileManager: FileManager = .default, session: URLSession? = nil) throws {
        self.root = root.standardizedFileURL
        self.fm = fileManager
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
        try fileManager.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public func install(into registry: ToolRegistry) async {
        await registry.register(.init(
            id: "workspace.list", description: "Lista arquivos do workspace local sem retornar pastas ocultas.",
            inputSchema: "{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"}},\"additionalProperties\":false}", risk: .readOnly, requiresApproval: false
        )) { [self] args in
            guard Set(args.keys).isSubset(of: Set(["path"])) else { throw ToolExecutionError.invalidArguments("workspace.list aceita somente path") }
            let relative: String
            if let value = args["path"] {
                guard let path = value.stringValue else { throw ToolExecutionError.invalidArguments("path precisa ser string") }
                relative = path
            } else { relative = "" }
            let folder = try secureURL(relative, mustExist: true)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw ToolExecutionError.invalidArguments("path precisa ser uma pasta existente") }
            let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
            var items: [[String: JSONValue]] = []
            while let url = enumerator?.nextObject() as? URL, items.count < 200 {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
                if values.isSymbolicLink == true { enumerator?.skipDescendants(); continue }
                let rel = String(url.path.dropFirst(self.root.path.count + 1))
                items.append(["path": .string(rel), "kind": .string(values.isDirectory == true ? "directory" : "file"), "bytes": .number(Double(values.fileSize ?? 0))])
            }
            return JSONValue.array(items.map(JSONValue.object)).encodedString(pretty: true)
        }

        await registry.register(.init(
            id: "workspace.read", description: "Lê um arquivo de texto do workspace (máximo 512 KiB).",
            inputSchema: "{\"type\":\"object\",\"required\":[\"path\"],\"properties\":{\"path\":{\"type\":\"string\"}},\"additionalProperties\":false}", risk: .readOnly, requiresApproval: false
        )) { [self] args in
            guard Set(args.keys) == Set(["path"]) else { throw ToolExecutionError.invalidArguments("workspace.read exige somente path") }
            let file = try secureURL(requiredString(args, "path"), mustExist: true)
            let attributes = try fm.attributesOfItem(atPath: file.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard fileSize <= maxBytes else { throw ToolExecutionError.fileTooLarge }
            let data = try Data(contentsOf: file)
            guard let text = String(data: data, encoding: .utf8) else { throw ToolExecutionError.invalidArguments("apenas arquivos UTF-8 podem ser lidos") }
            return text
        }

        await registry.register(.init(
            id: "workspace.write", description: "Cria ou substitui um arquivo UTF-8 no workspace. Sempre pede aprovação explícita.",
            inputSchema: "{\"type\":\"object\",\"required\":[\"path\",\"content\"],\"properties\":{\"path\":{\"type\":\"string\"},\"content\":{\"type\":\"string\"}},\"additionalProperties\":false}", risk: .workspaceWrite, requiresApproval: true, approvalText: "O agente deseja criar ou substituir um arquivo no workspace isolado do app. Confira o caminho e o conteúdo antes de permitir."
        )) { [self] args in
            guard Set(args.keys) == Set(["path", "content"]) else { throw ToolExecutionError.invalidArguments("workspace.write exige somente path e content") }
            let path = try requiredString(args, "path")
            let content = try requiredString(args, "content")
            guard let data = content.data(using: .utf8), data.count <= maxBytes else { throw ToolExecutionError.fileTooLarge }
            let target = try secureURL(path, mustExist: false)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            return "Arquivo gravado: \(path) (\(data.count) bytes)."
        }

        await registry.register(.init(
            id: "workspace.delete", description: "Apaga um arquivo do workspace após aprovação. Pastas não são aceitas.",
            inputSchema: "{\"type\":\"object\",\"required\":[\"path\"],\"properties\":{\"path\":{\"type\":\"string\"}},\"additionalProperties\":false}", risk: .destructive, requiresApproval: true, approvalText: "Esta ação remove permanentemente um arquivo do workspace deste app. Verifique o caminho antes de permitir."
        )) { [self] args in
            guard Set(args.keys) == Set(["path"]) else { throw ToolExecutionError.invalidArguments("workspace.delete exige somente path") }
            let path = try requiredString(args, "path")
            let target = try secureURL(path, mustExist: true)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: target.path, isDirectory: &isDirectory), !isDirectory.boolValue else { throw ToolExecutionError.invalidArguments("delete só aceita arquivos") }
            try fm.removeItem(at: target)
            return "Arquivo removido: \(path)."
        }

        await registry.register(.init(
            id: "workspace.validate", description: "Valida sintaxe local de JSON ou Property List (.plist/.xml), sem executar código.",
            inputSchema: "{\"type\":\"object\",\"required\":[\"path\"],\"properties\":{\"path\":{\"type\":\"string\"}},\"additionalProperties\":false}", risk: .readOnly, requiresApproval: false
        )) { [self] args in
            guard Set(args.keys) == Set(["path"]) else { throw ToolExecutionError.invalidArguments("workspace.validate exige somente path") }
            let path = try requiredString(args, "path")
            let file = try secureURL(path, mustExist: true)
            let size = (try fm.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size <= maxBytes else { throw ToolExecutionError.fileTooLarge }
            let data = try Data(contentsOf: file)
            switch file.pathExtension.lowercased() {
            case "json":
                _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                return "JSON válido: \(path) (\(size) bytes)."
            case "plist", "xml":
                _ = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                return "Property List válida: \(path) (\(size) bytes)."
            default:
                throw ToolExecutionError.invalidArguments("workspace.validate aceita somente .json, .plist ou XML Property List")
            }
        }

        await registry.register(.init(
            id: "web.fetch", description: "Busca uma URL pública HTTPS com GET; sem login, postagem ou envio de dados.",
            inputSchema: "{\"type\":\"object\",\"required\":[\"url\"],\"properties\":{\"url\":{\"type\":\"string\"}},\"additionalProperties\":false}", risk: .externalSideEffect, requiresApproval: true, approvalText: "Esta ação envia uma requisição GET sem conteúdo nem credenciais para o endereço solicitado. Confira a URL e o host."
        )) { [session] args in
            guard Set(args.keys) == Set(["url"]) else { throw ToolExecutionError.invalidArguments("web.fetch exige somente url") }
            let rawURL = try requiredString(args, "url")
            guard let url = URL(string: rawURL), url.scheme?.lowercased() == "https", let host = url.host, url.user == nil, url.password == nil, Self.isPublicHost(host) else {
                throw ToolExecutionError.invalidArguments("web.fetch aceita somente URL HTTPS pública")
            }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.httpMethod = "GET"
            request.httpShouldHandleCookies = false
            request.setValue("text/html,text/plain,application/json;q=0.9,*/*;q=0.5", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request, delegate: BlockRedirectsDelegate())
            guard let http = response as? HTTPURLResponse else { throw ToolExecutionError.invalidArguments("resposta HTTP inválida") }
            let prefix = data.prefix(32 * 1024)
            let text = String(decoding: prefix, as: UTF8.self)
            return "HTTP \(http.statusCode) — \(url.absoluteString)\n\(text)"
        }
    }

    private static func isPublicHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !host.isEmpty, !host.contains(":"), host != "localhost", !host.hasSuffix(".localhost"),
              !host.hasSuffix(".local"), !host.hasSuffix(".internal"), !host.hasSuffix(".test"),
              !host.hasSuffix(".invalid"), !host.hasSuffix(".home.arpa"), host.contains(".") else { return false }
        let pieces = host.split(separator: ".")
        if pieces.count == 4 {
            let octets = pieces.compactMap { UInt8($0) }
            guard octets.count == 4 else { return false }
            let (a, b, c, d) = (octets[0], octets[1], octets[2], octets[3])
            guard a != 0, a != 10, a != 127, a < 224,
                  !(a == 169 && b == 254), !(a == 172 && (16...31).contains(b)),
                  !(a == 192 && b == 168), !(a == 100 && (64...127).contains(b)),
                  !(a == 192 && b == 0 && c == 0), !(a == 192 && b == 0 && c == 2),
                  !(a == 198 && (b == 18 || b == 19)), !(a == 198 && b == 51 && c == 100),
                  !(a == 203 && b == 0 && c == 113), !(a == 255 && b == 255 && c == 255 && d == 255) else { return false }
        }
        return true
    }

    private func requiredString(_ args: [String: JSONValue], _ key: String) throws -> String {
        guard let value = args[key]?.stringValue, !value.isEmpty else { throw ToolExecutionError.invalidArguments("campo obrigatório: \(key)") }
        return value
    }

    private func secureURL(_ relative: String, mustExist: Bool) throws -> URL {
        guard !relative.hasPrefix("/"), !relative.contains("\\"), !relative.split(separator: "/").contains("..") else { throw ToolExecutionError.outsideWorkspace }
        let candidate = root.appendingPathComponent(relative.isEmpty ? "." : relative).standardizedFileURL
        let resolvedRoot = root.resolvingSymlinksInPath().path
        let resolvedCandidate = candidate.resolvingSymlinksInPath().path
        guard resolvedCandidate == resolvedRoot || resolvedCandidate.hasPrefix(resolvedRoot + "/") else { throw ToolExecutionError.outsideWorkspace }
        if mustExist && !fm.fileExists(atPath: candidate.path) { throw ToolExecutionError.invalidArguments("arquivo ou diretório não encontrado") }
        return candidate
    }
}

private final class BlockRedirectsDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
