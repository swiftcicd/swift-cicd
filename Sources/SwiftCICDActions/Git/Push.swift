import SwiftCICDCore

struct GitPush: Action {
    func run() async throws -> String {
        let push = ShellCommand("git push")
        return try await shell(push)
    }
}

public extension Git {
    @discardableResult
    func push() async throws -> String {
        try await run(GitPush())
    }
}
