struct ArgumentParser {
    enum ArgumentError: Error {
        case missingArgument
        case invalidArgument(value: String, expectedType: any ExpressibleByArgument.Type)
        case missingOption(name: String)
        case invalidOption(name: String, value: String, expectedType: any ExpressibleByArgument.Type)
    }

    var arguments: [String]

    init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    mutating func consumeArgument() throws -> String {
        guard !arguments.isEmpty else {
            throw ArgumentError.missingArgument
        }

        return arguments.removeFirst()
    }

    mutating func consumeOption(named name: String) throws -> String {
        guard let nameIndex = arguments.firstIndex(of: name) else {
            throw ArgumentError.missingOption(name: name)
        }

        let valueIndex = arguments.index(after: nameIndex)
        guard valueIndex < arguments.endIndex else {
            throw ArgumentError.missingOption(name: name)
        }

        let option = arguments[valueIndex]
        arguments.removeSubrange(nameIndex...valueIndex)
        return option
    }

    mutating func consumeFlag(named name: String) -> Bool {
        guard let flagIndex = arguments.firstIndex(of: name) else {
            return false
        }

        arguments.remove(at: flagIndex)
        return true
    }
}

protocol ExpressibleByArgument {
    init?(argument: String)
}

extension ArgumentParser {
    mutating func consumeOption<Option: ExpressibleByArgument>(named name: String, as type: Option.Type = Option.self) throws -> Option {
        let rawOption = try consumeOption(named: name)
        guard let option = Option(argument: rawOption) else {
            throw ArgumentError.invalidOption(name: name, value: rawOption, expectedType: Option.self)
        }
        return option
    }

    mutating func consumeArgument<Argument: ExpressibleByArgument>(as type: Argument.Type = Argument.self) throws -> Argument {
        let rawArgument = try consumeArgument()
        guard let argument = Argument(argument: rawArgument) else {
            throw ArgumentError.invalidArgument(value: rawArgument, expectedType: Argument.self)
        }
        return argument
    }
}
