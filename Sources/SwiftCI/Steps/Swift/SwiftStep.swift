public struct SwiftStep: Step {
    public let name = "Swift"

    let arguments: [Argument]

    public init(arguments: [Argument]) {
        self.arguments = arguments
    }

    public func run() async throws -> String {
        try context.shell("swift", arguments)
    }
}

public extension Step where Self == SwiftStep {
    static func swift(_ arguments: Argument...) -> SwiftStep {
        SwiftStep(arguments: arguments)
    }
}
