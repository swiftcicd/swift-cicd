import Logging

public extension Action {
    static var logger: Logger { context.logger }
    var logger: Logger { context.logger }
}

extension ContextValues {
    enum LoggerKey: ContextKey {
        // TODO: Can the default log handler be configured to remove its verbose prefix?
        public static let defaultValue: Logger = Logger(label: "swift-ci")
    }

    public var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

extension ContextValues {
    func startLogGroup(name: String) throws {
        let platform = try self.platform
        guard platform.supportsLogGroups else { return }
        platform.startLogGroup(named: name)
    }

    func endCurrentLogGroup() throws {
        let platform = try self.platform
        guard platform.supportsLogGroups else { return }
        platform.endCurrentLogGroup()
    }

    @discardableResult
    public func performInLogGroup<Result>(named name: String, operation: () throws -> Result) throws -> Result {
        try platform.startLogGroup(named: name)

        defer {
            try? platform.endCurrentLogGroup()
        }

        return try operation()
    }

    @discardableResult
    public func performInLogGroup<Result>(named name: String, operation: () async throws -> Result) async throws -> Result {
        try platform.startLogGroup(named: name)

        defer {
            try? platform.endCurrentLogGroup()
        }

        return try await operation()
    }
}
