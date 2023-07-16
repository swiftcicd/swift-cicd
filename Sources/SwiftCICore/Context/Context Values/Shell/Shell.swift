import Foundation
import ShellOut

public struct Shell {
    @Context(\.fileManager) var fileManager
    @Context(\.logger) var logger

    @_disfavoredOverload
    @discardableResult
    public func callAsFunction(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) throws -> Data {
        let currentDirectory = fileManager.currentDirectoryPath
        // Always log trace level
        if logger.logLevel == .trace {
            logger.debug("$ \(command) (at: \(currentDirectory)")
        } else if log {
            logger.debug("$ \(command)")
        }

        return try shellOut(to: command.command, at: currentDirectory)
    }

    @discardableResult
    public func callAsFunction(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) throws -> String {
        let output: Data = try callAsFunction(command, log: log, quiet: quiet)
        let stringOutput = String(decoding: output, as: UTF8.self)

        // TODO: Make output destination customizable via handles
        if !quiet {
            print(stringOutput)
        }

        return stringOutput
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
