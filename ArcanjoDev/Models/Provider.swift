import Foundation

/// Contrato único para o cérebro local e futuros especialistas remotos.
/// O app não instancia nem exige providers comerciais por padrão.
public protocol ModelProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func isReady() async -> Bool
    func generate(_ request: InferenceRequest) async throws -> InferenceResponse
}

/// Extensão de ciclo de vida exigida por providers que carregam pesos no dispositivo.
public protocol LocalModelProvider: ModelProvider {
    var recommendedModel: RecommendedModelInfo { get }
    func loadModel(at url: URL) async throws
    /// Inicia a obtenção explícita do modelo recomendado e carrega-o localmente.
    func loadRecommendedModel() async throws
    func unloadModel() async
}

public struct RecommendedModelInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let license: String
    public let sourceURL: URL
    public let note: String
    public init(id: String, displayName: String, license: String, sourceURL: URL, note: String) {
        self.id = id; self.displayName = displayName; self.license = license; self.sourceURL = sourceURL; self.note = note
    }
}

public struct ProviderDescriptor: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let kind: Kind
    public let configured: Bool
    public let note: String
    public enum Kind: String, Codable, Sendable { case local, external }
}

/// Inventário honesto: providers externos aparecem como extensões não configuradas.
/// Uma entrada aqui não indica que o adaptador ou suas credenciais estejam ativos.
public enum ProviderCatalog {
    public static let futureProviders: [ProviderDescriptor] = [
        .init(id: "openai", name: "OpenAI", kind: .external, configured: false, note: "Adaptador futuro; requer credencial e configuração explícita."),
        .init(id: "anthropic", name: "Anthropic / Claude", kind: .external, configured: false, note: "Adaptador futuro; requer credencial e configuração explícita."),
        .init(id: "manus", name: "Manus", kind: .external, configured: false, note: "Sem API presumida; integrar somente por interface documentada."),
        .init(id: "other", name: "Outros providers", kind: .external, configured: false, note: "Implementar ModelProvider para adicionar um provider compatível.")
    ]
}

public enum ModelRuntimeError: LocalizedError {
    case unsupportedModelFile(String)
    case notLoaded
    case loadFailed(String)
    case inferenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedModelFile(let name): "Formato de modelo não suportado: \(name)"
        case .notLoaded: "Nenhum modelo local foi carregado."
        case .loadFailed(let reason): "Falha ao carregar o modelo: \(reason)"
        case .inferenceFailed(let reason): "Falha na inferência local: \(reason)"
        }
    }
}
