import Foundation

public struct EnvironmentSecret: Secret {
    let key: String

    private init(key: String) {
        self.key = key
    }

    public struct MissingEnvironmentSecretError: Error {
        public let key: String
    }

    public func get() async throws -> Data {
        guard let value = ProcessInfo.processInfo.environment[key] else {
            throw MissingEnvironmentSecretError(key: key)
        }

        let data = value.data
        if let secretString = data.secretString {
            context.platform.obfuscate(secret: secretString)
        }
        return data
    }
}

public extension EnvironmentSecret {
    static func value(_ key: String) -> EnvironmentSecret {
        EnvironmentSecret(key: key)
    }

    static func base64EncodedValue(_ key: String) -> TransformedSecret {
        EnvironmentSecret(key: key).base64Decoded()
    }
}

public extension Secret where Self == EnvironmentSecret {
    static func environmentValue(_ key: String) -> EnvironmentSecret {
        EnvironmentSecret.value(key)
    }
}

public extension Secret where Self == TransformedSecret {
    static func base64EncodedEnvironmentValue(_ key: String) -> TransformedSecret {
        EnvironmentSecret.base64EncodedValue(key)
    }
}
