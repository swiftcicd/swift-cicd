public struct PipeCommand: CommandStep {
    public var name: String { left.name }

    let left: any CommandStep
    let right: any CommandStep

    public var command: Command {
        Command("\(left.command.command) | \(right.command.command)")
    }

    public init(left: any CommandStep, right: any CommandStep) {
        self.left = left
        self.right = right
    }
}

extension Step where Self: CommandConvertible {
    public func piped(into receivingCommand: any CommandStep) -> some CommandStep {
        PipeCommand(left: self, right: receivingCommand)
    }
}

public struct XCPretty: CommandStep {
    public let name = "XCPretty"

    public var command: Command {
        "xcpretty && exit ${PIPESTATUS[0]}"
    }

    public init() {}
}

public extension Step where Self == XCPretty {
    static var xcpretty: Self { Self() }
}
