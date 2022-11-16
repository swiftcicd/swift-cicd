public struct InstallCertificate: Step {
    let keychain: String
    let keychainPassword: String
    let certificate: String
    let certificatePassword: String

    public func run() async throws {
        // https://stackoverflow.com/a/46095880/4283188

        // TODO: How do we get around needing to know the keychain's password?
        // Can we create a new keychain specifically for signing that doesn't have a password?

        let keychain = "~/Library/Keychains/\(self.keychain).keychain"
        try context.shell("security", "unlock-keychain", "-p", keychainPassword, keychain)
        try context.shell("security", "import", certificate, "-k", keychain, "-T", "-P", certificatePassword, "/usr/bin/codesign")
    }
}

public extension Step where Self == InstallCertificate {
    static func installCertificate(
        _ certificate: String,
        password certificatePassword: String,
        toKeychain keychain: String,
        password keychainPassword: String
    ) -> InstallCertificate {
        InstallCertificate(keychain: keychain, keychainPassword: keychainPassword, certificate: certificate, certificatePassword: certificatePassword)
    }
}
