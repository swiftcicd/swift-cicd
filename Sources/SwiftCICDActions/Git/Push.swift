import SwiftCICDCore

extension Git {
    public struct Push: Action {
        public init() {}

        public func run() async throws {
            let push = ShellCommand("git push")
            try await shell(push)
        }
    }
}

public extension Git {
    func push() async throws {
        try await run(Push())
    }
}
