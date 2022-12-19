extension SwiftStep {
    public struct Test: Step {
        public let name = "Swift: Test"

        let arguments: [Argument]
        let xcbeautify: Bool

        public init(arguments: [Argument], xcbeautify: Bool = false) {
            self.arguments = arguments
            self.xcbeautify = xcbeautify
        }

        public func run() async throws -> String {
            try await swift(["test"] + arguments, xcbeautify: xcbeautify)
        }
    }
}

public extension Step where Self == SwiftStep.Test {
    static func swift(test arguments: Argument..., xcbeautify: Bool = false) -> SwiftStep.Test {
        SwiftStep.Test(arguments: arguments, xcbeautify: xcbeautify)
    }

    static var swiftTest: SwiftStep.Test {
        SwiftStep.Test(arguments: [])
    }
}
