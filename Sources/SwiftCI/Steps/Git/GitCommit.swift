extension GitStep {
    public struct Commit: Step {
        public let name = "Git Commit"

        let message: String
        let flags: [String]

        public init(message: String, flags: [String]) {
            self.message = message
            self.flags = flags.filter { $0 != "m" }
        }

        // TODO: Output should be a list of changes, and a flag "changes detected?"

        public func run() async throws -> String {
            try context.shell("git", "commit", "-\(flags.joined())", "-m", message)
        }
    }
}

public extension Step where Self == GitStep.Commit {
    static func commit(message: String, flags: [String] = []) -> GitStep.Commit {
        GitStep.Commit(message: message, flags: flags)
    }

    static func commitTrackedChanges(message: String, flags: [String] = []) -> GitStep.Commit {
        GitStep.Commit(message: message, flags: ["a"] + flags)
    }

    static func commitAllChanges(message: String, flags: [String] = []) -> GitStep.Commit {
        GitStep.Commit(message: message, flags: ["A"] + flags)
    }
}
