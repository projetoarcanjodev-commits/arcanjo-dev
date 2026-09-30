import XCTest
@testable import ArcanjoDev

private actor ScriptedProvider: ModelProvider {
    nonisolated let id = "test.scripted"
    nonisolated let displayName = "Provider de teste (somente XCTest)"
    private var replies: [String]
    init(_ replies: [String]) { self.replies = replies }
    func isReady() async -> Bool { true }
    func generate(_ request: InferenceRequest) async throws -> InferenceResponse {
        guard !replies.isEmpty else { throw TestFailure.scriptExhausted }
        return InferenceResponse(text: replies.removeFirst())
    }
}

private enum TestFailure: Error { case scriptExhausted }

private actor ApprovalCounter {
    private(set) var count = 0
    func approve() -> Bool { count += 1; return true }
    func value() -> Int { count }
}

final class AgentFlowTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func testToolWriteRequiresApprovalAndWritesOnlyInsideWorkspace() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let counter = ApprovalCounter()
        let registry = ToolRegistry(approval: { _, _ in await counter.approve() })
        try await WorkspaceToolSet(root: root).install(into: registry)
        let result = try await registry.execute(toolID: "workspace.write", arguments: [
            "path": .string("site/index.html"), "content": .string("<h1>Local</h1>")
        ], as: .programmer)
        XCTAssertTrue(result.success)
        let approvalCount = await counter.value()
        XCTAssertEqual(approvalCount, 1)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("site/index.html"), encoding: .utf8), "<h1>Local</h1>")
        do {
            _ = try await registry.execute(toolID: "workspace.read", arguments: ["path": .string("../outside.txt")], as: .programmer)
            XCTFail("Traversal fora do workspace deveria ser bloqueado")
        } catch { XCTAssertTrue(error is ToolExecutionError) }
    }

    func testDeniedApprovalPreventsWrite() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = ToolRegistry(approval: { _, _ in false })
        try await WorkspaceToolSet(root: root).install(into: registry)
        do {
            _ = try await registry.execute(toolID: "workspace.write", arguments: [
                "path": .string("blocked.txt"), "content": .string("must not exist")
            ], as: .programmer)
            XCTFail("A escrita foi negada e não deveria concluir")
        } catch { XCTAssertTrue(error is ToolExecutionError) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("blocked.txt").path))
    }

    func testWorkspaceValidateChecksJSONAndRejectsExtraArguments() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("{\"ok\":true}".utf8).write(to: root.appendingPathComponent("valid.json"))
        try Data("{\"broken\":".utf8).write(to: root.appendingPathComponent("broken.json"))
        let registry = ToolRegistry()
        try await WorkspaceToolSet(root: root).install(into: registry)
        let result = try await registry.execute(toolID: "workspace.validate", arguments: ["path": .string("valid.json")], as: .tester)
        XCTAssertTrue(result.output.contains("JSON válido"))
        do {
            _ = try await registry.execute(toolID: "workspace.validate", arguments: ["path": .string("broken.json")], as: .tester)
            XCTFail("JSON truncado deveria falhar na validação")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        do {
            _ = try await registry.execute(toolID: "workspace.validate", arguments: ["path": .string("valid.json"), "unexpected": .string("ignored")], as: .tester)
            XCTFail("Argumentos extras deveriam ser recusados")
        } catch { XCTAssertTrue(error is ToolExecutionError) }
    }

    func testPlannerExecutorVerifierCompletesWithLocalWorkspaceTool() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let memory = try LocalMemoryStore(root: root.appendingPathComponent("memory", isDirectory: true))
        let registry = ToolRegistry(approval: { _, _ in true })
        try await WorkspaceToolSet(root: root.appendingPathComponent("workspace", isDirectory: true)).install(into: registry)
        let script = [
            "{\"goal\":\"Criar página\",\"assumptions\":[],\"tasks\":[{\"id\":\"t1\",\"agent\":\"programmer\",\"objective\":\"Criar index.html\",\"expectedResult\":\"index.html no workspace\",\"requiredTools\":[\"workspace.write\"]}],\"successCriteria\":[\"index.html existe\"],\"maxCorrectionRounds\":1}",
            "{\"message\":\"Criando arquivo\",\"toolCalls\":[{\"id\":\"c1\",\"tool\":\"workspace.write\",\"arguments\":{\"path\":\"index.html\",\"content\":\"<html><body>Arcanjo</body></html>\"}}],\"completed\":false,\"confidence\":0.9}",
            "{\"message\":\"index.html gravado\",\"toolCalls\":[],\"completed\":true,\"confidence\":0.9}",
            "{\"passed\":true,\"findings\":[\"index.html aparece no workspace\"],\"requiredCorrections\":[]}"
        ]
        let provider = ScriptedProvider(script)
        let runner = ExecutionOrchestrator(provider: provider, tools: registry, memory: memory)
        let record = try await runner.run(goal: "Crie uma página HTML simples.")
        XCTAssertTrue(record.verification.passed)
        XCTAssertEqual(record.reports.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("workspace/index.html").path))
        let savedRuns = try await memory.readAll(from: .runs)
        XCTAssertFalse(savedRuns.isEmpty)
    }

    func testMemoryBucketsAreIndependent() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let memory = try LocalMemoryStore(root: root)
        try await memory.append(.init(category: "decision", content: "Local first"), to: .decisions)
        try await memory.append(.init(category: "curated", content: "Use folders for local model import"), to: .longTerm)
        let decisions = try await memory.readAll(from: .decisions)
        let conversations = try await memory.readAll(from: .conversations)
        let longTerm = try await memory.readAll(from: .longTerm)
        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(conversations.count, 0)
        XCTAssertEqual(longTerm.count, 1)
    }
}
