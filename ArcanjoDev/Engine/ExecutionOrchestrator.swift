import Foundation

public struct RunProgress: Sendable {
    public let phase: String
    public let detail: String
    public let completedTasks: Int
    public let totalTasks: Int
    public init(phase: String, detail: String, completedTasks: Int = 0, totalTasks: Int = 0) {
        self.phase = phase; self.detail = detail; self.completedTasks = completedTasks; self.totalTasks = totalTasks
    }
}

public actor ExecutionOrchestrator {
    private let provider: any ModelProvider
    private let tools: ToolRegistry
    private let memory: LocalMemoryStore
    private let progress: (@Sendable (RunProgress) async -> Void)?

    public init(provider: any ModelProvider, tools: ToolRegistry, memory: LocalMemoryStore, progress: (@Sendable (RunProgress) async -> Void)? = nil) {
        self.provider = provider; self.tools = tools; self.memory = memory; self.progress = progress
    }

    public func run(goal: String) async throws -> RunRecord {
        let normalizedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedGoal.isEmpty else { throw AgentRunError.invalidPlanResponse("O objetivo não pode estar vazio.") }
        guard await provider.isReady() else { throw AgentRunError.modelNotReady }
        let runID = UUID().uuidString
        let startedAt = Date()
        try await memory.append(.init(projectID: runID, category: "user", content: normalizedGoal), to: .conversations)
        await progress?(RunProgress(phase: "planning", detail: "Criando plano local…"))
        let plan = try await Planner(provider: provider, memory: memory).makePlan(for: normalizedGoal)
        let worker = AgentWorker(provider: provider, tools: tools, memory: memory)
        var reports: [AgentTaskReport] = []
        var allResults: [ToolResult] = []
        for (index, task) in plan.tasks.enumerated() {
            await progress?(RunProgress(phase: "agent", detail: "\(task.agent.title): \(task.objective)", completedTasks: index, totalTasks: plan.tasks.count))
            let (report, results) = try await worker.perform(task, runID: runID)
            reports.append(report); allResults.append(contentsOf: results)
        }
        let verifier = Verifier(provider: provider, tools: tools)
        var verification = try await verifier.verify(goal: normalizedGoal, plan: plan, reports: reports)
        var correctionRounds = 0
        while !verification.passed && correctionRounds < plan.maxCorrectionRounds {
            try Task.checkCancellation()
            correctionRounds += 1
            await progress?(RunProgress(phase: "correction", detail: "Corrigindo: \(verification.requiredCorrections.joined(separator: "; "))", completedTasks: correctionRounds, totalTasks: plan.maxCorrectionRounds))
            let correction = PlannedTask(
                id: "correction-\(correctionRounds)", agent: .programmer,
                objective: "Corrija apenas os achados abaixo sem ampliar o escopo: \(verification.requiredCorrections.joined(separator: " | "))",
                expectedResult: "Correções implementadas ou bloqueadores objetivos explicados.",
                requiredTools: ["workspace.read", "workspace.write"]
            )
            let (report, results) = try await worker.perform(correction, runID: runID)
            reports.append(report); allResults.append(contentsOf: results)
            verification = try await verifier.verify(goal: normalizedGoal, plan: plan, reports: reports)
        }
        let finalMessage = verification.passed
            ? "Tarefa concluída e verificada pelo agente local. Consulte os arquivos e relatórios antes de usar em produção."
            : "Tarefa executada, mas a verificação não passou. Achados: " + verification.findings.joined(separator: " | ")
        let record = RunRecord(id: runID, goal: normalizedGoal, startedAt: startedAt, completedAt: Date(), plan: plan, reports: reports, verification: verification, finalMessage: finalMessage)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let recordText = String(decoding: try encoder.encode(record), as: UTF8.self)
        try await memory.append(.init(projectID: runID, category: "run", content: recordText), to: .runs)
        try await memory.append(.init(projectID: runID, category: "assistant", content: finalMessage), to: .conversations)
        await progress?(RunProgress(phase: "finished", detail: finalMessage, completedTasks: reports.count, totalTasks: reports.count))
        return record
    }
}
