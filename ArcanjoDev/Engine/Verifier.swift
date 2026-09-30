import Foundation

public struct Verifier: Sendable {
    private let provider: any ModelProvider
    private let tools: ToolRegistry
    public init(provider: any ModelProvider, tools: ToolRegistry) { self.provider = provider; self.tools = tools }

    public func verify(goal: String, plan: TaskPlan, reports: [AgentTaskReport]) async throws -> VerificationReport {
        let workspaceEvidence: String
        do {
            let result = try await tools.execute(toolID: "workspace.list", arguments: ["path": .string("")], as: .reviewer)
            workspaceEvidence = result.output
        } catch {
            workspaceEvidence = "Falha ao inspecionar workspace: \(error.localizedDescription)"
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let planJSON = String(decoding: try encoder.encode(plan), as: UTF8.self)
        let reportsJSON = String(decoding: try encoder.encode(reports), as: UTF8.self)
        let prompt = """
        Verifique o resultado da tarefa com ceticismo. Não considere uma tarefa pronta só porque um agente diz que concluiu. Compare os critérios de sucesso com os relatórios e a evidência real de arquivos. A ferramenta workspace.list apenas lista arquivos e não executa build, testes ou preview; não alegue que esses foram executados. Se houver critérios não verificáveis ou arquivos ausentes, marque passed=false e descreva a correção necessária. Responda APENAS JSON: {"passed":false,"findings":["..."],"requiredCorrections":["..."]}.
        Objetivo: \(goal)
        Plano: \(planJSON)
        Relatórios de agentes: \(reportsJSON)
        Evidência de arquivos do workspace: \(workspaceEvidence)
        """
        let response = try await provider.generate(.init(messages: [
            .init(role: .system, content: "Você é o verificador independente do Arcanjo Dev. Não invente validações."),
            .init(role: .user, content: prompt)
        ], maxTokens: 700, temperature: 0.0))
        do {
            let report = try JSONDecoder().decode(VerificationReport.self, from: Planner.jsonData(response.text))
            if report.passed && !report.requiredCorrections.isEmpty {
                return VerificationReport(passed: false, findings: report.findings, requiredCorrections: report.requiredCorrections)
            }
            return report
        } catch { throw AgentRunError.invalidVerificationResponse(String(response.text.prefix(800))) }
    }
}
