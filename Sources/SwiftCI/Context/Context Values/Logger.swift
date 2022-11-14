public protocol Logger {
    func log(_ message: String)
}

public extension Logger {
    func callAsFunction(_ message: String) {
        log(message)
    }
}

public extension Workflow {
    static func log(_ message: String) {
        context.logger.log(message)
    }

    func log(_ message: String) {
        context.logger.log(message)
    }
}

public extension Step {
    func log(_ message: String) {
        context.logger.log(message)
    }
}

public struct Log: Logger {
    public func log(_ message: String) {
        print(message)
    }
}

enum LoggerKey: ContextKey {
    static let defaultValue: Logger = Log()
}

public extension ContextValues {
    var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}
