extension SwiftStep {
    public struct Run: Step {
        public let name = "Swift: Run"

        let arguments: [Argument]

        public init(arguments: [Argument]) {
            self.arguments = arguments
        }

        public func run() async throws -> String {
            try context.shell("swift", ["run"] + arguments)
        }
    }
}

public extension Step where Self == SwiftStep.Run {
    static func swift(run arguments: Argument...) -> SwiftStep.Run {
        SwiftStep.Run(arguments: arguments)
    }
}
