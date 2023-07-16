import Foundation
import SwiftCICore

// TODO: Make `brew` a Tool

public enum OnePassword: Tool {
    static let brew = "brew"///opt/homebrew/bin/brew"
    static let path = "/usr/local/bin/op"

    public static var isInstalled: Bool {
        get async {
            do {
                return try !context.shell("\(path) --version", log: false, quiet: true).isEmpty
            } catch {
                return false
            }
        }
    }

    public static func install() async throws {
        try context.shell("\(brew) install --cask 1password/tap/1password-cli")
    }

    public static func uninstall() async throws {
        try context.shell("\(brew) uninstall 1password-cli")
    }

    public static func read(reference: String, serviceAccountToken: String) async throws -> Data {
        try context.shell("OP_SERVICE_ACCOUNT_TOKEN=\(serviceAccountToken) \(Self.path) read \(reference)", log: false, quiet: true)
    }
}

public extension Tools {
    var onePassword: OnePassword.Type {
        get async throws {
            try await self[OnePassword.self]
        }
    }
}

public struct OnePasswordSecret: Secret {
    let reference: String
    let serviceAccountToken: Secret

    public init(reference: String, serviceAccountToken: Secret) {
        self.reference = reference
        self.serviceAccountToken = serviceAccountToken
    }

    public func get() async throws -> Data {
        let onePassword = try await context.tools.onePassword
        let token = try await serviceAccountToken.get().string
        let secret = try await onePassword.read(reference: reference, serviceAccountToken: token)

        // Obfuscate the secret if it can be converted to a string.
        if let secretString = String(data: secret, encoding: .utf8) {
            // Reference:
            // https://github.com/1Password/load-secrets-action/blob/d1a4e73495bde3551cf63f6c048588b8f734e21d/entrypoint.sh#L101
            // To support multiline secrets, escape percent signs and add a mask per line.
            let escapedSecret = secretString.replacingOccurrences(of: "%", with: "%25")
            try context.platform.obfuscate(secret: escapedSecret)
        }

        return secret
    }
}

public extension Secret where Self == OnePasswordSecret {
    static func onePassword(reference: String, serviceAccountToken: Secret) -> OnePasswordSecret {
        OnePasswordSecret(reference: reference, serviceAccountToken: serviceAccountToken)
    }
}

public struct OnePasswordVault {
    let vault: String
    let serviceAccountToken: Secret

    public init(vault: String, serviceAccountToken: Secret) {
        self.vault = vault
        self.serviceAccountToken = serviceAccountToken
    }

    public func secret(_ shortenedReference: String) -> Secret {
        OnePasswordSecret(reference: "op://\(vault)/\(shortenedReference)", serviceAccountToken: serviceAccountToken)
    }
}
