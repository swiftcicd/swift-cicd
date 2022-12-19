import ShellOut

public struct Shell {
    @Context(\.fileSystem) var fileSystem
    @Context(\.logger) var logger

    @discardableResult
    public func callAsFunction(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) throws -> String {
        // Always log trace level
        if logger.logLevel == .trace, let currentWorkingDirectory = fileSystem.currentWorkingDirectory {
            logger.debug("$ \(command) (at: \(currentWorkingDirectory.pathString)")
        } else if log {
            logger.debug("$ \(command)")
        }

        let output: String
        if let currentWorkingDirectory = fileSystem.currentWorkingDirectory {
            output = try shellOut(to: command.command, at: currentWorkingDirectory.pathString)
        } else {
            output = try shellOut(to: command.command)
        }

        // TODO: Make output destination customizable via handles
        if !quiet {
            print(output)
        }

        return output
    }
}

extension ContextValues {
    enum ShellKey: ContextKey {
        static var defaultValue = Shell()
    }

    public var shell: Shell {
        get { self[ShellKey.self] }
        set { self[ShellKey.self] = newValue }
    }
}
