import SwiftUI

@main
public struct ArcanjoDevApp: App {
    public init() {}
    public var body: some Scene {
        WindowGroup { BootstrapView() }
    }
}

private struct BootstrapView: View {
    @State private var model: AppModel?
    @State private var startupError: String?
    @State private var attempt = 0

    var body: some View {
        Group {
            if let model {
                MainViews(model: model)
            } else if let startupError {
                ContentUnavailableView {
                    Label("Falha ao iniciar", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(startupError)
                } actions: {
                    Button("Tentar novamente") { attempt += 1 }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Iniciando runtime local do Arcanjo Dev…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: attempt) {
            guard model == nil else { return }
            do {
                let runtime = try LocalRuntimeFactory.make()
                model = try AppModel(runtime: runtime)
            } catch {
                startupError = error.localizedDescription
            }
        }
    }
}
