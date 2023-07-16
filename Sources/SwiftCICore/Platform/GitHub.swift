import SwiftEnvironment

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

    // https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#grouping-log-lines
    public static let supportsLogGroups = true

    public static let supportsNestedLogGroups = false

    public static let supportsSecretObfuscation = true

    public static func startLogGroup(named groupName: String) {
        guard isRunningCI else { return }
        print("::group::\(groupName)")
    }

    public static func endLogGroup() {
        guard isRunningCI else { return }
        print("::endgroup::")
    }

    public static func detect() -> Bool {
        context.environment.github.actions ?? false
    }

    public static func obfuscate(secret: String) {
        // https://github.com/1Password/load-secrets-action/blob/d1a4e73495bde3551cf63f6c048588b8f734e21d/entrypoint.sh#L101
        // Register a mask for the secret to prevent accidental log exposure.
        // To support multiline secrets, escape percent signs and add a mask per line.
        let escapedSecret = secret.replacingOccurrences(of: "%", with: "%25")
        for line in escapedSecret.components(separatedBy: "\n") {
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
