import SwiftCICore

public enum XcodeBuild {
    public struct Configuration: ExpressibleByStringLiteral {
        public static let debug = Configuration(name: "Debug")
        public static let release = Configuration(name: "Release")

        public let name: String

        public init(name: String) {
            self.name = name
        }

        public init(stringLiteral value: String) {
            self.init(name: value)
        }
    }

    public enum CodeSignStyle {
        case manual(codeSignIdentity: String, developmentTeam: String, provisioningProfile: String)
        case automatic

        public static func manual(profile: ProvisioningProfile) throws -> CodeSignStyle {
            let certificate = try profile.openDeveloperCertificate()
            let developmentTeam = try profile.requireTeamIdentifier()
            return .manual(codeSignIdentity: certificate.commonName, developmentTeam: developmentTeam, provisioningProfile: profile.uuid)
        }
    }

    public enum Destination {
        public enum Platform: String {
            case iOSSimulator = "iOS Simulator"
            case macOS = "OS X"
        }

        public enum GenericPlatform: String {
            case iOS
            case macOS = "OS X"
        }

        case platform(String, os: String, name: String)
        case generic(platform: String)

        public static func platform(_ platform: Platform, os: String = "latest", name: String) -> Destination {
            .platform(platform.rawValue, os: os, name: name)
        }

        public static func generic(platform: GenericPlatform) -> Destination {
            .generic(platform: platform.rawValue)
        }

        public var value: ShellCommand.Component {
            switch self {
            case let .platform(platform, os, name):
                return "platform=\(platform),OS=\(os),name=\(name)"
            case .generic(let platform):
                return "generic/platform=\(platform)"
            }
        }
    }
}
