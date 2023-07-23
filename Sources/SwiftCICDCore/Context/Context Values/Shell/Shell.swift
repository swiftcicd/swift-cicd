import Foundation

public struct ShellError: Error, CustomStringConvertible {
    public let terminationStatus: Int32
    public let errorData: Data
    public let outputData: Data

    public var message: String {
        errorData.string
    }

    public var output: String {
        outputData.string
    }

    public var description: String {
        """
        Shell error
        Status code: \(terminationStatus)
        Message: "\(message)"
        Output: "\(output)"
        """
    }
}

public struct Shell {
    public static let `default` = Shell.zsh
    public static let zsh = "/bin/zsh"
    public static let bash = "/bin/bash"

    @Context(\.logger) var logger

    @_disfavoredOverload
    @discardableResult
    public func callAsFunction(
        _ command: ShellCommand,
        shell: String = Shell.default,
        log: Bool = true,
        quiet: Bool = false
    ) async throws -> Data {
        // Always log at trace level
        if log || logger.logLevel == .trace {
            logger.debug("$ \(command)")
        }

        let task = Process()
        task.executableURL = URL(filePathCompat: shell)
        task.arguments = ["--login", "-c", command.command]
        task.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        task.standardOutput = outputPipe

        let errorPipe = Pipe()
        task.standardError = errorPipe

        try task.run()

        let outputData = try outputPipe.drain()
        let errorData = try errorPipe.drain()

        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw ShellError(
                terminationStatus: task.terminationStatus,
                errorData: errorData,
                outputData: outputData
            )
        }

        return outputData
    }

    @discardableResult
    public func callAsFunction(
        _ command: ShellCommand,
        shell: String = Shell.default,
        log: Bool = true,
        quiet: Bool = false
    ) async throws -> String {
        let output: Data = try await callAsFunction(command, shell: shell, log: log, quiet: quiet)
        let stringOutput = String(decoding: output, as: UTF8.self)

        // TODO: Make output destination customizable via handles
        if !quiet {
            print(stringOutput)
        }

        return stringOutput
    }
}

private extension Pipe {
    func drain() throws -> Data {
        try fileHandleForReading.readToEnd()?.removingTrailingNewline ?? Data()
    }
}

private extension Data {
    var removingTrailingNewline: Data {
        guard let output = String(data: self, encoding: .utf8) else {
            return self
        }

        guard output.hasSuffix("\n") else {
            return self
        }

        let endIndex = output.index(before: output.endIndex)
        return Data(output[..<endIndex].utf8)
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

public extension Action {
    @_disfavoredOverload
    @discardableResult
    func shell(_ command: ShellCommand, shell: String = Shell.default, log: Bool = true, quiet: Bool = false) async throws -> Data {
        try await context.shell(command, log: log, quiet: quiet)
    }

    @discardableResult
    func shell(_ command: ShellCommand, shell: String = Shell.default, log: Bool = true, quiet: Bool = false) async throws -> String {
        try await context.shell(command, log: log, quiet: quiet)
    }
}
