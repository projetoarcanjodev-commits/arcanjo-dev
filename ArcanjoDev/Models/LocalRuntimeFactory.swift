import Foundation

/// Seleciona o provider local padrão. A factory não injeta respostas nem faz fallback remoto.
public enum LocalRuntimeFactory {
    public static func make() throws -> any LocalModelProvider {
        MLXLocalModelProvider()
    }
}
