import SwiftEnvironment

public extension ContextValues {
    private enum ProcessEnvironmentKey: ContextKey {
        public static let defaultValue = ProcessEnvironment.self
    }

    var environment: ProcessEnvironment.Type {
        get { self[ProcessEnvironmentKey.self] }
        set { self[ProcessEnvironmentKey.self] = newValue }
    }
}
