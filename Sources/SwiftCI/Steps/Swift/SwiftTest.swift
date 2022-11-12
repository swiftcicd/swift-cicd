extension SwiftStep {
    public struct Test: Step {
        public let name = "Swift: Test"

        let arguments: [Argument]

        public init(arguments: [Argument]) {
            self.arguments = arguments
        }

        public func run() async throws -> String {
            try context.shell("swift", ["test"] + arguments)
        }
    }
}

public extension Step where Self == SwiftStep.Test {
    static func swift(test arguments: Argument...) -> SwiftStep.Test {
        SwiftStep.Test(arguments: arguments)
    }
}
