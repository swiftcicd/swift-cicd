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

public extension ContextValues {
    func startLogGroup(name: String) {
        _ = try? shell("echo \"::group::\(name)\"", log: false)
    }

    func endLogGroup() {
        _ = try? shell("echo \"::endgroup::\"", log: false)
    }

    @discardableResult
    func performInLogGroup<Result>(named name: String, operation: () throws -> Result) rethrows -> Result {
        startLogGroup(name: name)
        defer { endLogGroup() }
        return try operation()
    }

    @discardableResult
    func performInLogGroup<Result>(named name: String, operation: () async throws -> Result) async rethrows -> Result {
        startLogGroup(name: name)
        defer { endLogGroup() }
        return try await operation()
    }
}

public extension String {
    func embeddedInLogGroup(named name: String) -> String {
        """
        ::group::\(name)
        \(self)
        ::endgroup::
        """
    }
}
