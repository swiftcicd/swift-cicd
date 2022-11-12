import Foundation

public struct ContextValues {
    static let shared = ContextValues()
    private let cache = ContextCache()

    public subscript<Key: ContextKey>(key: Key.Type) -> Key.Value {
        get { cache.getValue(for: key) }
        set { cache.setValue(newValue, for: key) }
    }
}

private final class ContextCache {
    private var storage = [ObjectIdentifier: Any]()

    func setValue<Key: ContextKey>(_ value: Key.Value, for key: Key.Type = Key.self) {
        storage[ObjectIdentifier(key)] = value
    }

    func getValue<Key: ContextKey>(for key: Key.Type = Key.self) -> Key.Value {
        guard let value = storage[ObjectIdentifier(key)] as? Key.Value else {
            return Key.defaultValue
        }

        return value
    }
}

public protocol ContextKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

@propertyWrapper
public struct Context<Value> {
    let keyPath: KeyPath<ContextValues, Value>

    public var wrappedValue: Value {
        ContextValues.shared[keyPath: keyPath]
    }

    public init(_ keyPath: KeyPath<ContextValues, Value>) {
        self.keyPath = keyPath
    }
}
