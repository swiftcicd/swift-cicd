import ShellOut

public protocol Argument {
    var argument: String { get }
}

extension String: Argument {
    public var argument: String { self }
}

extension Argument {
    var escapedArgument: String {
        // TODO: If the argument has newlines in it, should we esacpe the lines?

        if argument.contains(" ") {
            return "'\(argument)'"
        } else {
            return argument
        }
    }
}

public struct Shell {
    @discardableResult
    func callAsFunction(_ command: String, _ arguments: [Argument]) throws -> String {
        try shellOut(to: command, arguments: arguments.map(\.escapedArgument))
    }

    @discardableResult
    func callAsFunction(_ command: String, _ arguments: Argument...) throws -> String {
        try callAsFunction(command, arguments)
    }
}

extension Shell: ContextKey {
    public static var defaultValue: Shell { Shell() }
}

public extension ContextValues {
    var shell: Shell {
        get { self[Shell.self] }
        set { self[Shell.self] = newValue }
    }
}
