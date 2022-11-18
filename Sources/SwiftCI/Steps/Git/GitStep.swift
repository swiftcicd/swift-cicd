public struct GitStep: Step {
    public let name = "git"

    let arguments: [Argument]

    public init(arguments: [Argument]) {
        self.arguments = arguments
    }

    public func run() async throws -> String {
        try context.shell("git", arguments)
    }
}

public extension Step where Self == GitStep {
    static func git(_ arguments: Argument...) -> GitStep {
        GitStep(arguments: arguments)
    }
}
