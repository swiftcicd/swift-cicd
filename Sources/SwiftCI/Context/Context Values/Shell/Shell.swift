import ShellOut

public struct Shell {
    @Context(\.fileManager) var fileManager
    @Context(\.logger) var logger

    @discardableResult
    func callAsFunction(_ command: String, _ arguments: [Argument], log: Bool = true, quiet: Bool = false) throws -> String {
        let commandArgumentsDescription = "\(command) \(arguments.map(\.escaped).joined(separator: " "))"

        // Always log trace level
        if logger.logLevel == .trace {
            logger.debug("Shell (at: \(fileManager.currentDirectoryPath)): \(commandArgumentsDescription)")
        } else if log {
            logger.debug("Shell: \(commandArgumentsDescription)")
        }

        let output = try shellOut(to: command, arguments: arguments.map(\.escaped), at: fileManager.currentDirectoryPath)

        // TODO: We're just going to print the output for now, but eventually it should be streamed out as it comes in and made available for formatting
        if !quiet {
            print(output)
        }

        return output
    }

    @discardableResult
    func callAsFunction(_ command: String, _ arguments: Argument..., log: Bool = true, quiet: Bool = false) throws -> String {
        try callAsFunction(command, arguments, log: log, quiet: quiet)
    }

    @discardableResult
    func callAsFunction(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) throws -> String {
        try callAsFunction(command.command, command.arguments, log: log, quiet: quiet)
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

protocol ShellCommand {
    var command: String { get }
    var arguments: [Argument] { get }
}

public struct Command: ShellCommand, CustomStringConvertible {
    public let command: String
    public var arguments: [Argument]

    public var description: String {
        "\(command) \(arguments.map(\.escaped).joined(separator: " "))"
    }

    public init(_ command: String, _ arguments: [Argument] = []) {
        self.command = command
        self.arguments = arguments
    }

    public init(_ command: String, _ arguments: Argument...) {
        self.init(command, arguments)
    }

    public mutating func add(_ arguments: Argument...) {
        self.arguments.append(contentsOf: arguments)
    }

    public mutating func add(_ option: String? = nil, ifLet argument: Argument?) {
        if let argument {
            if let option {
                self.add(option, argument)
            } else {
                self.add(argument)
            }
        }
    }

    public static func += (lhs: inout Command, rhs: Argument) {
        lhs.add(rhs)
    }

    @_disfavoredOverload
    public static func += (lhs: inout Command, rhs: Argument) -> Command {
        lhs.add(rhs)
        return lhs
    }
}
