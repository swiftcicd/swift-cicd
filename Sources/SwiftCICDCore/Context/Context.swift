import Foundation

public struct ContextValues: Sendable {
    @TaskLocal public static var current = Self()

    private var implicitValues = CachedValues()
    private var explicitValues = [ObjectIdentifier: AnySendable]()

    public init() {}

    public static func withValue<Value, R>(
        _ keyPath: WritableKeyPath<ContextValues, Value>,
        _ value: Value,
        operation: () throws -> R
    ) rethrows -> R {
        var context = Self.current
        context[keyPath: keyPath] = value
        return try Self.$current.withValue(context, operation: operation)
    }

    public static func withValue<Value, R>(
        _ keyPath: WritableKeyPath<ContextValues, Value>,
        _ value: Value,
        operation: () async throws -> R
    ) async rethrows -> R {
        var context = Self.current
        context[keyPath: keyPath] = value
        return try await Self.$current.withValue(context, operation: operation)
    }

    public static func withValues<R>(
        _ updateValuesForOperation: (inout Self) throws -> Void,
        operation: () throws -> R
    ) rethrows -> R {
        var context = Self.current
        try updateValuesForOperation(&context)
        return try Self.$current.withValue(context, operation: operation)
    }

    public static func withValues<R>(
        _ updateValuesForOperation: (inout Self) async throws -> Void,
        operation: () async throws -> R
    ) async rethrows -> R {
        var context = Self.current
        try await updateValuesForOperation(&context)
        return try await Self.$current.withValue(context, operation: operation)
    }

    public subscript<Key: ContextKey>(key: Key.Type) -> Key.Value where Key.Value: Sendable {
        get {
            if let explicitValue = self.explicitValues[ObjectIdentifier(key)]?.base as? Key.Value {
                return explicitValue
            } else {
                return self.implicitValues.value(for: Key.self)
            }
        }

        set {
            self.explicitValues[ObjectIdentifier(key)] = AnySendable(newValue)
        }
    }
}

private final class CachedValues: @unchecked Sendable {
    struct CacheKey: Hashable, Sendable {
        let id: ObjectIdentifier
    }

    private let lock = NSRecursiveLock()
    private var cached = [CacheKey: AnySendable]()

    func value<Key: ContextKey>(for key: Key.Type) -> Key.Value {
        self.lock.lock()
        defer { self.lock.unlock() }

        let cacheKey = CacheKey(id: ObjectIdentifier(key))

        if let cachedValue = self.cached[cacheKey]?.base as? Key.Value {
            return cachedValue
        } else {
            let value = Key.defaultValue
            self.cached[cacheKey] = AnySendable(value)
            return value
        }
    }
}

struct AnySendable: @unchecked Sendable {
    let base: Any

    @inlinable
    init<Base: Sendable>(_ base: Base) {
        self.base = base
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
        ContextValues.current[keyPath: keyPath]
    }

    public init(_ keyPath: KeyPath<ContextValues, Value>) {
        self.keyPath = keyPath
    }
}

public protocol ContextAware {
    static var context: ContextValues { get }
    var context: ContextValues { get }
}

public extension ContextAware {
    static var context: ContextValues { .current }
    var context: ContextValues { .current }
}
