import Foundation

public struct ImportSigningAssets: Step {
    public struct Output {
        public let appStoreConnectKey: XcodeBuild.Authentication
        public let certificatePath: String
        public let profile: ProvisioningProfile
    }

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

    let appStoreConnectKeySecret: AppStoreConnectKeySecret
    let certificateSecret: CertificateSecret
    let profileSecret: Secret

    public init(appStoreConnectKeySecret: AppStoreConnectKeySecret, certificateSecret: CertificateSecret, profileSecret: Secret) {
        self.appStoreConnectKeySecret = appStoreConnectKeySecret
        self.certificateSecret = certificateSecret
        self.profileSecret = profileSecret
    }

    func saveSecret(_ secret: Secret, name: String) async throws -> (filePath: String, contents: Data) {
        switch secret {
        case .environmentFile(let key):
            let output = try await step(.loadFile(fromEnvironmentKey: key, as: name))
            return (filePath: output.filePath, contents: output.contents)

        case .environmentValue(let value):
            let contents = try context.environment.require(value)
            let filePath = context.temporaryDirectory/name
            let fileData = Data(contents.utf8)
            guard context.fileManager.createFile(atPath: filePath, contents: fileData) else {
                throw StepError("Failed to save secret file \(filePath)")
            }
            return (filePath: filePath, contents: fileData)
        }
    }

    public func run() async throws -> Output {
        let appStoreConnectKeyPath = try await saveSecret(appStoreConnectKeySecret.p8, name: "AuthKey_\(appStoreConnectKeySecret.keyID).p8").filePath
        let certificateOutput = try await saveSecret(certificateSecret.p12, name: "Certificate.p12")
        let certificatePasswordData = try await saveSecret(certificateSecret.password, name: "Certificate_Password.txt").contents
        let certificatePassword = String(decoding: certificatePasswordData, as: UTF8.self)
        let provisioningProfilePath = try await saveSecret(profileSecret, name: "Profile.mobileprovision").filePath

        try await step(.installCertificate(certificateOutput.filePath, password: certificatePassword))
        let profile = try await step(.addProfile(provisioningProfilePath))

        return Output(
            appStoreConnectKey: .init(
                key: appStoreConnectKeyPath,
                id: appStoreConnectKeySecret.keyID,
                issuerID: appStoreConnectKeySecret.keyIssuerID
            ),
            certificatePath: certificateOutput.filePath,
            profile: profile
        )
    }
}
