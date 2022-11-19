import Foundation
import JWTKit

public struct AppStoreConnect {
    private func request<Response: Decodable>(method: String = "GET", _ path: String, key: Key, as response: Response.Type = Response.self) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com\(path)")!)
        let token = Token(
            keyID: key.id,
            issuerID: key.issuerID,
            key: key.key,
            scope: [
                "\(method) \(path)"
            ]
        )
        let jwt = try token.generateJWT()
        request.addValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        print(String(decoding: data, as: UTF8.self))
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response
    }

    public func getApps(key: Key) async throws -> [App] {
        try await request("/v1/apps", key: key, as: DataResponse<[App]>.self).data
    }

    public func getLatestBuild(appID: String, key: Key) async throws -> Build? {
        let data = try await request("/v1/builds?filter[app]=\(appID)&limit=1", key: key, as: DataResponse<[Build]>.self)
        return data.data.first
    }
}

extension AppStoreConnect: ContextKey {
    public static let defaultValue = AppStoreConnect()
}

public extension ContextValues {
    var appStoreConnect: AppStoreConnect {
        get { self[AppStoreConnect.self] }
        set { self[AppStoreConnect.self] = newValue }
    }
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
            guard let key = ContextValues.shared.fileManager.contents(atPath: path) else {
                ContextValues.shared.logger.error("Failed to get contents of App Store Connect key from \(path)")
                return nil
            }

            self.init(id: id, issuerID: issuerID, key: String(decoding: key, as: UTF8.self), path: path)
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

        public init(
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

        public func generateJWT() throws -> String {
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

extension AppStoreConnect {
    struct DataResponse<T: Decodable>: Decodable {
        let data: T
    }

    public struct App: Decodable {
        public let id: String
        public let attributes: Attributes

        public struct Attributes: Decodable {
            public let bundleId: String
            public let name: String
        }
    }

    public struct Build: Decodable {
        public let id: String
        public let attributes: Attributes

        public struct Attributes: Decodable {
            public let expired: Bool
            public let version: String
            public let processingState: String
        }
    }
}
