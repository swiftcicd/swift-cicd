import SwiftEnvironment

// TODO: Explore using these GitHub commands to highlight certain lines in the action output
// https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-a-notice-message

public enum GitHubPlatform: Platform {
    public static let name = "GitHub Actions"

    public static var isRunningCI: Bool {
        context.environment.github.isCI
    }

    public static var workingDirectory: String {
        get throws {
            try context.environment.github.$workspace.require()
        }
    }

    public static func detect() -> Bool {
        context.environment.github.actions ?? false
    }

    // https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#grouping-log-lines
    public static func startLogGroup(named groupName: String) {
        // GitHub doesn't support nested log groups.
        // So always eageraly end a group before starting a new one.
        endLogGroup()
        print("::group::\(groupName)")
    }

    public static func endLogGroup() {
        print("::endgroup::")
    }

    // https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#masking-a-value-in-a-log
    public static func obfuscate(secret: String) {
        // Reference:
        // https://github.com/1Password/load-secrets-action/blob/d1a4e73495bde3551cf63f6c048588b8f734e21d/entrypoint.sh#L101
        // Register a mask for the secret to prevent accidental log exposure.
        // To support multiline secrets, escape percent signs and add a mask per line.
        for line in secret.components(separatedBy: "\n") {
            if line.count < 3 {
                // To avoid false positives and unreadable logs, omit mask for lines that are too short.
                continue
            }
            print("::add-mask::\(line)")
        }
    }
}

public extension Platform {
    static var isGitHub: Bool {
        if let _ = self as? GitHubPlatform.Type {
            return true
        } else {
            return false
        }
    }
}
