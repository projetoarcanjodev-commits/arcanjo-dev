import SwiftUI

public struct ApprovalRequest: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String
}

@MainActor
public final class ApprovalCenter: ObservableObject, @unchecked Sendable {
    @Published public private(set) var pending: ApprovalRequest?
    private var continuation: CheckedContinuation<Bool, Never>?

    public init() {}

    public func request(title: String, detail: String) async -> Bool {
        await withCheckedContinuation { continuation in
            // O executor serializa chamadas de tools; rejeitar solicitação concorrente evita sobrescrever um prompt pendente.
            guard self.continuation == nil else { continuation.resume(returning: false); return }
            self.pending = ApprovalRequest(id: UUID(), title: title, detail: detail)
            self.continuation = continuation
        }
    }

    public func resolve(approved: Bool) {
        let current = continuation
        continuation = nil
        pending = nil
        current?.resume(returning: approved)
    }
}
