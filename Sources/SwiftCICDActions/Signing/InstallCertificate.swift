import Foundation
import SwiftCICDCore

struct InstallCertificate: Action {
    var shouldCreateKeychain: Bool = false
    let keychain: String
    let keychainPassword: String
    let certificate: String
    let certificatePassword: String

    @State var certificateCommonName: String?

    func listUserKeychains() async throws -> [String] {
        try await shell("security list-keychain -d user")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\""))) }
    }

    func keychainExists(_ keychain: String, in keychains: [String]) throws -> Bool {
        // The keychain we created may show up at different path so only check for common suffix
        // example: /var/temp/temp.keychain may show up at /private/var/temp/temp.keychain after it's added to the search list.
        return keychains.contains(where: { $0.hasSuffix(keychain) })
    }

    func run() async throws {
        // References:
        // https://stackoverflow.com/a/46095880/4283188
        // https://github.com/microsoft/azure-pipelines-tasks/blob/ad56e0c4a52a33256e39786bec1947daf97c1743/common-npm-packages/ios-signing-common/ios-signing-common.ts#L16

        logger.info("Importing certificate \(certificate) in keychain \(keychain)")

        if shouldCreateKeychain {
            if context.fileManager.fileExists(atPath: keychain) {
                try await shell("security delete-keychain \(keychain)")
            }

            // Create the keychain with the given password
            try await shell("security create-keychain -p \(keychainPassword) \(keychain)")
            try await shell("security set-keychain-settings -lut 21600 \(keychain)")
        }

        // Unlock the keychain with the password
        try await shell("security unlock-keychain -p \(keychainPassword) \(keychain)")

        // Import the certificate to the keychain
        // -A: Allow any application to access the certificate
        // -t cert: Type is cert
        // -f pkcs12: Format is pkcs12
        try await shell("security import \(certificate) -P \(certificatePassword) -A -t cert -f pkcs12 -k \(keychain)")

        if !shouldCreateKeychain {
            guard let certificateData = context.fileManager.contents(atPath: certificate) else {
                throw ActionError("Failed to open certificate \(certificate)")
            }

            let certificate = try Certificate(data: certificateData)
            certificateCommonName = certificate.commonName
            // This command doesn't exist until macOS 10.12
            try await shell("security set-key-partition-list -S apple-tool:,apple: -s -l \(certificate.commonName) -k \(keychainPassword) \(keychain)")
        }

        let keychains = try await listUserKeychains()
        // If the keychain we're using doesn't show up in the user's list, add it to the search list.
        if try !keychainExists(keychain, in: keychains) {
            // Add the keychain to the front of the list so it will be used first
            try await shell("security list-keychain -d user -s \(keychain) \(keychains)")
        }

        // Verify that the keychain exists in our list now
        let verifyKeychains = try await listUserKeychains()
        guard try keychainExists(keychain, in: verifyKeychains) else {
            throw ActionError("Keychain setup failed \(keychain)")
        }

        logger.debug("Successfully imported certificate")
    }

    func cleanUp(error: Error?) async throws {
        if let certificateCommonName {
            try await shell("security delete-certificate -c \(certificateCommonName) \(keychain)")
        }

        if shouldCreateKeychain {
            try await shell("security delete-keychain \(keychain)")
        }
    }
}

public extension Signing {
    func installCertificate(
        _ certificate: String,
        password certificatePassword: String,
        toKeychain keychain: String,
        password keychainPassword: String
    ) async throws {
        try await run(
            InstallCertificate(
                keychain: keychain,
                keychainPassword: keychainPassword,
                certificate: certificate,
                certificatePassword: certificatePassword
            )
        )
    }

    func installCertificate(
        _ certificate: String,
        password certificatePassword: String
    ) async throws {
        let keychain = context.fileManager.temporaryDirectory.path/"temp.keychain"
        let password = String.random(length: 20)
        return try await run(
            InstallCertificate(
                shouldCreateKeychain: true,
                keychain: keychain,
                keychainPassword: password,
                certificate: certificate,
                certificatePassword: certificatePassword
            )
        )
    }
}

extension String {
    static func random(length: Int) -> String {
        let numbers = 48...57
        let uppers = 65...90
        let lowers = 97...122
        let asciiRanges = [numbers, uppers, lowers]
        return (0..<length).reduce(into: "") { string, _ in
            string += asciiRanges.randomElement()!.randomElement().flatMap(UnicodeScalar.init).flatMap(String.init)!
        }
    }
}
