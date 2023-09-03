public struct Brew: Tool {
    public static let name = "brew"

    public static func install() async throws {
        // FIXME: This will fail because the install script requires sudo or a password.
        try await context.shell(#"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#)
        // TODO: Run the "Next Steps" commands
        // We can either parse the output of install script and look for that section and the exact commands to run
        // or we can run whoami and get the name of the user and then use that username and hardcode the follow Next Step commands.
        // :
        // (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/clayellis/.zprofile
        // eval "$(/opt/homebrew/bin/brew shellenv)"
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
