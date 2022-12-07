extension SwiftStep {
    public struct Run: Step {
        public let name = "Swift: Run"

        let arguments: [Argument]
        let xcbeautify: Bool

        public init(arguments: [Argument], xcbeautify: Bool = false) {
            self.arguments = arguments
            self.xcbeautify = xcbeautify
        }

        public func run() async throws -> String {
            try await swift(["run"] + arguments, xcbeautify: xcbeautify)
        }
    }
}

public extension Step where Self == SwiftStep.Run {
    static func swift(run arguments: Argument..., xcbeautify: Bool = false) -> SwiftStep.Run {
        SwiftStep.Run(arguments: arguments, xcbeautify: xcbeautify)
    }

    static var swiftRun: SwiftStep.Run {
        SwiftStep.Run(arguments: [])
    }
}
