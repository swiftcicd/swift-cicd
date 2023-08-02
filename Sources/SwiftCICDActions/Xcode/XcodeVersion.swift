import SwiftCICDCore

// https://github.com/xcpretty/xcode-install

struct XcodeVersion: Action {
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

    func run() async throws {
        try await shell("xcversion \(command.command)")
    }
}

extension Xcode {
    public func select(_ version: String) async throws {
        try await run(XcodeVersion(command: .select(version: version)))
    }
}
