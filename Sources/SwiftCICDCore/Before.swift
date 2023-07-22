public extension MainAction {
    func before() async throws {
        // Default is no-op.
    }
}

extension ContextValues {
    private enum IsRunningBeforeAction: ContextKey {
        static var defaultValue: Bool = false
    }

    var isRunningBeforeAction: Bool {
        get { self[IsRunningBeforeAction.self] }
        set { self[IsRunningBeforeAction.self] = newValue }
    }
}
