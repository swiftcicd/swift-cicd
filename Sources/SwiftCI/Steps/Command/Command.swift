import ShellOut

public struct Command: Step {
    public let name = "Command"

    public let command: String

    public init(command: String, arguments: [CommandArgument]) {
        self.command = ([command] + arguments.map(\.singleQuotedIfNeeded)).joined(separator: " ")
    }

    public init(_ raw: String) {
        command = raw
    }

    public func run() async throws -> String {
        // TODO: Don't use shellOut (it's really old and hasn't been maintained)
        try shellOut(to: command)
    }
}

extension Command: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public extension Step where Self == Command {
    static func command(_ command: String, _ arguments: CommandArgument...) -> Command {
        Command(command: command, arguments: arguments)
    }

    static func command(_ raw: String) -> Command {
        Command(raw)
    }

    static func command(_ command: CommandConvertible) -> Command {
        command.command
    }
}

public protocol CommandConvertible {
    var command: Command { get }
}

public typealias CommandStep = Step & CommandConvertible

public extension Step where Self: CommandConvertible {
    func run() async throws -> String {
        try await command.run()
    }
}

public protocol CommandArgument {
    var argument: String { get }
}

extension String: CommandArgument {
    public var argument: String { self }
}

extension CommandArgument {
    var singleQuotedIfNeeded: String {
        if argument.contains(" ") {
            return "'\(argument)'"
        } else {
            return argument
        }
    }
}

//public protocol CommandConvertible {
//    var shell: String { get }
//    var command: String { get }
//    var arguments: [String] { get }
//}
//
//public extension CommandConvertible {
//    var shell: String { "/bin/zsh" }
//}
