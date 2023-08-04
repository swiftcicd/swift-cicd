import Foundation

public protocol Secret: ContextAware {
    func get() async throws -> Data
}

public struct EnvironmentSecret: Secret {
    public let key: String
    public var processValue: (inout Data) async throws -> Void

    public static func value(_ key: String) -> EnvironmentSecret {
        self.init(key: key, processValue: { _ in })
    }

    public static func base64EncodedValue(_ key: String) -> EnvironmentSecret {
        self.init(key: key, processValue: {
            guard let data = Data(base64Encoded: $0, options: .ignoreUnknownCharacters) else {
                throw ActionError("Failed to base64-decode secret")
            }

            $0 = data
        })
    }

    public init(key: String, processValue: @escaping (inout Data) async throws -> Void) {
        self.key = key
        self.processValue = processValue
    }

    public struct MissingEnvironmentSecretError: Error {
        public let key: String
    }

    public func get() async throws -> Data {
        guard let value = ProcessInfo.processInfo.environment[key] else {
            throw MissingEnvironmentSecretError(key: key)
        }

        var data = value.data
        try await processValue(&data)
        if let secretString = data.secretString {
            context.platform.obfuscate(secret: secretString)
        }
        return data
    }
}

public extension Secret where Self == EnvironmentSecret {
    static func environmentValue(_ key: String) -> EnvironmentSecret {
        .value(key)
    }

    static func base64EncodedEnvironmentValue(_ key: String) -> EnvironmentSecret {
        .base64EncodedValue(key)
    }
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
