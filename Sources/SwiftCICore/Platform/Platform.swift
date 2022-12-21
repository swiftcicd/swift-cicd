import Foundation

/// A CI platform.
public protocol Platform: ContextAware {
    static var name: String { get }

    /// Whether the platform has detected that SwiftCI is running as part of its CI workflow.
    static var isRunningCI: Bool { get }

    /// An absolute path to the working directory on the CI platform's machine.
    static var workingDirectory: String { get throws }

    /// Whether the platform supports grouping log messages together.
    static var supportsLogGroups: Bool { get }

    /// If the platform supports log groups, call this method to start a new log group.
    static func startLogGroup(named groupName: String)

    /// If the platform supports log groups, call this method to eagerly end a log group.
    static func endLogGroup()

    /// Returns whether this platform is detected as the current platform or not.
    static func detect() -> Bool
}

private let supportedPlatforms: [any Platform.Type] = [
    GitHubPlatform.self
]

private func detectPlatform() throws -> Platform.Type {
    guard let platform = supportedPlatforms.first(where: { $0.detect() }) else {
        throw ActionError("Failed to detect platform")
    }

    return platform
}

public extension ContextValues {
    var platform: Platform.Type {
        get throws { try detectPlatform() }
    }

    var workingDirectory: String {
        get throws { try platform.workingDirectory }
    }
}
