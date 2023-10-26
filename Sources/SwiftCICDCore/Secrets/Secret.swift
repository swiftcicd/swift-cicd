import Foundation

public protocol Secret: ContextAware {
    func get() async throws -> Data
}


public extension Action {
    func getSecret(_ secret: Secret) async throws -> Data {
        let value = try await secret.get()
        if let stringValue = value.secretString {
            context.platform.obfuscate(secret: stringValue)
        }
        return value
    }
}

public extension Data {
    /// If the data (usually used in context of secrets) is a string that can encoded/decoded without changing
    /// values, it should be treated as a secret string. This computed property will return the string if it passes
    /// this test, otherwise it will return `nil`.
    var secretString: String? {
        guard let stringValue = String(data: self, encoding: .utf8) else {
            return nil
        }

        // Check that when we convert the string back to data, it's the same value.
        // Raw files will usually not convert back to the same data.
        guard self == stringValue.data else {
            return nil
        }

        return stringValue
    }
}
