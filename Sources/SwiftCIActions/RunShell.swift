import SwiftCICore

// TODO: Rename this to "Run"?

public struct RunShell: Action {
    public let name = "Shell"

    let command: ShellCommand
    let log: Bool
    let quiet: Bool

    public init(command: ShellCommand, log: Bool, quiet: Bool) {
        self.command = command
        self.log = log
        self.quiet = quiet
    }

    public func run() async throws -> String {
        try context.shell(command, log: log, quiet: quiet)
    }
}

public extension Action {
    @discardableResult
    func shell(_ command: ShellCommand, log: Bool = true, quiet: Bool = false) async throws -> String {
        try await action(RunShell(command: command, log: log, quiet: quiet))
    }
}
