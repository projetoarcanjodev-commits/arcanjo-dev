import Foundation

public enum IntegrationID: String, Codable, CaseIterable, Sendable, Identifiable {
    case git, github, netlify, gmail, whatsappBusiness = "whatsapp_business", instagramMeta = "instagram_meta"
    public var id: String { rawValue }
}

public enum IntegrationState: String, Codable, Sendable { case availableLocally, requiresCredentials, notImplemented }

public struct IntegrationDescriptor: Codable, Sendable, Identifiable {
    public let id: IntegrationID
    public let name: String
    public let state: IntegrationState
    public let note: String
}

public struct IntegrationRequest: Codable, Sendable {
    public let operation: String
    public let payload: JSONValue
}

public struct IntegrationResponse: Codable, Sendable {
    public let success: Bool
    public let data: JSONValue
    public let message: String
}

/// Interface comum para adaptadores futuros. Implementações devem validar escopos,
/// aplicar a política de aprovação e manter segredos no Keychain.
public protocol IntegrationAdapter: Sendable {
    var descriptor: IntegrationDescriptor { get }
    func execute(_ request: IntegrationRequest) async throws -> IntegrationResponse
}

public enum IntegrationCatalog {
    public static let descriptors: [IntegrationDescriptor] = [
        .init(id: .git, name: "Git", state: .notImplemented, note: "Requer implementação compatível com iOS (por exemplo, libgit2); nenhum comando shell é fingido."),
        .init(id: .github, name: "GitHub", state: .notImplemented, note: "Interface preparada, mas OAuth/API, credenciais e operações ainda não estão implementados."),
        .init(id: .netlify, name: "Netlify", state: .notImplemented, note: "Interface preparada; deploy e configuração de credenciais não estão implementados."),
        .init(id: .gmail, name: "Gmail", state: .notImplemented, note: "Interface preparada; leitura, envio e configuração de credenciais não estão implementados."),
        .init(id: .whatsappBusiness, name: "WhatsApp Business", state: .notImplemented, note: "Interface preparada; nenhum envio ou fluxo de credenciais está implementado."),
        .init(id: .instagramMeta, name: "Instagram / Meta", state: .notImplemented, note: "Interface preparada; publicação e configuração de credenciais não estão implementadas.")
    ]
}
