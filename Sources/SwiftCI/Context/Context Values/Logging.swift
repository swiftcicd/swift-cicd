import Logging

enum LoggerKey: ContextKey {
    // TODO: Can the default log handler be configured to remove its verbose prefix?
    static let defaultValue: Logger = Logger(label: "swift-ci")
}

public extension ContextValues {
    var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

// Logging is so essential to workflows and steps, we'll make the
// logger available without reaching through the context.

public extension Workflow {
    static var logger: Logger { context.logger }
    var logger: Logger { context.logger }
}

public extension Step {
    var logger: Logger { context.logger }
}
