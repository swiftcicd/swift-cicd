import SwiftCICDCore

public extension XcodeBuild {
    enum Container {
        case project(String)
        case workspace(String)

        public var flag: ShellCommand.Component {
            switch self {
            case .project(let project):
                return "-project \(project)"
            case .workspace(let workspace):
                return "-workspace \(workspace)"
            }
        }
    }

    struct Configuration: ExpressibleByStringLiteral {
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

    enum CodeSignStyle {
        case manual(codeSignIdentity: String, developmentTeam: String, provisioningProfile: String)
        case automatic

        public static func manual(profile: ProvisioningProfile) throws -> CodeSignStyle {
            let certificate = try profile.openDeveloperCertificate()
            let developmentTeam = try profile.requireTeamIdentifier()
            return .manual(codeSignIdentity: certificate.commonName, developmentTeam: developmentTeam, provisioningProfile: profile.uuid)
        }
    }

    enum Destination {
        public enum Platform: String {
            case iOSSimulator = "iOS Simulator"
            case macOS = "OS X"

            /// Alias for ``Platform/macOS``.
            public static let osx = Platform.macOS

            public var sdk: SDK? {
                switch self {
                case .iOSSimulator:
                    return .iOSSimulator
                case .macOS:
                    return .macOS
                }
            }
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

        public static var iOSSimulator: Destination {
            .iOSSimulator(name: "iPhone 14")
        }

        public static func iOSSimulator(name: String) -> Destination {
            .platform(.iOSSimulator, name: name)
        }

        public var sdk: SDK? {
            switch self {
            case .generic(let platformString):
                return Platform(rawValue: platformString)?.sdk

            case .platform(let platformString, _, _):
                return Platform(rawValue: platformString)?.sdk
            }
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

    enum SDK: String {
        case driverKit = "driverkit"
        case iOS = "iphoneos"
        case iOSSimulator = "iphonesimulator"
        case macOS = "macosx"
        case tvOS = "appletvos"
        case tvOSSimulator = "appletvsimulator"
        case watchOS = "watchos"
        case watchOSSimulator = "watchsimulator"

        public var value: ShellCommand.Component {
            "\(rawValue)"
        }
    }
}
