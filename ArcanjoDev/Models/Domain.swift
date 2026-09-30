import Foundation

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    public var objectValue: [String: JSONValue]? { if case .object(let value) = self { value } else { nil } }
    public var arrayValue: [JSONValue]? { if case .array(let value) = self { value } else { nil } }
    public var boolValue: Bool? { if case .bool(let value) = self { value } else { nil } }
    public var numberValue: Double? { if case .number(let value) = self { value } else { nil } }

    public func encodedString(pretty: Bool = false) -> String {
        let encoder = JSONEncoder()
        if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        guard let data = try? encoder.encode(self) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}

public enum AgentRole: String, Codable, CaseIterable, Sendable, Identifiable, Equatable {
    case researcher, programmer, web, designer, tester, reviewer, devops, integrations, memory, security

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .researcher: "Pesquisador"
        case .programmer: "Programador"
        case .web: "Web"
        case .designer: "Designer"
        case .tester: "Testador"
        case .reviewer: "Revisor"
        case .devops: "DevOps"
        case .integrations: "Integrações"
        case .memory: "Memória"
        case .security: "Segurança"
        }
    }

    public var systemInstruction: String {
        let shared = "Você é um agente especializado do Arcanjo Dev. Use somente as ferramentas explicitamente autorizadas. Não invente que uma ação foi feita: confirme pela saída da ferramenta. Se faltar capacidade, diga isso claramente. Responda à interface interna no formato JSON solicitado."
        let role: String
        switch self {
        case .researcher: role = "Pesquise e sintetize informações. Prefira fontes oficiais e diferencie fatos confirmados de inferências."
        case .programmer: role = "Implemente a tarefa com alterações pequenas, completas e coerentes no workspace. Leia os arquivos antes de alterá-los."
        case .web: role = "Trabalhe em páginas e conteúdo web. Use a ferramenta de leitura web apenas para URLs públicas HTTPS."
        case .designer: role = "Projete estrutura, hierarquia, acessibilidade e conteúdo visual. Não alegue ter renderizado sem usar a prévia."
        case .tester: role = "Inspecione os arquivos e procure defeitos verificáveis. Não declare testes executados se não houver ferramenta de teste."
        case .reviewer: role = "Revise alterações quanto a correção, segurança, regressões e escopo. Fundamente os achados em evidências."
        case .devops: role = "Prepare configurações e instruções reproduzíveis. Não publique nem execute comandos externos sem ferramenta e aprovação."
        case .integrations: role = "Avalie adaptadores e requisitos de credenciais. Não simule serviços externos nem invente endpoints."
        case .memory: role = "Extraia decisões persistentes concisas, não segredos ou dados sensíveis desnecessários."
        case .security: role = "Avalie permissões, caminhos de arquivos, dados e ações externas. Recomende bloqueio quando houver risco não autorizado."
        }
        return shared + "\nPapel: " + role
    }
}

public struct InferenceMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable, Equatable { case system, user, assistant }
    public let role: Role
    public let content: String
    public init(role: Role, content: String) { self.role = role; self.content = content }
}

public struct InferenceRequest: Sendable {
    public let messages: [InferenceMessage]
    public let maxTokens: Int
    public let temperature: Float
    public init(messages: [InferenceMessage], maxTokens: Int = 1024, temperature: Float = 0.2) {
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

public struct InferenceResponse: Sendable {
    public let text: String
    public let promptTokenCount: Int?
    public let generatedTokenCount: Int?
    public init(text: String, promptTokenCount: Int? = nil, generatedTokenCount: Int? = nil) {
        self.text = text
        self.promptTokenCount = promptTokenCount
        self.generatedTokenCount = generatedTokenCount
    }
}

public struct PlannedTask: Codable, Sendable, Identifiable {
    public let id: String
    public let agent: AgentRole
    public let objective: String
    public let expectedResult: String
    public let requiredTools: [String]
    public init(id: String, agent: AgentRole, objective: String, expectedResult: String, requiredTools: [String]) {
        self.id = id; self.agent = agent; self.objective = objective
        self.expectedResult = expectedResult; self.requiredTools = requiredTools
    }
}

public struct TaskPlan: Codable, Sendable {
    public let goal: String
    public let assumptions: [String]
    public let tasks: [PlannedTask]
    public let successCriteria: [String]
    public let maxCorrectionRounds: Int
}

public struct ToolCall: Codable, Sendable, Identifiable {
    public let id: String
    public let tool: String
    public let arguments: [String: JSONValue]
}

public struct AgentTurn: Codable, Sendable {
    public let message: String
    public let toolCalls: [ToolCall]
    public let completed: Bool
    public let confidence: Double
}

public struct AgentTaskReport: Codable, Sendable, Identifiable {
    public let id: String
    public let agent: AgentRole
    public let objective: String
    public let outcome: String
    public let toolResultIDs: [String]
    public let completed: Bool
}

public struct VerificationReport: Codable, Sendable {
    public let passed: Bool
    public let findings: [String]
    public let requiredCorrections: [String]
}

public struct RunRecord: Codable, Sendable, Identifiable {
    public let id: String
    public let goal: String
    public let startedAt: Date
    public let completedAt: Date
    public let plan: TaskPlan
    public let reports: [AgentTaskReport]
    public let verification: VerificationReport
    public let finalMessage: String
}

public enum AgentRunError: LocalizedError {
    case invalidPlanResponse(String)
    case invalidAgentResponse(String)
    case invalidVerificationResponse(String)
    case turnLimitReached(String)
    case modelNotReady
    case userCancelled

    public var errorDescription: String? {
        switch self {
        case .invalidPlanResponse(let text): "O modelo não retornou um plano JSON válido: \(text)"
        case .invalidAgentResponse(let text): "O modelo não retornou uma ação JSON válida: \(text)"
        case .invalidVerificationResponse(let text): "O modelo não retornou uma verificação JSON válida: \(text)"
        case .turnLimitReached(let reason): "Limite de execução atingido: \(reason)"
        case .modelNotReady: "Carregue um modelo local antes de executar uma tarefa."
        case .userCancelled: "A ação foi recusada pelo usuário."
        }
    }
}
