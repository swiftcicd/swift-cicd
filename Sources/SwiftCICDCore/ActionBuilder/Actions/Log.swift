import Logging

// This action namespace doesn't conform to ActionNamespace because logging inside
// of actions should be done via the context's logger.

/// Namespace for Log actions.
public enum Log {}

public extension Log {
    struct Trace: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.trace(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }

    struct Debug: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.debug(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }

    struct Info: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.info(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }

    struct Notice: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.notice(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }

    struct Warning: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.warning(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }

    struct Error: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.error(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }

    struct Critical: _BuilderAction {
        var log: () -> Void = {}

        public init(
            _ message: @escaping @autoclosure () -> Logger.Message,
            metadata: @escaping @autoclosure () -> Logger.Metadata? = nil,
            source: @escaping @autoclosure () -> String? = nil,
            file: String = #fileID, function: String = #function, line: UInt = #line
        ) {
            log = { [logger] in
                logger.critical(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
            }
        }

        public func run() {
            log()
        }
    }
}
