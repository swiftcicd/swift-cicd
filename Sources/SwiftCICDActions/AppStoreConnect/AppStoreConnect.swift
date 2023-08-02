import Foundation
import JWTKit
import SwiftCICDCore

/// Namespace for App Store Connect actions.
public struct AppStoreConnect: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var appStoreConnect: AppStoreConnect { AppStoreConnect(caller: self) }
}

extension AppStoreConnect {
    public struct Key {
        let id: String
        let issuerID: String
        let key: String
        let path: String

        public init(id: String, issuerID: String, key: String, path: String) {
            self.id = id
            self.issuerID = issuerID
            self.key = key
            self.path = path
        }

        public init?(id: String, issuerID: String, path: String) {
            guard let key = ContextValues.current.fileManager.contents(atPath: path) else {
                ContextValues.current.logger.error("Failed to get contents of App Store Connect key from \(path)")
                return nil
            }

            self.init(id: id, issuerID: issuerID, key: key.string, path: path)
        }
    }

    struct Token {
        let keyID: String
        let issuerID: String
        let key: String
        let expirationDuration: TimeInterval
        let scope: [String]

        struct Payload: JWTPayload {
            var iss: IssuerClaim
            var iat: IssuedAtClaim
            var exp: ExpirationClaim
            var aud: AudienceClaim
            var scope: [String]

            func verify(using signer: JWTSigner) throws {
                try exp.verifyNotExpired()
            }
        }

        init(
            keyID: String,
            issuerID: String,
            key: String,
            expirationDuration: TimeInterval = 2 * 60,
            scope: [String]
        ) {
            self.keyID = keyID
            self.issuerID = issuerID
            self.key = key
            self.expirationDuration = expirationDuration
            self.scope = scope
        }

        func generateJWT() throws -> String {
            let now = Date()
            let payload = Payload(
                iss: IssuerClaim(value: issuerID),
                iat: IssuedAtClaim(value: now),
                exp: ExpirationClaim(value: Date(timeInterval: expirationDuration, since: now)),
                aud: "appstoreconnect-v1",
                scope: scope
            )

            let signer = try JWTSigner.es256(key: ECDSAKey.private(pem: key))
            let jwt = try signer.sign(payload, kid: JWKIdentifier(string: keyID))
            return jwt
        }
    }
}
