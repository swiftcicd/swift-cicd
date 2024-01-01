import Foundation
import SwiftCICDCore

// TODO: Consider finding a Swift package for AppStoreConnect.

public enum AppStoreConnectAPI: ContextAware {
    public static func getApps(key: AppStoreConnect.Key) async throws -> [App] {
        try await response("/v1/apps", key: key, as: DataWrapper<[App]>.self).data
    }

    public static func getApp(bundleID: String, key: AppStoreConnect.Key) async throws -> App {
        let response = try await response("/v1/apps?filter[bundleId]=\(bundleID)", key: key, as: DataWrapper<[App]>.self)
        guard let app = response.data.first else {
            throw ActionError("No app with bundleID \(bundleID) found on App Store Connect. Either the bundle id isn't correct or the app hasn't been created on App Store Connect yet.")
        }
        return app
    }

    public static func getLatestBuild(appID: String, key: AppStoreConnect.Key) async throws -> Build? {
        // FIXME: Processing builds don't show up in this list right away. They do at some point, but not as 
        // fast as they appear on the App Store Connect website. Is there some mix of query parameters that
        // would start returning processing builds right away?
        let response = try await response("/v1/builds?filter[app]=\(appID)&limit=1", key: key, as: DataWrapper<[Build]>.self)
        return response.data.first
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
        try await getBuilds(appID: app.id, key: key)
    }

    public static func getBuilds(appID: String, key: AppStoreConnect.Key) async throws -> [Build] {
        try await response("/v1/builds?filter[app]=\(appID)&include=preReleaseVersion&fields[preReleaseVersions]=platform,version", key: key, as: DataWrapper<[Build]>.self).data
    }

    public static func getBuild(
        preReleaseVersion: String,
        buildVersion: String,
        platform: Platform = .iOS,
        appID: String,
        key: AppStoreConnect.Key
    ) async throws -> Build? {
        var path = "/v1/builds"
        path.append("?filter[app]=\(appID)")
        path.append("&filter[preReleaseVersion.version]=\(preReleaseVersion)")
        path.append("&filter[version]=\(buildVersion)")
        path.append("&filter[preReleaseVersion.platform]=\(platform.rawValue)")
        path.append("&include=preReleaseVersion")
        path.append("&fields[preReleaseVersions]=platform,version")
        path.append("&limit=1")
        let builds: DataWrapper<[Build]> = try await response(path, key: key)
        return builds.data.first
    }

    public static func _endpoint(_ method: String, _ path: String, body: Data? = nil, key: AppStoreConnect.Key) async throws {
        if let body {
            try await response(method, path, body: body, key: key)
        } else {
            try await response(method, path, key: key)
        }
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
        request.httpMethod = method
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
        let bodyData = try JSONEncoder().encode(body)
        return try request(method: method, path: path, body: bodyData, key: key)
    }

    private static func request(
        method: String = "POST",
        path: String,
        body: Data,
        key: AppStoreConnect.Key
    ) throws -> URLRequest {
        var request = try request(method: method, path: path, key: key)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private static func response<Response: Decodable>(
        _ method: String,
        _ path: String,
        key: AppStoreConnect.Key,
        as response: Response.Type = Response.self
    ) async throws -> Response {
        let request = try request(method: method, path: path, key: key)
        logRequest(request)
        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        logResponse(urlResponse, bodyData: data, request: request)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response
    }

    private static func response<Response: Decodable>(
        _ path: String,
        key: AppStoreConnect.Key,
        as response: Response.Type = Response.self
    ) async throws -> Response {
        try await self.response("GET", path, key: key)
    }

    @discardableResult
    private static func response(
        _ method: String,
        _ path: String,
        key: AppStoreConnect.Key
    ) async throws -> HTTPURLResponse {
        let request = try request(method: method, path: path, key: key)
        logRequest(request)
        let (data, response) = try await URLSession.shared.data(for: request)
        logResponse(response, bodyData: data, request: request)
        return response as! HTTPURLResponse
    }

    @discardableResult
    private static func response<Request: Encodable>(
        _ method: String,
        _ path: String,
        body: Request,
        key: AppStoreConnect.Key
    ) async throws -> HTTPURLResponse {
        let request = try request(method: method, path: path, body: body, key: key)
        logRequest(request)
        let (data, response) = try await URLSession.shared.data(for: request)
        logResponse(response, bodyData: data, request: request)
        return response as! HTTPURLResponse
    }

    @discardableResult
    private static func response<Request: Encodable>(
        _ path: String,
        body: Request,
        key: AppStoreConnect.Key
    ) async throws -> HTTPURLResponse {
        try await self.response("POST", path, body: body, key: key)
    }
}

extension AppStoreConnectAPI {
    private static func logRequest(_ request: URLRequest) {
        var message = "Making request: \(request.formatted)"
        if let httpBody = request.httpBody {
            message.append("\n\(httpBody.formatted(writingOptions: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]))")
        }
        context.logger.info("\(message)")
    }

