import ShellOut

public struct Shell {
    @Context(\.files) var files
    @Context(\.logger) var logger

    @discardableResult
    public func callAsFunction(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) throws -> String {
        // Always log trace level
        if logger.logLevel == .trace {
            logger.debug("$ \(command) (at: \(files.currentDirectoryPath)")
        } else if log {
            logger.debug("$ \(command)")
        }

        let output = try shellOut(to: command.command, at: files.currentDirectoryPath)

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
