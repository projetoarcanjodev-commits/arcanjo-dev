import SwiftUI
import UniformTypeIdentifiers

public struct MainViews: View {
    @ObservedObject private var model: AppModel
    @ObservedObject private var approvals: ApprovalCenter
    @State private var showPreview = false

    public init(model: AppModel) {
        self.model = model
        self.approvals = model.approvalCenter
    }

    public var body: some View {
        TabView {
            taskScreen
                .tabItem { Label("Agente", systemImage: "sparkles") }
            WorkspaceView(model: model)
                .tabItem { Label("Workspace", systemImage: "folder") }
            MemoryView(memory: model.memory)
                .tabItem { Label("Memória", systemImage: "internaldrive") }
        }
        .tint(.indigo)
        .sheet(item: approvalBinding) { request in
            ApprovalSheet(request: request, center: approvals)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showPreview) {
            if let url = model.previewURL {
                WebPreviewScreen(url: url)
            }
        }
        .fileImporter(isPresented: $model.showModelImporter, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await model.importModel(from: url) }
            case .failure(let error): model.setError(error.localizedDescription)
            }
        }
        .alert("Arcanjo Dev", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var approvalBinding: Binding<ApprovalRequest?> {
        Binding(get: { approvals.pending }, set: { value in
            if value == nil, approvals.pending != nil { approvals.resolve(approved: false) }
        })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { visible in if !visible { model.clearError() } })
    }

    private var taskScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Arcanjo Dev").font(.largeTitle.bold())
                        Text("Agente pessoal local para planejar, executar e revisar trabalho.")
                            .foregroundStyle(.secondary)
                    }
                    modelCard
                    VStack(alignment: .leading, spacing: 10) {
                        Text("O que você quer realizar?").font(.headline)
                        TextEditor(text: $model.goal)
                            .frame(minHeight: 130)
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topLeading) {
                                if model.goal.isEmpty {
                                    Text("Ex.: Crie uma página responsiva para uma pizzaria, com cardápio, contato e arquivos HTML/CSS.")
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 14).padding(.vertical, 17)
                                        .allowsHitTesting(false)
                                }
                            }
                        HStack {
                            Button {
                                if model.isRunning { model.cancelRun() } else { model.runGoal() }
                            } label: {
                                Label(model.isRunning ? "Cancelar execução" : "Planejar e executar", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.isRunning && (!model.modelReady || !model.toolsReady || model.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                            if model.previewURL != nil {
                                Button { showPreview = true } label: { Label("Prévia", systemImage: "safari") }
                                    .buttonStyle(.bordered)
                            }
                        }
                        if !model.toolsReady {
                            Label("Preparando workspace e ferramentas…", systemImage: "hourglass")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let progress = model.progress {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { ProgressView(); Text(progress.phase.capitalized).font(.headline) }
                            Text(progress.detail).font(.subheadline).foregroundStyle(.secondary)
                            if progress.totalTasks > 0 { ProgressView(value: Double(progress.completedTasks), total: Double(progress.totalTasks)) }
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if let record = model.runRecord { resultCard(record) }
                    integrationsCard
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.modelReady ? "cpu.fill" : "cpu")
                    .font(.title2).foregroundStyle(model.modelReady ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.modelReady ? "Modelo local pronto" : "Modelo local necessário").font(.headline)
                    Text(model.activeModelName ?? "Nenhum peso está incluído no app.")
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            Text("Recomendado: \(model.recommendedModel.displayName) · \(model.recommendedModel.license)")
                .font(.caption).foregroundStyle(.secondary)
            Text(model.recommendedModel.note).font(.caption).foregroundStyle(.secondary)
            Link("Abrir ficha do modelo", destination: model.recommendedModel.sourceURL)
            HStack {
                Button {
                    Task { await model.downloadRecommendedModel() }
                } label: {
                    Label(model.isLoadingModel ? "Baixando/carregando…" : "Baixar recomendado", systemImage: model.isLoadingModel ? "hourglass" : "icloud.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isLoadingModel)
                Button { model.showModelImporter = true } label: { Label("Importar pasta", systemImage: "folder.badge.plus") }
                    .buttonStyle(.bordered)
                if model.modelReady {
                    Button("Descarregar") { Task { await model.unloadModel() } }.buttonStyle(.bordered)
                }
            }
            if model.isLoadingModel { ProgressView("Baixando ou carregando no dispositivo…") }
            Text("O primeiro download usa internet e pode transferir centenas de MB. Depois, os pesos ficam em cache local. Modelos importados também podem ocupar vários GB e usar memória significativa.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func resultCard(_ record: RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(record.verification.passed ? "Verificação passou" : "Verificação não passou", systemImage: record.verification.passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(record.verification.passed ? .green : .orange)
            Text(record.finalMessage).font(.subheadline)
            if !record.plan.tasks.isEmpty {
                Text("Plano").font(.subheadline.bold())
                ForEach(record.plan.tasks) { task in
                    HStack(alignment: .top) {
                        Image(systemName: "person.crop.circle").foregroundStyle(.indigo)
                        VStack(alignment: .leading) {
                            Text(task.agent.title).font(.caption.bold())
                            Text(task.objective).font(.caption)
                        }
                    }
                }
            }
            if !record.verification.findings.isEmpty {
                Text("Achados").font(.subheadline.bold())
                ForEach(record.verification.findings, id: \.self) { Text("• \($0)").font(.caption) }
            }
            if !record.verification.passed {
                ForEach(record.verification.requiredCorrections, id: \.self) { Text("Correção pendente: \($0)").font(.caption).foregroundStyle(.orange) }
            }
            Text("A aprovação confirma somente a operação descrita no diálogo. Verificação por modelo não substitui build, testes automatizados ou revisão humana.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var integrationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Integrações externas").font(.headline)
            Text("Arquitetura preparada; ainda sem adaptadores operacionais ou credenciais.").font(.caption).foregroundStyle(.secondary)
            ForEach(IntegrationCatalog.descriptors) { descriptor in
                HStack {
                    Text(descriptor.name).font(.subheadline)
                    Spacer()
                    Text(descriptor.state.rawValue).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ApprovalSheet: View {
    let request: ApprovalRequest
    @ObservedObject var center: ApprovalCenter
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Aprovação necessária", systemImage: "hand.raised.fill").font(.title2.bold())
                Text(request.title).font(.headline)
                ScrollView {
                    Text(request.detail)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 260)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                Text("Se recusar, a ferramenta não será executada.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                HStack {
                    Button("Recusar", role: .cancel) { center.resolve(approved: false) }
                        .buttonStyle(.bordered)
                    Button("Aprovar esta ação") { center.resolve(approved: true) }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}
