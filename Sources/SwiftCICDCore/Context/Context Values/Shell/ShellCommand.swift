public struct ShellCommand: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    public private(set) var command: String

    public var description: String { command }

    internal init() {
        self.command = ""
    }

    public init(_ staticString: StaticString) {
        self.init(stringLiteral: staticString)
    }

    public init(_ component: Component) {
        self.command = component.value
    }

    public init(stringLiteral value: StaticString) {
        self.command = "\(value)"
    }

    public init(stringInterpolation: Component.StringInterpolation) {
        self.command = stringInterpolation.output
    }

    public mutating func append(_ component: Component) {
        command.append(" \(component.value)")
    }

    public mutating func append(_ component: Component?) {
        if let component {
            append(component)
        }
    }

    public mutating func append(_ component: Component, if flag: Bool) {
        if flag {
            append(component)
        }
    }

    public mutating func append(_ option: StaticString, _ separator: StaticString = " ", ifLet value: Component?) {
        if let value {
            command.append(" \(option)\(separator)\(value.value)")
        }
    }

    @_disfavoredOverload
    public mutating func append(_ option: StaticString, _ separator: StaticString = " ", ifLet value: String?) {
        if let value {
            append(option, separator, ifLet: "\(value)")
        }
    }
}

extension ShellCommand {
    public struct Component: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
        public struct StringInterpolation: StringInterpolationProtocol {
            var output = ""

            public init(literalCapacity: Int, interpolationCount: Int) {
                output.reserveCapacity(literalCapacity + interpolationCount * 2)
            }

            public mutating func appendLiteral(_ literal: StaticString) {
                output.append("\(literal)")
            }

            public mutating func appendInterpolation(_ command: ShellCommand) {
                output.append(command.command)
            }

            public mutating func appendInterpolation(unescaped: String) {
                output.append(unescaped)
            }

            public mutating func appendInterpolation(_ argument: String, escapingWith escapeStyle: ArgumentEscapeStyle = .singleQuotes) {
                guard argument.contains(" ") else {
                    output.append(argument)
                    return
                }

                output.append(escapeStyle.escape(argument: argument))
            }

            public mutating func appendInterpolation(_ arguments: [String], escapingWith escapeStyle: ArgumentEscapeStyle = .singleQuotes) {
                for argument in arguments {
                    appendInterpolation(argument, escapingWith: escapeStyle)
                }
            }
        }

        public let value: String

        public init(stringLiteral value: StaticString) {
            self.value = "\(value)"
        }

        public init(stringInterpolation: StringInterpolation) {
            self.value = stringInterpolation.output
        }
    }
}

public protocol ArgumentEscapeStyle {
    func escape(argument: String) -> String
}

// TODO: Check if the argument is already escaped before esacping it.

public struct SingleQuoteArgumentEscapeStyle: ArgumentEscapeStyle {
    public func escape(argument: String) -> String {
        "'\(argument)'"
    }
}

public extension ArgumentEscapeStyle where Self == SingleQuoteArgumentEscapeStyle {
    static var singleQuotes: Self { Self() }
}

public struct DoubleQuoteArgumentEscapeStyle: ArgumentEscapeStyle {
    public func escape(argument: String) -> String {
        "\"\(argument)\""
    }
}

public extension ArgumentEscapeStyle where Self == DoubleQuoteArgumentEscapeStyle {
    static var doubleQuotes: Self { Self() }
}

public struct DollarSingleQuoteArgumentEscapeStyle: ArgumentEscapeStyle {
    public func escape(argument: String) -> String {
        "$'\(argument)'"
    }
}

public extension ArgumentEscapeStyle where Self == DollarSingleQuoteArgumentEscapeStyle {
    static var dollarSingleQuotes: Self { Self() }
}

public struct BackslashArgumentEscapeStyle: ArgumentEscapeStyle {
    public func escape(argument: String) -> String {
        argument.replacingOccurrences(of: " ", with: "\\ ")
    }
}

public extension ArgumentEscapeStyle where Self == BackslashArgumentEscapeStyle {
    static var backslashes: Self { Self() }
}
