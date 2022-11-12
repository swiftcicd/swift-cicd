import Foundation

public enum ProcessEnvironment {
    static var environment: [String: String] = ProcessInfo.processInfo.environment

    public static subscript(key: String) -> String? {
        environment[key]
    }

    static func dump() -> String {
        environment
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}

extension ProcessEnvironment: ContextKey {
    public static let defaultValue = ProcessEnvironment.self
}

public extension ContextValues {
    var environment: ProcessEnvironment.Type {
        get { self[ProcessEnvironment.self] }
        set { self[ProcessEnvironment.self] = newValue }
    }
}
