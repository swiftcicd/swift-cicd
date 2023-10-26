import Foundation
import JWTKit
import Security
import SwiftCICDCore

extension Signing {
    public struct ImportSigningAssets: Action {
        let secrets: Secrets

        public struct Output {
            public let appStoreConnectKey: AppStoreConnect.Key
            public let certificatePath: String
            public let profile: ProvisioningProfile
        }

        init(secrets: Secrets) {
            self.secrets = secrets
        }

        public init(
            appStoreConnectKey: Secrets.AppStoreConnectKey,
            certificate: Secrets.Certificate,
            profile: Secrets.Profile
        ) {
            self.init(secrets: Secrets(
                appStoreConnectKey: appStoreConnectKey,
                certificate: certificate,
                profile: profile
            ))
        }

        public func run() async throws -> Output {
            let appStoreConnectKeySecret = try await secrets.appStoreConnectKey()
            let certificateSecret = try await secrets.certificate()
            let profileSecret = try await secrets.profile()

            let appStoreConnectKeyContents = try await appStoreConnectKeySecret.p8()
//            try validateP8(pem: appStoreConnectKeyContents)
            let saveAppStoreConnectP8 = try await saveFile(
                name: "AuthKey_\(appStoreConnectKeySecret.keyID).p8",
                contents: appStoreConnectKeyContents
            )

            let appStoreConnectKey = AppStoreConnect.Key(
                id: appStoreConnectKeySecret.keyID,
                issuerID: appStoreConnectKeySecret.keyIssuerID,
                key: appStoreConnectKeyContents,
                path: saveAppStoreConnectP8.filePath
            )

            let certificateContents = try await certificateSecret.p12()
            let certificatePassword = try await certificateSecret.password()
//            try validateP12(data: certificateContents, password: certificatePassword)
            let savedCertificate = try await saveFile(name: "Certificate.p12", contents: certificateContents)
            try await signing.installCertificate(savedCertificate.filePath, password: certificatePassword)

            let profileContents = try await profileSecret.mobileprovision()
            let savedProfile = try await saveFile(name: "Profile.mobileprovision", contents: profileContents)
            let profile = try await signing.addProvisioningProfile(savedProfile.filePath)

            let output = Output(
                appStoreConnectKey: appStoreConnectKey,
                certificatePath: savedCertificate.filePath,
                profile: profile
            )

            context.outputs.signingAssets = output
            return output
        }

        private func validateP8(pem: String) throws {
            logger.info("Validating AppStoreConnectKeySecret.p8")
            do {
                // Verify that the P8 is valid (it should be a private RSA key)
                _ = try RSAKey.private(pem: pem)
            } catch {
                throw ActionError("Invalid AppStoreConnectKeySecret.p8", error: error)
            }
        }

        private func validateP12(data: Data, password: String) throws {
            logger.info("Validating CertificateSecret.p12")
            var importResult: CFArray? = nil
            let status = SecPKCS12Import(
                data as NSData,
                [kSecImportExportPassphrase as String: password] as NSDictionary,
                &importResult
            )

            switch status {
            case errSecSuccess:
                // Valid
                break
            case errSecAuthFailed:
                // Invalid password
                throw ActionError("CertificateSecret.password was incorrect")
            case errSecDecode:
                // Invalid data
                throw ActionError("Invalid CertificateSecret.p12")
            default:
                logger.warning("SecPKCS12Import didn't result in errSecSuccess. Continuing regardless.")
                break
            }
        }

        // TODO: Validate Provisioning Profile
        private func validateProvisioningProfile(data: Data, certificatePublicKey: String) throws {
            // https://stackoverflow.com/questions/6712895/validate-certificate-and-provisioning-profile
            // https://github.com/quadion/iOSValidation/blob/master/validateProvisioningProfile.rb
        }
    }
}

extension Signing.ImportSigningAssets {
    public struct Secrets: Decodable {
        let appStoreConnectKey: () async throws -> AppStoreConnectKey
        let certificate: () async throws -> Certificate
        let profile: () async throws -> Profile

        public init(
            appStoreConnectKey: AppStoreConnectKey,
            certificate: Certificate,
            profile: Profile
        ) {
            self.appStoreConnectKey = { appStoreConnectKey }
            self.certificate = { certificate }
            self.profile = { profile }
        }

