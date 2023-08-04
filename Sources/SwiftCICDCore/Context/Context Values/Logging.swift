import Logging

// TODO: Make a PlatformLogger so that if a platform supports formatting log levels (like GitHub actions: https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-a-debug-message) then those can be formatted according to the platform.

public extension Action {
    static var logger: Logger { context.logger }
    var logger: Logger { context.logger }
}

extension ContextValues {
    enum LoggerKey: ContextKey {
        // TODO: Can the default log handler be configured to remove its verbose prefix?
        public static let defaultValue: Logger = Logger(label: "swift-cicd")
    }

    public var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}
