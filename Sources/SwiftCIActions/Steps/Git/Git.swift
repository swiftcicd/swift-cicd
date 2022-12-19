public struct Git: Step {
    public let name = "git"

    let arguments: [Argument]

    public init(_ arguments: [Argument]) {
        self.arguments = arguments
    }

    public func run() async throws -> String {
        try context.shell("git", arguments)
    }
}

public extension Step where Self == Git {
    static func git(_ arguments: Argument...) -> Git {
        Git(arguments)
    }
}

public extension StepRunner {
    @discardableResult
    func git(_ arguments: Argument...) async throws -> String {
        try await step(Git(arguments))
    }
}
