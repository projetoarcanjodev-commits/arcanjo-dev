import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// Provider real de inferência no dispositivo com MLX Swift LM.
/// O download só começa quando loadRecommendedModel() é chamado pela ação explícita do usuário.
public actor MLXLocalModelProvider: LocalModelProvider {
    public nonisolated let id = "mlx.swift.local"
    public nonisolated let displayName = "MLX Swift (Apple Metal)"
    public nonisolated let recommendedModel = RecommendedModelInfo(
        id: "mlx-community/Qwen3-0.6B-4bit",
        displayName: "Qwen3 0.6B (MLX, 4-bit)",
        license: "Apache-2.0 (modelo-base Qwen3; verificar a ficha da conversão)",
        sourceURL: URL(string: "https://huggingface.co/mlx-community/Qwen3-0.6B-4bit")!,
        note: "Modelo pequeno de partida. Conversão MLX da comunidade a partir de Qwen3-0.6B; o app baixa os pesos após toque explícito e não os inclui no ZIP. Qualidade PT-BR, RAM, velocidade e tool-calling não foram medidos neste build."
    )

    private var container: ModelContainer?
    private let maximumPromptCharacters = 36_000
    private let maximumHistoryMessages = 6
    private let maximumGeneratedTokens = 1_024

    public init() {}

    public func isReady() async -> Bool { container != nil }

    public func loadRecommendedModel() async throws {
        try await load(configuration: MLXLLM.LLMRegistry.qwen3_0_6b_4bit)
    }

    public func loadModel(at url: URL) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ModelRuntimeError.unsupportedModelFile("Selecione uma pasta de modelo no formato MLX, não um arquivo isolado/GGUF.")
        }
        try await load(configuration: ModelConfiguration(directory: url))
    }

    public func unloadModel() async { container = nil }

    public func generate(_ request: InferenceRequest) async throws -> InferenceResponse {
        guard let container else { throw ModelRuntimeError.notLoaded }
        let bounded = Self.boundMessages(request.messages, maximumCharacters: maximumPromptCharacters, maximumHistory: maximumHistoryMessages)
        guard let latest = bounded.last(where: { $0.role != .system }), latest.role == .user else {
            throw ModelRuntimeError.inferenceFailed("A última mensagem do pedido precisa ser do usuário.")
        }
        let system = bounded.first(where: { $0.role == .system })?.content
        let conversation = bounded.filter { $0.role != .system }
        let history = conversation.dropLast().compactMap(Self.chatMessage)
        let instructions = [system, "/no_think", "Responda de forma concisa. Quando solicitado pelo sistema, retorne JSON válido sem cercas Markdown."].compactMap { $0 }.joined(separator: "\n\n")
        let parameters = GenerateParameters(
            maxTokens: min(max(request.maxTokens, 32), maximumGeneratedTokens),
            temperature: max(request.temperature, 0.7),
            topP: 0.8
        )
        // ChatSession aplica o chat template/tokenizer do modelo carregado.
        // Reidratar histórico a cada pedido preserva a API independente do provider;
        // os limites acima reduzem recálculo e evitam crescer sem teto.
        let session = ChatSession(container, instructions: instructions, history: history, generateParameters: parameters)
        var output = ""
        do {
            for try await event in session.streamDetails(to: latest.content, images: [], videos: []) {
                switch event {
                case .chunk(let text): output += text
                case .info(_): break
                case .toolCall(_):
                    // O Arcanjo usa sua própria camada de tools/approval. Não execute tool call nativo do modelo aqui.
                    throw ModelRuntimeError.inferenceFailed("O modelo emitiu uma chamada nativa fora do protocolo JSON do orquestrador; nenhuma ferramenta foi executada.")
                }
            }
        } catch let error as ModelRuntimeError { throw error }
        catch { throw ModelRuntimeError.inferenceFailed(error.localizedDescription) }
        return InferenceResponse(text: output)
    }

    private func load(configuration: ModelConfiguration) async throws {
        do {
            let client = HubClient()
            let downloader = #hubDownloader(client)
            let tokenizerLoader = #huggingFaceTokenizerLoader()
            let factory: any ModelFactory = LLMModelFactory.shared
            let loaded = try await factory.loadContainer(
                from: downloader,
                using: tokenizerLoader,
                configuration: configuration
            )
            container = loaded
        } catch {
            container = nil
            throw ModelRuntimeError.loadFailed(error.localizedDescription)
        }
    }

    private static func chatMessage(_ message: InferenceMessage) -> Chat.Message? {
        switch message.role {
        case .system: nil
        case .user: .user(message.content)
        case .assistant: .assistant(message.content)
        }
    }

    private static func boundMessages(_ messages: [InferenceMessage], maximumCharacters: Int, maximumHistory: Int) -> [InferenceMessage] {
        guard !messages.isEmpty else { return [] }
        let system = messages.first(where: { $0.role == .system }).map {
            InferenceMessage(role: .system, content: String($0.content.prefix(6_000)))
        }
        let nonSystem = messages.filter { $0.role != .system }
        guard let latest = nonSystem.last else { return system.map { [$0] } ?? [] }
        let firstUser = nonSystem.first(where: { $0.role == .user })
        var retained = Array(nonSystem.dropLast().suffix(maximumHistory))
        if let firstUser, firstUser != latest, !retained.contains(where: { $0 == firstUser }) {
            retained.insert(firstUser, at: 0)
        }
        let boundedHistory = retained.map { InferenceMessage(role: $0.role, content: String($0.content.prefix(2_500))) }
        let boundedLatest = InferenceMessage(role: latest.role, content: String(latest.content.prefix(min(9_000, maximumCharacters / 4))))
        let result = (system.map { [$0] } ?? []) + boundedHistory + [boundedLatest]
        return result
    }
}
