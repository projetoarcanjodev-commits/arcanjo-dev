import Foundation
import SwiftUI

@MainActor
public final class AppModel: ObservableObject {
    @Published public var goal = ""
    @Published public private(set) var runRecord: RunRecord?
    @Published public private(set) var progress: RunProgress?
    @Published public private(set) var isRunning = false
    @Published public private(set) var toolsReady = false
    @Published public private(set) var modelReady = false
    @Published public private(set) var isLoadingModel = false
    @Published public private(set) var activeModelName: String?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var workspaceFiles: [WorkspaceFile] = []
    @Published public var showModelImporter = false
    @Published public var showWorkspaceImporter = false

    public let approvalCenter: ApprovalCenter
    public let workspaceURL: URL
    public let memory: LocalMemoryStore
    public var recommendedModel: RecommendedModelInfo { runtime.recommendedModel }
    private let runtime: any LocalModelProvider
    private let registry: ToolRegistry
    private let workspaceTools: WorkspaceToolSet
    private let modelStore: LocalModelStore
    private var currentTask: Task<Void, Never>?

    public init(runtime: any LocalModelProvider) throws {
        self.runtime = runtime
        let approvalCenter = ApprovalCenter()
        self.approvalCenter = approvalCenter
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        self.workspaceURL = documents.appendingPathComponent("ArcanjoDev/Workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: self.workspaceURL, withIntermediateDirectories: true)
        self.memory = try LocalMemoryStore()
        self.modelStore = try LocalModelStore()
        self.workspaceTools = try WorkspaceToolSet(root: self.workspaceURL)
        self.registry = ToolRegistry(approval: { title, detail in
            await approvalCenter.request(title: title, detail: detail)
        })
        self.activeModelName = modelStore.activeURL?.lastPathComponent ?? (modelStore.activeHubModelID == runtime.recommendedModel.id ? runtime.recommendedModel.displayName : nil)
        Task { [weak self] in
            guard let self else { return }
            await self.workspaceTools.install(into: self.registry)
            self.toolsReady = true
            await self.refreshWorkspace()
            if self.modelStore.activeHubModelID == self.runtime.recommendedModel.id {
                await self.loadRecommendedModel()
            } else if let modelURL = self.modelStore.activeURL {
                await self.loadModel(at: modelURL)
            }
        }
    }

    public func runGoal() {
        guard !isRunning, toolsReady else { return }
        errorMessage = nil; isRunning = true; runRecord = nil
        let goal = self.goal
        let progressUpdate: @Sendable (RunProgress) async -> Void = { [weak self] update in
            await MainActor.run { self?.progress = update }
        }
        let orchestrator = ExecutionOrchestrator(provider: runtime, tools: registry, memory: memory, progress: progressUpdate)
        currentTask = Task { [weak self] in
            do {
                let record = try await orchestrator.run(goal: goal)
                self?.runRecord = record
            } catch {
                self?.errorMessage = error.localizedDescription
            }
            self?.isRunning = false
            self?.currentTask = nil
            await self?.refreshWorkspace()
        }
    }

    public func cancelRun() { currentTask?.cancel() }

    public func setError(_ message: String) { errorMessage = message }
    public func clearError() { errorMessage = nil }

    public func importModel(from sourceURL: URL) async {
        errorMessage = nil
        isLoadingModel = true
        defer { isLoadingModel = false }
        do {
            let store = modelStore
            let copied = try await Task.detached(priority: .userInitiated) {
                try store.importItem(from: sourceURL)
            }.value
            activeModelName = copied.lastPathComponent
            try await runtime.loadModel(at: copied)
            modelReady = await runtime.isReady()
            if !modelReady { throw ModelRuntimeError.loadFailed("O runtime retornou sem indicar modelo pronto.") }
            try modelStore.setActive(copied)
        } catch { errorMessage = error.localizedDescription }
    }

    public func downloadRecommendedModel() async {
        errorMessage = nil
        isLoadingModel = true
        defer { isLoadingModel = false }
        do {
            try await runtime.loadRecommendedModel()
            modelReady = await runtime.isReady()
            guard modelReady else { throw ModelRuntimeError.loadFailed("O runtime não confirmou que o modelo está pronto.") }
            try modelStore.setActiveHubModelID(runtime.recommendedModel.id)
            activeModelName = runtime.recommendedModel.displayName
        } catch {
            modelReady = false
            errorMessage = error.localizedDescription
        }
    }

    public func loadSavedModel() async {
        if modelStore.activeHubModelID == runtime.recommendedModel.id { await loadRecommendedModel(); return }
        guard let url = modelStore.activeURL else { errorMessage = "Baixe o modelo recomendado ou importe um modelo local primeiro."; return }
        await loadModel(at: url)
    }

    private func loadRecommendedModel() async {
        isLoadingModel = true
        defer { isLoadingModel = false }
        do {
            try await runtime.loadRecommendedModel()
            modelReady = await runtime.isReady()
            activeModelName = runtime.recommendedModel.displayName
        } catch {
            modelReady = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadModel(at url: URL) async {
        isLoadingModel = true
        defer { isLoadingModel = false }
        errorMessage = nil
        do {
            try await runtime.loadModel(at: url)
            modelReady = await runtime.isReady()
            activeModelName = url.lastPathComponent
        } catch {
            modelReady = false
            errorMessage = error.localizedDescription
        }
    }

    public func unloadModel() async {
        await runtime.unloadModel()
        modelReady = false
    }

    public func refreshWorkspace() async {
        do {
            let entries = try FileManager.default.contentsOfDirectory(at: workspaceURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
            workspaceFiles = try entries.map { url in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return WorkspaceFile(name: url.lastPathComponent, url: url, isDirectory: values.isDirectory ?? false, bytes: values.fileSize ?? 0)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch { errorMessage = "Não foi possível listar o workspace: \(error.localizedDescription)" }
    }

    public func importWorkspaceItem(from sourceURL: URL) async {
        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            let name = sourceURL.lastPathComponent
            let destination = workspaceURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destination.path) { throw ToolExecutionError.invalidArguments("Já existe um item chamado \(name) no workspace.") }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            await refreshWorkspace()
        } catch { errorMessage = error.localizedDescription }
    }

    public var previewURL: URL? {
        let index = workspaceURL.appendingPathComponent("index.html")
        return FileManager.default.fileExists(atPath: index.path) ? index : nil
    }
}

public struct WorkspaceFile: Identifiable, Sendable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let bytes: Int
    public var id: String { url.path }
}
