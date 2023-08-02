import Foundation
import JWTKit
import Security
import SwiftCICDCore

public struct ImportSigningAssets: Action {
    let appStoreConnectKeySecret: AppStoreConnectKeySecret
    let certificateSecret: CertificateSecret
    let profileSecret: Secret

    public struct AppStoreConnectKeySecret {
        public let p8: Secret
        public let keyID: String
        public let keyIssuerID: String

        public init(
            p8: Secret,
            keyID: String,
            keyIssuerID: String
        ) {
            self.p8 = p8
            self.keyID = keyID
            self.keyIssuerID = keyIssuerID
        }
    }

    public struct CertificateSecret {
        public let p12: Secret
        public let password: Secret

        public init(
            p12: Secret,
            password: Secret
        ) {
            self.p12 = p12
            self.password = password
        }
    }

    public struct Output {
        public let appStoreConnectKey: AppStoreConnect.Key
        public let certificatePath: String
        public let profile: ProvisioningProfile
    }

    public init(appStoreConnectKeySecret: AppStoreConnectKeySecret, certificateSecret: CertificateSecret, profileSecret: Secret) {
        self.appStoreConnectKeySecret = appStoreConnectKeySecret
        self.certificateSecret = certificateSecret
        self.profileSecret = profileSecret
    }

    public func run() async throws -> Output {
        let appStoreConnectKeyContents = try await appStoreConnectKeySecret.p8.get().string
//        try validateP8(pem: appStoreConnectKeyContents)
        let saveAppStoreConnectP8 = try await saveFile(name: "AuthKey_\(appStoreConnectKeySecret.keyID).p8", contents: appStoreConnectKeyContents)
        let appStoreConnectKey = AppStoreConnect.Key(
            id: appStoreConnectKeySecret.keyID,
            issuerID: appStoreConnectKeySecret.keyIssuerID,
            key: appStoreConnectKeyContents,
            path: saveAppStoreConnectP8.filePath
        )

        let certificateContents = try await certificateSecret.p12.get()
        let certificatePassword = try await certificateSecret.password.get().string
//        try validateP12(data: certificateContents, password: certificatePassword)
        let savedCertificate = try await saveFile(name: "Certificate.p12", contents: certificateContents)
        try await installCertificate(savedCertificate.filePath, password: certificatePassword)

        let profileContents = try await profileSecret.get()
        let savedProfile = try await saveFile(name: "Profile.mobileprovision", contents: profileContents)
        let profile = try await addProvisioningProfile(savedProfile.filePath)

        return Output(
            appStoreConnectKey: appStoreConnectKey,
            certificatePath: savedCertificate.filePath,
            profile: profile
        )
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

public extension Action {
    @discardableResult
    func importSigningAssets(
        appStoreConnectKeySecret: ImportSigningAssets.AppStoreConnectKeySecret,
        certificateSecret: ImportSigningAssets.CertificateSecret,
        profileSecret: Secret
    ) async throws -> ImportSigningAssets.Output {
        try await run(ImportSigningAssets(
            appStoreConnectKeySecret: appStoreConnectKeySecret,
            certificateSecret: certificateSecret,
            profileSecret: profileSecret
        ))
    }
}
