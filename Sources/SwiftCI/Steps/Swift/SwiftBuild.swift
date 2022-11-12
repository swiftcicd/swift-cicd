extension SwiftStep {
    public struct Build: Step {
        public let name = "Swift: Build"

        let arguments: [Argument]

        public init(arguments: [Argument]) {
            self.arguments = arguments
        }

        public func run() async throws -> String {
            try context.shell("swift", ["build"] + arguments)
        }
    }
}

public extension Step where Self == SwiftStep.Build {
    static func swift(build arguments: Argument...) -> SwiftStep.Build {
        SwiftStep.Build(arguments: arguments)
    }
}
