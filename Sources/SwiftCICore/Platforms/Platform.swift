import Foundation

let supportedPlatforms: [any Platform.Type] = [
    GitHubPlatform.self
]

func detectPlatform() throws -> Platform.Type {
    guard let platform = supportedPlatforms.first(where: { $0.detect() }) else {
        throw ActionError("Failed to detect platform")
    }

    return platform
}

/// A CI platform.
public protocol Platform: ContextAware {
    static var name: String { get }

    /// Whether the platform has detected that SwiftCI is running as part of its CI workflow.
    static var isRunningCI: Bool { get }

    /// An absolute path to the workspace on the CI platform's machine.
    static var workspace: String { get throws }

    /// Whether the platform supports grouping log messages together.
    static var supportsLogGroups: Bool { get }

    /// If the platform supports log groups, call this method to start a new log group.
    static func startLogGroup(named groupName: String)

    /// If the platform supports log groups, call this method to end an existing log group.
    static func endLogGroup(named groupName: String)

    /// Returns whether this platform is detected as the current platform or not.
    static func detect() -> Bool
}

extension ContextValues {
    enum PlatformKey: ContextKey {
        // TODO: Should the default be a "LocalPlatform"?
        static var defaultValue: Platform.Type = UndetectedPlatform.self
    }

    var platform: Platform.Type {
        get { self[PlatformKey.self] }
        set { self[PlatformKey.self] = newValue }
    }
}

struct UndetectedPlatform: Platform {
    static let name = "Undetected"
    static let isRunningCI = false
    static var workspace: String {
        get throws {
            struct UndetectedPlatformWorkspaceError: Error {}
            throw UndetectedPlatformWorkspaceError()
        }
    }
    static let supportsLogGroups = false
    static func startLogGroup(named groupName: String) {}
    static func endLogGroup(named groupName: String) {}
    static func detect() -> Bool { false }
}
