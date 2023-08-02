import Foundation

public class OutputValues {
    static let current = OutputValues()

    private let lock = NSRecursiveLock()
    private var implicitValues: [ObjectIdentifier: Any] = [:]
    private var explicitValues: [ObjectIdentifier: Any] = [:]

    private func implicitValue<Key: OutputKey>(for key: Key.Type) -> Key.Value {
        lock.lock()
        defer { lock.unlock() }

        let valueKey = ObjectIdentifier(key)

        if let value = self.implicitValues[valueKey] as? Key.Value {
            return value
        } else {
            let value = Key.defaultValue
            self.implicitValues[valueKey] = value
            return value
        }
    }

    public subscript<Key: OutputKey>(key: Key.Type) -> Key.Value {
        get {
            if let explicitValue = self.explicitValues[ObjectIdentifier(key)] as? Key.Value {
                return explicitValue
            } else {
                return implicitValue(for: key)
            }
        }

        set {
            self.explicitValues[ObjectIdentifier(key)] = newValue
        }
    }
}

public protocol OutputKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public extension ContextValues {
    private enum OutputValuesKey: ContextKey {
        static var defaultValue: OutputValues = .current
    }

    var outputs: OutputValues {
        get { self[OutputValuesKey.self] }
        set { self[OutputValuesKey.self] = newValue }
    }
}
