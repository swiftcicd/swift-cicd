public struct ShellStep: Step {
    public let name = "Shell"

    let command: String
    let arguments: [Argument]

    public init(command: String, arguments: [Argument]) {
        self.command = command
        self.arguments = arguments
    }

    public func run() async throws -> String {
        try context.shell(command, arguments)
    }
}

public extension Step where Self == ShellStep {
    static func shell(_ command: String, _ arguments: Argument...) -> ShellStep {
        ShellStep(command: command, arguments: arguments)
    }
}
