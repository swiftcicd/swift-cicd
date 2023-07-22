extension ContextValues {
    private enum ActionNameOverrideKey: ContextKey {
        static let defaultValue: String? = nil
    }

    public var actionNameOverride: String? {
        get { self[ActionNameOverrideKey.self] }
        set { self[ActionNameOverrideKey.self] = newValue }
    }
}
