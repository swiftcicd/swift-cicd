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
                // Adding CODE_SIGNING_REQUIRED=Yes and CODE_SIGNING_ALLOWED=No because of this answer:
                // https://forums.swift.org/t/xcode-14-beta-code-signing-issues-when-spm-targets-include-resources/59685/17

                arguments += [
                    "CODE_SIGNING_REQUIRED=Yes",
                    "CODE_SIGNING_ALLOWED=No",
                    "CODE_SIGN_STYLE=Manual",
                    "CODE_SIGN_IDENTITY=\(codeSignIdentity)",
                    "DEVELOPMENT_TEAM=\(developmentTeam)",
                    "PROVISIONING_PROFILE=\(provisioningProfile)",
                    "PROVISIONING_PROFILE_SPECIFIER=\(provisioningProfile)"
                ]
            }

            // Values:
            // DEVELOPMENT_TEAM ([sdk=...])
            // CODE_SIGN_IDENTITY ([sdk=...])
            // PROVISIONING_PROFILE_SPECIFIER ([sdk=...])
            // CODE_SIGN_STYLE
            // CODE_SIGN_ENTITLEMENTS
            // PROVISIONING_PROFILE
            // PRODUCT_BUNDLE_IDENTIFIER

//            -allowProvisioningUpdates                                Allow xcodebuild to communicate with the Apple Developer website. For automatically signed targets, xcodebuild will create and update profiles, app IDs, and certificates. For manually signed targets, xcodebuild will download missing or updated provisioning profiles. Requires a developer account to have been added in Xcode's Accounts preference pane or an App Store Connect authentication key to be specified via the -authenticationKeyPath, -authenticationKeyID, and -authenticationKeyIssuerID parameters.

//            -authenticationKeyPath                                   specifies the path to an authentication key issued by App Store Connect. If specified, xcodebuild will authenticate with the Apple Developer website using this credential. The -authenticationKeyID and -authenticationKeyIssuerID parameters are required.
//            -authenticationKeyID                                     specifies the key identifier associated with the App Store Conect authentication key at -authenticationKeyPath. This string can be located in the users and access details for your provider at "https://appstoreconnect.apple.com".
//            -authenticationKeyIssuerID                               specifies the App Store Connect issuer identifier associated with the authentication key at -authenticationKeyPath. This string can be located in the users and access details for your provider at "https://appstoreconnect.apple.com".

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
