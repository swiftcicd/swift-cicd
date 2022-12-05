public struct Push: Step {
    public let name = "git push"

    public func run() async throws -> String {
        let push = Command("git", "push")
        return try context.shell(push)
    }
}

public extension StepRunner {
    func push() async throws {
        try await step(Push())
    }
}
