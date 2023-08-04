import Foundation
import Logging

/// A CI platform.
public protocol Platform: ContextAware {
    static var name: String { get }

    /// Whether the platform has detected that SwiftCI is running as part of its CI workflow.
    static var isRunningCI: Bool { get }

    /// An absolute path to the working directory on the CI platform's machine.
    static var workingDirectory: String { get throws }

    /// A swift-log Logger.
    static var logger: Logger { get set }

    /// Returns whether this platform is detected as the current platform or not.
    static func detect() -> Bool

    /// If the platform supports log groups, call this method to start a new log group.
    static func startLogGroup(named groupName: String)

    /// If the platform supports log groups, call this method to eagerly end a log group.
    static func endLogGroup()

    /// If the platform supports secret obfuscation the `secret` should be obfuscated
    /// when logging via the built-in `logger`.
    ///
    /// - Parameter secret: The secret to obfuscate.
    static func obfuscate(secret: String)
}

private var defaultLogger = Logger(label: "swift-cicd")

public extension Platform {
    static var logger: Logger {
        get { defaultLogger }
        set { defaultLogger = newValue }
    }
}

public extension ContextValues {
    private enum PlatformKey: ContextKey {
        static var defaultValue: Platform.Type?
    }

    var platform: Platform.Type {
        get {
            guard let platform = self[PlatformKey.self] else {
                fatalError("Context value 'platform' was accessed before it had been set.")
            }

            return platform
        }

        set { self[PlatformKey.self] = newValue }
    }

    var workingDirectory: String {
        get throws { try platform.workingDirectory }
    }

    var logger: Logger {
        get { platform.logger }
        set { platform.logger = newValue }
    }
}
