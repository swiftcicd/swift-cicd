public protocol Option {
    var name: String { get }
    var argument: Argument { get }
}

public protocol Argument {
    var argument: String { get }
}

extension String: Argument {
    public var argument: String { self }
}

extension Argument {
    var escaped: String {
        // TODO: If the argument has newlines in it, should we esacpe the lines?

        if argument.contains(" ") && !(argument.hasPrefix("'") && argument.hasSuffix("'")) {
            return "'\(argument)'"
        } else {
            return argument
        }
    }
}
