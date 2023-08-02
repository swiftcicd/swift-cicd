import Foundation
import SwiftCICDCore

// TODO: Consider finding a Swift package for AppStoreConnect.

public struct AppStoreConnectAPI {
    private func request<Response: Decodable>(method: String = "GET", _ path: String, key: AppStoreConnect.Key, as response: Response.Type = Response.self) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com\(path)")!)
        let token = AppStoreConnect.Token(
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
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response
    }

    public func getApps(key: AppStoreConnect.Key) async throws -> [App] {
        try await request("/v1/apps", key: key, as: DataResponse<[App]>.self).data
    }

    public func getLatestBuild(appID: String, key: AppStoreConnect.Key) async throws -> Build? {
        // FIXME: Processing builds don't show up in this list right away. They do at some point, but not as fast as they appear on the App Store Connect website.
        // Is there some mix of query parameters that would start returning processing builds right away?
        let data = try await request("/v1/builds?filter[app]=\(appID)&limit=1", key: key, as: DataResponse<[Build]>.self)
        return data.data.first
    }
}

public extension ContextValues {
    private enum Key: ContextKey {
        static let defaultValue = AppStoreConnectAPI()
    }

    var appStoreConnectAPI: AppStoreConnectAPI {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

extension AppStoreConnectAPI {
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
