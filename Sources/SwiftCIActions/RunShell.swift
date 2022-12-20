import SwiftCICore

// TODO: Rename this to "Run"?

public struct RunShell: Action {
    public let name = "Shell"

    let command: ShellCommand

    public init(command: ShellCommand) {
        self.command = command
    }

    public func run() async throws -> String {
        try context.shell(command)
    }
}

public extension Action {
    func shell(_ command: ShellCommand) async throws -> String {
        try await action(RunShell(command: command))
    }
}
