import ShellOut

public struct Shell {
    @Context(\.fileManager) var fileManager
    @Context(\.logger) var logger

    @discardableResult
    public func callAsFunction(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) throws -> String {
        let currentDirectory = fileManager.currentDirectoryPath
        // Always log trace level
        if logger.logLevel == .trace {
            logger.debug("$ \(command) (at: \(currentDirectory)")
        } else if log {
            logger.debug("$ \(command)")
        }

        let output = try shellOut(to: command.command, at: currentDirectory)

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
