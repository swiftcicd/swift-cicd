public struct Build: Step {
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

    var scheme: String?
    var configuration: Configuration?
    let destination: String?
    var cleanBuild: Bool
    var archivePath: String?
    var codeSignStyle: CodeSignStyle?
    var projectVersion: String?
    let xcbeautify: Bool

    public init(
        scheme: String? = nil,
        configuration: Configuration? = nil,
        destination: String? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: CodeSignStyle? = nil,
        projectVersion: String? = nil,
        xcbeautify: Bool = false
    ) {
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.cleanBuild = cleanBuild
        self.archivePath = archivePath
        self.codeSignStyle = codeSignStyle
        self.projectVersion = projectVersion
        self.xcbeautify = xcbeautify
    }

    public init(
        scheme: String? = nil,
        configuration: Configuration? = nil,
        destination: XcodeBuildStep.Destination? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: CodeSignStyle? = nil,
        projectVersion: String? = nil,
        xcbeautify: Bool = false
    ) {
        self.init(
            scheme: scheme,
            configuration: configuration,
            destination: destination?.argument,
            cleanBuild: cleanBuild,
            archivePath: archivePath,
            codeSignStyle: codeSignStyle,
            projectVersion: projectVersion,
            xcbeautify: xcbeautify
        )
    }

    public func run() async throws -> String {
        var xcodebuild = Command("xcodebuild")
        xcodebuild.add("-scheme", ifLet: scheme)
        xcodebuild.add("-destination", ifLet: destination)
        xcodebuild.add("-configuration", ifLet: configuration?.string)

        if let archivePath {
            xcodebuild.add("archive", "-archivePath", archivePath)
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

            xcodebuild.add(
                "CODE_SIGNING_REQUIRED=Yes",
                "CODE_SIGNING_ALLOWED=No",
                "CODE_SIGN_STYLE=Manual",
                "CODE_SIGN_IDENTITY=\(codeSignIdentity)",
                "DEVELOPMENT_TEAM=\(developmentTeam)",
                "PROVISIONING_PROFILE=\(provisioningProfile)",
                "PROVISIONING_PROFILE_SPECIFIER=\(provisioningProfile)"
            )
        }

        if let projectVersion {
            xcodebuild.add("CURRENT_PROJECT_VERSION=\(projectVersion)")
        }

        if cleanBuild {
            xcodebuild.add("clean")
        }

        xcodebuild.add("build")

        if xcbeautify {
            return try await xcbeautify(xcodebuild)
        } else {
            return try context.shell(xcodebuild)
        }
    }

    public func cleanUp(error: Error?) async throws {
        if let archivePath {
            try context.fileManager.removeItem(atPath: archivePath)
        }
    }
}

public extension StepRunner {
    @discardableResult
    func build(
        scheme: String? = nil,
        configuration: Build.Configuration? = nil,
        destination: XcodeBuildStep.Destination? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: Build.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        xcbeautify: Bool = false
    ) async throws -> String {
        try await step {
            Build(
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                xcbeautify: xcbeautify
            )
        }
    }
}
