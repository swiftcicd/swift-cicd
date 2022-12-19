public struct SwiftStep: Step {
    public let name = "Swift"

    let arguments: [Argument]
    let xcbeautify: Bool

    public init(arguments: [Argument], xcbeautify: Bool = false) {
        self.arguments = arguments
        self.xcbeautify = xcbeautify
    }

    public func run() async throws -> String {
        let swiftRun = Command("swift", arguments)
        if xcbeautify {
            return try await xcbeautify(swiftRun)
        } else {
            return try context.shell(swiftRun)
        }
    }
}

public extension StepRunner {
    func swift(_ arguments: Argument..., xcbeautify: Bool = false) async throws -> String {
        try await step(SwiftStep(arguments: arguments, xcbeautify: xcbeautify))
    }

    func swift(_ arguments: [Argument], xcbeautify: Bool = false) async throws -> String {
        try await step(SwiftStep(arguments: arguments, xcbeautify: xcbeautify))
    }
}
