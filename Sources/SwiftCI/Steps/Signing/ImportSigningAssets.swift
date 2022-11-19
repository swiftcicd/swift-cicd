import Foundation

public struct ImportSigningAssets: Step {
    let appStoreConnectKeySecret: AppStoreConnectKeySecret
    let certificateSecret: CertificateSecret
    let profileSecret: Secret

    public struct AppStoreConnectKeySecret {
        public let p8: Secret
        public let keyID: String
        public let keyIssuerID: String

        public init(p8: Secret, keyID: String, keyIssuerID: String) {
            self.p8 = p8
            self.keyID = keyID
            self.keyIssuerID = keyIssuerID
        }
    }

    public struct CertificateSecret {
        public let p12: Secret
        public let password: Secret

        public init(p12: Secret, password: Secret) {
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
        let appStoreConnectKeyContents: String = try loadSecret(appStoreConnectKeySecret.p8)
        let saveAppStoreConnectP8 = try await saveFile(name: "AuthKey_\(appStoreConnectKeySecret.keyID).p8", contents: appStoreConnectKeyContents)
        let appStoreConnectKey = AppStoreConnect.Key(
            id: appStoreConnectKeySecret.keyID,
            issuerID: appStoreConnectKeySecret.keyIssuerID,
            key: appStoreConnectKeyContents,
            path: saveAppStoreConnectP8.filePath
        )

        let certificateContents: Data = try loadSecret(certificateSecret.p12)
        let savedCertificate = try await saveFile(name: "Certificate.p12", contents: certificateContents)
        let certificatePassword: String = try loadSecret(certificateSecret.password)
        try await step(.installCertificate(savedCertificate.filePath, password: certificatePassword))

        let profileContents: Data = try loadSecret(profileSecret)
        let savedProfile = try await saveFile(name: "Profile.mobileprovision", contents: profileContents)
        let profile = try await step(.addProfile(savedProfile.filePath))

        return Output(
            appStoreConnectKey: appStoreConnectKey,
            certificatePath: savedCertificate.filePath,
            profile: profile
        )
    }
}
