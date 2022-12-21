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

public struct LogGroup: Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

extension ContextValues {
    enum LogGroupKey: ContextKey {
        static var defaultValue: LogGroup?
    }

    public var currentLogGroup: LogGroup? {
        get { self[LogGroupKey.self] }
        set { self[LogGroupKey.self] = newValue }
    }
}

extension ContextValues {

    /// Starts on a new log group on the current platform.
    ///
    /// This will always eagerly call ``Platform/endLogGroup()`` before calling ``Platform/startLogGroup(named:)``.
    /// If finer control is needed, call ``Platform/startLogGroup(named:)`` directly.
    /// - Note: This has _no effect_ on ``ContextValues/currentLogGroup``.
    /// - Parameter name: The name of the log group.
    func startLogGroup(named name: String) throws {
        let platform = try self.platform
        guard platform.supportsLogGroups else { return }
        platform.endLogGroup()
        platform.startLogGroup(named: name)
    }

    /// Ends the log group on the current platform.
    /// - Note:
    ///     - This has _no effect_ on ``ContextValues/currentLogGroup``.
    func endLogGroup() throws {
        let platform = try self.platform
        guard platform.supportsLogGroups else { return }
        platform.endLogGroup()
    }

    
    /// Starts a new log group with the given name and sets the ``ContextValues/currentLogGroup`` for the duration of the operation.
    ///
    /// The log group _will not_ be ended at the end of the operation. Log groups are automatically balanced by only ending a group when a new one is started.
    /// If finer control is needed, either call ``ContextValues/endLogGroup()`` or ``Platform/endLogGroup()`` directly.
    /// - Parameters:
    ///   - name: The name of the log group.
    ///   - operation: The operation to run.
    /// - Returns: The result of the operation.
    @discardableResult
    public func withLogGroup<Result>(named name: String, operation: () throws -> Result) throws -> Result {
        try Self.withValue(\.currentLogGroup, LogGroup(name: name)) {
            try startLogGroup(named: name)
            return try operation()
        }
    }

    /// Starts a new log group with the given name and sets the ``ContextValues/currentLogGroup`` for the duration of the operation.
    ///
    /// The log group _will not_ be ended at the end of the operation. Log groups are automatically balanced by only ending a group when a new one is started.
    /// If finer control is needed, either call ``ContextValues/endLogGroup()`` or ``Platform/endLogGroup()`` directly.
    /// - Parameters:
    ///   - name: The name of the log group.
    ///   - operation: The operation to run.
    /// - Returns: The result of the operation.
    @discardableResult
    public func withLogGroup<Result>(named name: String, operation: () async throws -> Result) async throws -> Result {
        try await Self.withValue(\.currentLogGroup, LogGroup(name: name)) {
            try startLogGroup(named: name)
            return try await operation()
        }
    }
}
