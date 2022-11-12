public struct XcodeBuild: CommandStep {
    public let name = "Xcode Build"

    let arguments: [CommandArgument]

    public var command: Command {
        Command(command: "xcodebuild", arguments: arguments)
    }

    public init(arguments: [CommandArgument]) {
        self.arguments = arguments
    }
}

public extension Step where Self == XcodeBuild {
    static func xcodebuild(_ arguments: CommandArgument...) -> XcodeBuild {
        XcodeBuild(arguments: arguments)
    }
}
