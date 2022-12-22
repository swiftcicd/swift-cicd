import SwiftCICore

public struct BuildXcodeProject: Action {
    public let name = "Build Xcode Project"

//    @Context(\.xcodeProject) var xcodeProject

    var project: String?
    var scheme: String?
    var configuration: XcodeBuild.Configuration?
    let destination: XcodeBuild.Destination?
    var cleanBuild: Bool
    var archivePath: String?
    var codeSignStyle: XcodeBuild.CodeSignStyle?
    var projectVersion: String?
    let xcbeautify: Bool

    public init(
        project: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = nil,
        destination: XcodeBuild.Destination? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        xcbeautify: Bool = false
    ) {
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.cleanBuild = cleanBuild
        self.archivePath = archivePath
        self.codeSignStyle = codeSignStyle
        self.projectVersion = projectVersion
        self.xcbeautify = xcbeautify
    }

    public func run() async throws -> String {
        var xcodebuild = ShellCommand("xcodebuild")
        let project = try self.project ?? context.xcodeProject
        xcodebuild.append("-project", ifLet: project)
        xcodebuild.append("-scheme", ifLet: scheme)
        xcodebuild.append("-destination", ifLet: destination?.value)
        xcodebuild.append("-configuration", ifLet: configuration.map { "\($0.name)" })

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

            xcodebuild.append("""
                CODE_SIGNING_REQUIRED=Yes \
                CODE_SIGNING_ALLOWED=No \
                CODE_SIGN_STYLE=Manual \
                CODE_SIGN_IDENTITY=\(codeSignIdentity) \
                DEVELOPMENT_TEAM=\(developmentTeam) \
                PROVISIONING_PROFILE=\(provisioningProfile)
                PROVISIONING_PROFILE_SPECIFIER=\(provisioningProfile)
                """
            )
        }

        xcodebuild.append("CURRENT_PROJECT_VERSION", "=", ifLet: projectVersion)
        xcodebuild.append("clean", if: cleanBuild)

        if let archivePath {
            xcodebuild.append("archive -archivePath \(archivePath)")
        } else {
            xcodebuild.append("build")
        }

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

public extension Action {
    @discardableResult
    func buildXcodeProject(
        _ project: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = nil,
        destination: XcodeBuild.Destination? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        xcbeautify: Bool = false
    ) async throws -> String {
        try await action(
            BuildXcodeProject(
                project: project,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                xcbeautify: xcbeautify
            )
        )
    }
}
