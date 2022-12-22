import Foundation
import SwiftCICore

public struct ImportSigningAssets: Action {
    let appStoreConnectKeySecret: AppStoreConnectKeySecret
    let certificateSecret: CertificateSecret
    let profileSecret: Secret

    public struct AppStoreConnectKeySecret {
        public let p8: Secret
        public let keyID: String
        public let keyIssuerID: String

        public init(
            p8: Secret = .environmentValue("APP_STORE_CONNECT_KEY_P8"),
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
            p12: Secret = .base64EncodedEnvironmentValue("CERTIFICATE_P12"),
            password: Secret = .environmentValue("CERTIFICATE_PASSWORD")
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
        let saveAppStoreConnectP8 = try await saveFile(name: "AuthKey_\(appStoreConnectKeySecret.keyID).p8", contents: appStoreConnectKeyContents)
        let appStoreConnectKey = AppStoreConnect.Key(
            id: appStoreConnectKeySecret.keyID,
            issuerID: appStoreConnectKeySecret.keyIssuerID,
            key: appStoreConnectKeyContents,
            path: saveAppStoreConnectP8.filePath
        )

        let certificateContents = try await certificateSecret.p12.get()
        let savedCertificate = try await saveFile(name: "Certificate.p12", contents: certificateContents)
        let certificatePassword = try await certificateSecret.password.get().string
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
}

public extension Action {
    @discardableResult
    func importSigningAssets(
        appStoreConnectKeySecret: ImportSigningAssets.AppStoreConnectKeySecret,
        certificateSecret: ImportSigningAssets.CertificateSecret = .init(),
        profileSecret: Secret = .base64EncodedEnvironmentValue("PROVISIONING_PROFILE")
    ) async throws -> ImportSigningAssets.Output {
        try await action(ImportSigningAssets(
            appStoreConnectKeySecret: appStoreConnectKeySecret,
            certificateSecret: certificateSecret,
            profileSecret: profileSecret
        ))
    }
}
