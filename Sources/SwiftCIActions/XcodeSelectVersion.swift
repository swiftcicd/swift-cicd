import SwiftCICore

public struct XcodeVersion: Action {
    enum Command {
        case select(version: String)

        var command: ShellCommand {
            switch self {
            case .select(let version):
                return "select \(version)"
            }
        }
    }

    let command: Command

    public func run() async throws {
        try context.shell("xcversion \(command.command)")
    }
}

extension Action {
    public func selectXcodeVersion(_ version: String) async throws {
        try await action(XcodeVersion(command: .select(version: version)))
    }
}
