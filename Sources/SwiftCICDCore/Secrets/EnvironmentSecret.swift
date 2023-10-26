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
    static func value(_ key: String) -> some Secret {
        EnvironmentSecret(key: key)
    }

    static func base64EncodedValue(_ key: String) -> some Secret {
        EnvironmentSecret(key: key).base64Decoded()
    }
}

// FIXME: Auto-completion doesn't pick these up for some reason.
// I know that the self-constraint is incorrect for the base64EncodedEnvironmentValue
// but it is at least available while keeping TransformedSecret internal.
public extension Secret where Self == EnvironmentSecret {
    static func environmentValue(_ key: String) -> some Secret {
        EnvironmentSecret.value(key)
    }

    static func base64EncodedEnvironmentValue(_ key: String) -> some Secret {
        EnvironmentSecret.base64EncodedValue(key)
    }
}
