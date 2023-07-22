import SwiftCICore

public struct GitPush: Action {
    public func run() async throws -> String {
        let push = ShellCommand("git push")
        return try await shell(push)
    }
}

public extension Action {
    @discardableResult
    func push() async throws -> String {
        try await action(GitPush())
    }
}
