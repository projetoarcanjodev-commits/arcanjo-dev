import Foundation

public struct AgentProfile: Sendable, Identifiable {
    public let role: AgentRole
    public let allowedTools: Set<String>
    public var id: String { role.rawValue }
}

public enum AgentCatalog {
    private static let readTools: Set<String> = ["workspace.list", "workspace.read", "workspace.validate", "web.fetch"]
    private static let editTools: Set<String> = ["workspace.list", "workspace.read", "workspace.write", "web.fetch"]

    public static func profile(for role: AgentRole) -> AgentProfile {
        let tools: Set<String>
        switch role {
        case .researcher: tools = ["web.fetch", "workspace.read", "workspace.write"]
        case .programmer: tools = editTools.union(["workspace.delete"])
        case .web: tools = editTools
        case .designer: tools = ["workspace.list", "workspace.read", "workspace.write"]
        case .tester: tools = readTools
        case .reviewer: tools = readTools
        case .devops: tools = editTools.union(["workspace.delete"])
        case .integrations: tools = ["workspace.list", "workspace.read", "workspace.write", "web.fetch"]
        case .memory: tools = ["workspace.list", "workspace.read"]
        case .security: tools = readTools
        }
        return AgentProfile(role: role, allowedTools: tools)
    }
}
