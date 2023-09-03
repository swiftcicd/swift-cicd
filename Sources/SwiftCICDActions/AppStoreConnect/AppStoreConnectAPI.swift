import Foundation
import SwiftCICDCore

// TODO: Consider finding a Swift package for AppStoreConnect.

public enum AppStoreConnectAPI {
    public static func getApps(key: AppStoreConnect.Key) async throws -> [App] {
        try await response("/v1/apps", key: key, as: DataWrapper<[App]>.self).data
    }

    public static func getApp(bundleID: String, key: AppStoreConnect.Key) async throws -> App {
        let apps = try await getApps(key: key)
        guard let app = apps.first(where: { $0.attributes.bundleId == bundleID }) else {
            throw ActionError("No app with bundleID \(bundleID) found on App Store Connect. Either the bundle id isn't correct or the app hasn't been created on App Store Connect yet.")
        }
        return app
    }

    public static func getLatestBuild(appID: String, key: AppStoreConnect.Key) async throws -> Build? {
        // FIXME: Processing builds don't show up in this list right away. They do at some point, but not as 
        // fast as they appear on the App Store Connect website. Is there some mix of query parameters that
        // would start returning processing builds right away?
        let data = try await response("/v1/builds?filter[app]=\(appID)&limit=1", key: key, as: DataWrapper<[Build]>.self)
        return data.data.first
    }

    public static func addBuild(id buildID: String, toGroups groupIDs: [String], key: AppStoreConnect.Key) async throws {
        let body = DataWrapper(data: groupIDs.map {
            BuildBetaGroupsLinkagesRequest(id: $0)
        })
        let response = try await response("/v1/builds/\(buildID)/relationships/betaGroups", body: body, key: key)
        try validateStatusCode(from: response, is: 204)
    }

    public static func getBetaGroups(key: AppStoreConnect.Key) async throws -> [BetaGroup] {
        try await response("/v1/betaGroups", key: key, as: DataWrapper<[BetaGroup]>.self).data
    }

    public static func getBuilds(forApp app: App, key: AppStoreConnect.Key) async throws -> [Build] {
        try await response("/v1/builds?filter[app]=\(app.id)", key: key, as: DataWrapper<[Build]>.self).data
    }
}

extension AppStoreConnectAPI {
    public enum APIError: Error {
        case invalidStatusCode(actual: Int, expected: Int)
    }

    private static func validateStatusCode(from response: HTTPURLResponse, is expectedStatusCode: Int) throws {
        guard response.statusCode == expectedStatusCode else {
            throw APIError.invalidStatusCode(actual: response.statusCode, expected: expectedStatusCode)
        }
    }

    private static func request(
        method: String = "GET",
        path: String,
        key: AppStoreConnect.Key
    ) throws -> URLRequest {
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
        return request
    }

    private static func request(
        method: String = "POST",
        path: String,
        body: any Encodable,
        key: AppStoreConnect.Key
    ) throws -> URLRequest {
        var request = try request(method: method, path: path, key: key)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try JSONEncoder().encode(body)
        request.httpBody = bodyData
        return request
    }

    private static func response<Response: Decodable>(
        method: String = "GET",
        _ path: String,
        key: AppStoreConnect.Key,
        as response: Response.Type = Response.self
    ) async throws -> Response {
        let request = try request(method: method, path: path, key: key)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response
    }

    private static func response<Request: Encodable>(
        method: String = "POST",
        _ path: String,
        body: Request,
        key: AppStoreConnect.Key
    ) async throws -> HTTPURLResponse {
        let request = try request(method: method, path: path, body: body, key: key)
        let (_, response) = try await URLSession.shared.data(for: request)
        return response as! HTTPURLResponse
    }
}

extension AppStoreConnectAPI {
    struct DataWrapper<T> {
        let data: T
    }
}

extension AppStoreConnectAPI.DataWrapper: Encodable where T: Encodable {}
extension AppStoreConnectAPI.DataWrapper: Decodable where T: Decodable {}

extension AppStoreConnectAPI {
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
            public let processingState: ProcessingState

            public enum ProcessingState: String, Decodable {
                case processing = "PROCESSING"
                case failed = "FAILED"
                case invalid = "INVALID"
                case valid = "VALID"
            }
        }
    }

    struct BuildBetaGroupsLinkagesRequest: Encodable {
        /// The opaque resource ID that uniquely identifies the resource.
        let id: String
        var type: ResourceType = .betaGroups

        enum ResourceType: String, Encodable {
            case betaGroups = "betaGroups"
        }
    }

    public struct BetaGroup: Decodable {
        public let id: String
        public let attributes: Attributes

        public struct Attributes: Decodable {
            /// A Boolean value that indicates whether the group is internal. Only existing users of App Store Connect may be added for internal beta testing.
            public let isInternalGroup: Bool

            /// The name for the beta group.
            public let name: String
        }
    }
}

public extension ContextValues {
    private enum Key: ContextKey {
        static let defaultValue = AppStoreConnectAPI.self
    }

    var appStoreConnectAPI: AppStoreConnectAPI.Type {
        self[Key.self]
    }
}
