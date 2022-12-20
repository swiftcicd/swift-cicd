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

public struct LogGroup {
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

//    func startLogGroup(name: String) {
//        guard platform.supportsLogGroups else { return }
//        currentLogGroup = LogGroup(name: name)
//        platform.startLogGroup(named: name)
//    }
//
//    func endLogGroup() {
//        guard platform.supportsLogGroups, let currentLogGroup else { return }
//        self.currentLogGroup = nil
//        platform.endLogGroup(named: currentLogGroup.name)
//    }

    public enum PerformInLogGroupOption {
        case endCurrentLogGroup
        case keepCurrentLogGroup
    }

    @discardableResult
    public func performInLogGroup<Result>(named name: String, option: PerformInLogGroupOption = .endCurrentLogGroup, operation: () throws -> Result) rethrows -> Result {
        var logGroup = LogGroup(name: name)
        var shouldStartNewGroup = true

        if let currentLogGroup {
            switch option {
            case .endCurrentLogGroup:
                platform.endLogGroup(named: currentLogGroup.name)
            case .keepCurrentLogGroup:
                logGroup = currentLogGroup
                shouldStartNewGroup = false
            }
        }

        return try ContextValues.withValue(\.currentLogGroup, logGroup) {
            if shouldStartNewGroup {
                platform.startLogGroup(named: name)
            }

            defer {
                if shouldStartNewGroup {
                    platform.endLogGroup(named: name)
                }
            }

            return try operation()
        }
    }

    @discardableResult
    public func performInLogGroup<Result>(named name: String, option: PerformInLogGroupOption = .endCurrentLogGroup, operation: () async throws -> Result) async rethrows -> Result {
        var logGroup = LogGroup(name: name)
        var shouldStartNewGroup = true

        if let currentLogGroup {
            switch option {
            case .endCurrentLogGroup:
                platform.endLogGroup(named: currentLogGroup.name)
            case .keepCurrentLogGroup:
                logGroup = currentLogGroup
                shouldStartNewGroup = false
            }
        }

        return try await ContextValues.withValue(\.currentLogGroup, logGroup) {
            if shouldStartNewGroup {
                platform.startLogGroup(named: name)
            }

            defer {
                if shouldStartNewGroup {
                    platform.endLogGroup(named: name)
                }
            }

            return try await operation()
        }
    }
}

//public extension String {
//    func embeddedInLogGroup(named name: String, startingWithBlankLine: Bool = true) -> String {
//        // Start with a blank line by default to ensure that the the start token is at the start of a new line.
//        // Callers can turn this off if needed.
//        """
//        \(startingWithBlankLine ? "\n" : "")\(startGroupToken)\(name)
//        \(self)
//        \(endGroupToken)
//        """
//    }
//}
