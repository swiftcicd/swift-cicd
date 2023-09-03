public struct Brew: Tool {
    public static let name = "brew"

    public static func install() async throws {
        // FIXME: This will fail because the install script requires sudo or a password.
        try await context.shell(#"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#)
    }

    public static func uninstall() async throws {
        try await context.shell(#"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)""#)
    }

    public static func install(_ package: String) async throws {
        try await context.shell("brew install \(package)")
    }
}

public extension Tools {
    var brew: Brew.Type {
        get async throws {
            try await self[Brew.self]
        }
    }
}
