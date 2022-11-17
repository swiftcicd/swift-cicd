extension XcodeBuildStep {
    public struct Build: Step {
        public let name = "Xcode Build: Build"

        public enum Configuration: ExpressibleByStringLiteral {
            case debug
            case release
            case custom(String)

            var string: String {
                switch self {
                case .debug:
                    return "Debug"
                case .release:
                    return "Release"
                case .custom(let value):
                    return value
                }
            }

            public init(stringLiteral value: String) {
                self = .custom(value)
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

        let scheme: String
        var configuration: Configuration?
        let destination: String
        var archivePath: String?
        var codeSignStyle: CodeSignStyle?

        public init(scheme: String, configuration: Configuration? = nil, destination: String, archivePath: String? = nil, codeSignStyle: CodeSignStyle? = nil) {
            self.scheme = scheme
            self.configuration = configuration
            self.destination = destination
            self.archivePath = archivePath
            self.codeSignStyle = codeSignStyle
        }

        public func run() async throws -> String {
            var arguments = [
                "-scheme", scheme,
                "-destination", destination
            ]

            if let configuration {
                arguments.append(contentsOf: [
                    "-configuration",
                    configuration.string
                ])
            }

            if let archivePath {
                arguments.append(contentsOf: [
                    "archive",
                    "-archivePath", archivePath
                ])
            }

            if case let .manual(codeSignIdentity, developmentTeam, provisioningProfile) = codeSignStyle {
                // It seems like this happens when you have a swift package that has a target that has resources.
                // Adding CODE_SIGNING_REQUIRED=Yes and CODE_SIGNING_ALLOWED=No because of this answer:
                // https://forums.swift.org/t/xcode-14-beta-code-signing-issues-when-spm-targets-include-resources/59685/17

                // need either code sign identity or development team, but not both (both can be used, just not required) according to testing
                // there's a note on this thread (https://developer.apple.com/forums/thread/48762) that says apple says not to use code_sign_identity when doing manual signing

                // But there's a slide from that presentation (https://devstreaming-cdn.apple.com/videos/wwdc/2017/403yv29uwyamwsi222/403/403_whats_new_in_signing_for_xcode_and_xcode_server.pdf)
                // that has this on it:
                /*
                 Manual Signing
                 Build settings
                 DEVELOPMENT_TEAM to set your team identifier
                 PROVISIONING_PROFILE_SPECIFIER to set your profile name
                 CODE_SIGN_IDENTITY to set your certificate
                */
                // So maybe those notes are wrong?

                // Also provisioning_profile is supposedly deprecated (or at the xcodebuild argument was)
                // Does that mean we shouldn't use the build setting? Maybe just the specifier?
                // Only using the specifier setting seems to work.

                arguments += [
                    "CODE_SIGNING_REQUIRED=Yes",
                    "CODE_SIGNING_ALLOWED=No",
                    "CODE_SIGN_STYLE=Manual",
//                    "CODE_SIGN_IDENTITY=\(codeSignIdentity)",
                    "DEVELOPMENT_TEAM=\(developmentTeam)",
//                    "PROVISIONING_PROFILE=\(provisioningProfile)",
                    "PROVISIONING_PROFILE_SPECIFIER=\(provisioningProfile)"
                ]
            }

            return try context.shell("xcodebuild", arguments)
        }
    }
}

public extension Step where Self == XcodeBuildStep.Build {
    static func xcodebuild(
        buildScheme scheme: String,
        configuration: XcodeBuildStep.Build.Configuration? = nil,
        destination: XcodeBuildStep.Destination,
        archiveTo archivePath: String? = nil,
        codeSignStyle: XcodeBuildStep.Build.CodeSignStyle? = nil
    ) -> XcodeBuildStep.Build {
        .init(
            scheme: scheme,
            configuration: configuration,
            destination: destination.argument,
            archivePath: archivePath,
            codeSignStyle: codeSignStyle
        )
    }
}
