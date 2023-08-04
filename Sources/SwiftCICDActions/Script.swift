import SwiftCICDCore

public struct Script: Action {
    let command: ShellCommand

    public init(_ command: ShellCommand) {
        self.command = command
    }

    public func run() async throws -> String {
        try await shell(command)
    }
}