        enum CodingKeys: CodingKey {
            case appStoreConnectKey
            case certificate
            case profile
        }

        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.appStoreConnectKey = { try container.decode(AppStoreConnectKey.self, forKey: .appStoreConnectKey) }
            self.certificate = { try container.decode(Certificate.self, forKey: .certificate) }
            self.profile = { try container.decode(Profile.self, forKey: .profile) }
        }

        public struct AppStoreConnectKey: Decodable {
            let p8: () async throws -> String
            let keyID: String
            let keyIssuerID: String

            public init(p8: Secret, keyID: String, keyIssuerID: String) {
                self.p8 = { try await p8.get().string }
                self.keyID = keyID
                self.keyIssuerID = keyIssuerID
            }

            enum CodingKeys: CodingKey {
                case p8
                case keyID
                case keyIssuerID
            }

            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                self.p8 = { try container.decode(String.self, forKey: .p8) }
                self.keyID = try container.decode(String.self, forKey: .keyID)
                self.keyIssuerID = try container.decode(String.self, forKey: .keyIssuerID)
            }
        }

        public struct Certificate: Decodable {
            let p12: () async throws -> String
            let password: () async throws -> String

            public init(p12: Secret, password: Secret) {
                self.p12 = { try await p12.get().string }
                self.password = { try await password.get().string }
            }

            enum CodingKeys: CodingKey {
                case p12
                case password
            }

            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                self.p12 = { try container.decode(String.self, forKey: .p12) }
                self.password = { try container.decode(String.self, forKey: .password) }
            }
        }

        public struct Profile: Decodable {
            let mobileprovision: () async throws -> String

            public init(mobileprovision: Secret) {
                self.mobileprovision = { try await mobileprovision.get().string }
            }

            enum CodingKeys: CodingKey {
                case mobileprovision
            }

            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                self.mobileprovision = { try container.decode(String.self, forKey: .mobileprovision) }
            }
        }
    }
}

// MARK: - File

extension Signing.ImportSigningAssets.Secrets {
    /// Creates the necessary secrets by reading from a secret JSON file following the expected format below.
    ///
    /// - Parameter file: A secret containing the JSON file.
    ///
    /// ### File format:
    /// ```json
    /// {
    ///    "appStoreConnectKey": {
    ///        "p8": "p8 file contents (string)",
    ///        "keyID": "string",
    ///        "keyIssuerID": "string"
    ///    },
    ///    "certificate": {
    ///        "p12": "base64Encoded file contents (string)",
    ///        "password": "string"
    ///    },
    ///    "profile":  {
    ///        "mobileprovision": "base64Encoded file contents (string)"
    ///    }
    /// }
    /// ```
    public init(file: Secret) throws {
        func decodedFile() async throws -> Self {
            try await JSONDecoder().decode(Self.self, from: file.get())
        }

        self.appStoreConnectKey = { try await decodedFile().appStoreConnectKey() }
        self.certificate = { try await decodedFile().certificate() }
        self.profile = { try await decodedFile().profile() }
    }
}

public extension Signing {
    @discardableResult
    func `import`(
        appStoreConnectKey: ImportSigningAssets.Secrets.AppStoreConnectKey,
        certificateSecret: ImportSigningAssets.Secrets.Certificate,
        profileSecret: ImportSigningAssets.Secrets.Profile
    ) async throws -> ImportSigningAssets.Output {
        try await run(ImportSigningAssets(
            appStoreConnectKey: appStoreConnectKey,
            certificate: certificateSecret,
            profile: profileSecret
        ))
    }

    /// Creates the necessary secrets by reading from a secret JSON file following the expected format below.
    ///
    /// - Parameter file: A secret containing the JSON file.
    ///
    /// ### File format:
    /// ```json
    /// {
    ///    "appStoreConnectKey": {
    ///        "p8": "p8 file contents (string)",
    ///        "keyID": "string",
    ///        "keyIssuerID": "string"
    ///    },
    ///    "certificate": {
    ///        "p12": "base64Encoded file contents (string)",
    ///        "password": "string"
    ///    },
    ///    "profile":  {
    ///        "mobileprovision": "base64Encoded file contents (string)"
    ///    }
    /// }
    /// ```
    @discardableResult
    func `import`(
        signingAssetsFromFile file: Secret
    ) async throws -> ImportSigningAssets.Output {
        try await run(ImportSigningAssets(secrets: .init(file: file)))
    }
}

public extension OutputValues {
    private enum Key: OutputKey {
        static var defaultValue: Signing.ImportSigningAssets.Output?
    }

    var signingAssets: Signing.ImportSigningAssets.Output? {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}
