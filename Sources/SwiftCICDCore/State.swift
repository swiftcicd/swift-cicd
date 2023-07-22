@propertyWrapper
public struct State<T> {
    private class Storage {
        var state: T

        init(state: T) {
            self.state = state
        }
    }

    private let storage: Storage

    public init(wrappedValue: T) {
        self.storage = Storage(state: wrappedValue)
    }

    public var wrappedValue: T {
        get { storage.state }
        nonmutating set { storage.state = newValue }
    }
}
