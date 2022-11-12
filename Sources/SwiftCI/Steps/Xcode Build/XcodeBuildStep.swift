public struct XcodeBuildStep: Step {
    public let name = "Xcode Build"

    let arguments: [Argument]

    public init(arguments: [Argument]) {
        self.arguments = arguments
    }

    public func run() async throws -> String {
        try context.shell("xcodebuild", arguments)
    }
}

public extension Step where Self == XcodeBuildStep {
    static func xcodebuild(_ arguments: Argument...) -> XcodeBuildStep {
        XcodeBuildStep(arguments: arguments)
    }
}
