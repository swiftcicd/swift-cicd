import Foundation
import SwiftCICDCore

public extension Xcode {

    // TODO: We can run into problems if the Container's path isn't a full file path.
    // It's better if we always ensure that it is.
    // Check if the supplied path has

    enum Container {
        case project(String)
        case workspace(String)

        public var isProject: Bool {
            switch self {
            case .project: return true
            case .workspace: return false
            }
        }

        public var isWorkspace: Bool {
            switch self {
            case .workspace: return true
            case .project: return false
            }
        }

        public var path: String {
            get throws {
                let relativePath: String
                switch self {
                case .project(let project):
                    relativePath = project
                case .workspace(let workspace):
                    relativePath = workspace
                }

                return try context.workingDirectory/relativePath
            }
        }

        public var flag: ShellCommand.Component {
            get throws {
                let path = try self.path
                switch self {
                case .project:
                    return "-project \(path)"
                case .workspace:
                    return "-workspace \(path)"
                }
            }
        }
    }
}

extension Xcode.Container: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        if value.hasSuffix(".xcworkspace") {
            self = .workspace(value)
        } else {
            self = .project(value)
        }
    }
}

public enum XcodeBuild {
//    static var derivedData: URL {
//        context.fileManager.temporaryDirectory/"DerivedData"
//    }

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

    public enum SDK: String {
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
