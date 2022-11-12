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
