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

    /// Whether the platform supports obfuscating secrets.
    static var supportsSecretObfuscation: Bool { get }

    /// If the platform supports secret obfuscation (see: ``supportsSecretObfuscation``),
    /// the `secret` should be obfuscated when logging via the built-in `logger`.
    /// - Parameter secret: The secret to obfuscate.
    static func obfuscate(secret: String)
}

// TODO: In order to remove the need for hard-coding supportedPlatforms we could just add a 'static platform: Platform?' property to MainAction.
// Then a user could specify up-front what platform they intend to run on and implement the Platform protocol themselves.
// Then in the MainAction.run we could guard detect the platform they specified, if they specified one.
// Otherwise, we'll just check for the platforms we know about (Local and GitHub)

private let supportedPlatforms: [any Platform.Type] = [
    LocalPlatform.self,
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
