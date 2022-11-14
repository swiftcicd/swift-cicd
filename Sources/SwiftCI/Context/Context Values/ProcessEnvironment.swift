import SwiftEnvironment

extension ProcessEnvironment: ContextKey {
    public static let defaultValue = ProcessEnvironment.self
}

public extension ContextValues {
    var environment: ProcessEnvironment.Type {
        get { self[ProcessEnvironment.self] }
        set { self[ProcessEnvironment.self] = newValue }
    }
}