    private static func logResponse(_ response: URLResponse, bodyData: Data?, request: URLRequest) {
        let response = response as! HTTPURLResponse
        var message = "Received response: (\(response.statusCode)) \(request.formatted)"
        if let bodyData {
            message.append("\n\(bodyData.formatted(writingOptions: [.prettyPrinted, .withoutEscapingSlashes ,.sortedKeys]))")
        }
        context.logger.info("\(message)")
    }
}

private extension URLRequest {
    var formatted: String {
        "\(httpMethod ?? "GET") \(url!.absoluteString.removingPercentEncoding!)"
    }
}

private extension Data {
    func formatted(readingOptions: JSONSerialization.ReadingOptions = [], writingOptions: JSONSerialization.WritingOptions = []) -> String {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: self, options: readingOptions)
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: writingOptions)
            return jsonData.string
        } catch {
            return self.string
        }
    }
}

extension AppStoreConnectAPI {
    struct DataWrapper<T> {
        let data: T
    }
}

extension AppStoreConnectAPI.DataWrapper: Encodable where T: Encodable {}
extension AppStoreConnectAPI.DataWrapper: Decodable where T: Decodable {}

@dynamicMemberLookup
protocol AttributedModelLookup<Attributes> {
    associatedtype Attributes
    var attributes: Attributes { get }
}

extension AttributedModelLookup {
    subscript<T>(dynamicMember keyPath: KeyPath<Attributes, T>) -> T {
        attributes[keyPath: keyPath]
    }
}

extension AppStoreConnectAPI {

    /// https://developer.apple.com/documentation/appstoreconnectapi/platform
    public enum Platform: String, Decodable {
        case iOS = "IOS"
        case macOS = "MAC_OS"
        case tvOS = "TV_OS"
    }

    /// https://developer.apple.com/documentation/appstoreconnectapi/app
    public struct App: Decodable, AttributedModelLookup {
        public let id: String
        public let attributes: Attributes

        public struct Attributes: Decodable {
            public let bundleId: String
            public let name: String
        }
    }

    /// https://developer.apple.com/documentation/appstoreconnectapi/build
    public struct Build: Decodable, AttributedModelLookup {
        public let id: String
        public let attributes: Attributes
        public let included: [Included]?

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

        public enum Included: Decodable {
            case preReleaseVersion(PrereleaseVersion)

            enum CodingKeys: CodingKey {
                case preReleaseVersion
            }

            public init(from decoder: Decoder) throws {
                enum TypeCodingKey: CodingKey { case type }
                let typeContainer = try decoder.container(keyedBy: TypeCodingKey.self)
                let valueContainer = try decoder.singleValueContainer()
                let type = try typeContainer.decode(String.self, forKey: .type)
                switch type {
                case "preReleaseVersion":
                    self = .preReleaseVersion(try valueContainer.decode(PrereleaseVersion.self))
                default:
                    throw DecodingError.typeMismatch(Self.self, .init(
                        codingPath: valueContainer.codingPath,
                        debugDescription: "Unknown included type: \(type)"
                    ))
                }
            }
        }

        public init(from decoder: Decoder) throws {
            enum CodingKeys: CodingKey { case id, attributes, included }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            attributes = try container.decode(Attributes.self, forKey: .attributes)
            included = try container.decodeIfPresentLossyArrayOf(Included.self, forKey: .included)
        }
    }

    /// https://developer.apple.com/documentation/appstoreconnectapi/prereleaseversion
    public struct PrereleaseVersion: Decodable, AttributedModelLookup {
        public let id: String
        public let attributes: Attributes

        public struct Attributes: Decodable {
            public let platform: Platform
            public let version: String
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

extension KeyedDecodingContainer {
    func decodeLossyArrayOf<D: Decodable>(_ type: D.Type, forKey key: Key) throws -> Array<D> {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        var array = [D]()
        while !container.isAtEnd {
            do {
                let value = try container.decode(D.self)
                array.append(value)
            } catch {
                continue
            }
        }
        return array
    }

    func decodeIfPresentLossyArrayOf<D: Decodable>(_ type: D.Type, forKey key: Key) throws -> Array<D>? {
        guard self.contains(key) else {
            return nil
        }

        return try self.decodeLossyArrayOf(D.self, forKey: key)
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
