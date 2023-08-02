import SwiftCICDCore

/// Namespace for Git actions.
public struct Git: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var git: Git { Git(caller: self) }
}

public extension Git {
    var latestCommitSHA: String? {
        get async throws {
            try await context.shell("git rev-parse HEAD")
        }
    }
}
