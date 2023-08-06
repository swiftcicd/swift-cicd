import Foundation

@propertyWrapper
public struct Value<T> {
    private class Storage {
        let lock = NSRecursiveLock()
        var _value: T
        var value: T {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _value
            }

            set {
                lock.lock()
                defer { lock.unlock() }
                _value = newValue
            }
        }

        init(_ value: T) {
            self._value = value
        }
    }

    private let storage: Storage
    public var projectedValue: Self { self }
    public var wrappedValue: T {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    public init(wrappedValue: T) {
        self.storage = Storage(wrappedValue)
    }
}
