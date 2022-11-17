extension XcodeBuild {
    public struct Authentication {
        /// Specifies the path to an authentication key issued by App Store Connect.
        /// If specified, xcodebuild will authenticate with the Apple Developer website using this credential.
        /// Requires -authenticationKeyID and -authenticationKeyIssuerID.
        public let key: String

        /// Specifies the key identifier associated with the App Store Conect authentication key at -authenticationKeyPath.
        /// This string can be located in the users and access details for your provider at  https://appstoreconnect.apple.com.
        public let id: String

        /// Specifies the App Store Connect issuer identifier associated with the authentication key at -authenticationKeyPath.
        /// This string can be located in the users and access details for your provider at https://appstoreconnect.apple.com.
        public let issuerID: String

        public init(key: String, id: String, issuerID: String) {
            self.key = key
            self.id = id
            self.issuerID = issuerID
        }
    }
}
