extension SwiftStep {
    public struct Build: Step {
        public let name = "Swift: Build"

        let arguments: [Argument]
        let xcbeautify: Bool

        public init(arguments: [Argument], xcbeautify: Bool = false) {
            self.arguments = arguments
            self.xcbeautify = xcbeautify
        }

        public func run() async throws -> String {
            try await swift(["build"] + arguments, xcbeautify: xcbeautify)
        }
    }
}

public extension Step where Self == SwiftStep.Build {
    static func swift(build arguments: Argument..., xcbeautify: Bool = false) -> SwiftStep.Build {
        SwiftStep.Build(arguments: arguments, xcbeautify: xcbeautify)
    }

    static var swiftBuild: SwiftStep.Build {
        SwiftStep.Build(arguments: [])
    }
}
