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
