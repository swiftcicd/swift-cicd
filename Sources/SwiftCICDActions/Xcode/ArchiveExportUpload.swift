import Foundation
import SwiftCICDCore

extension Xcode {
    public struct ArchiveExportUpload: Action {
        let container: Xcode.Container?
        let scheme: String?
        let destination: XcodeBuild.Destination?
        var profile: ProvisioningProfile?
        var appStoreConnectKey: AppStoreConnect.Key?
        let buildNumberStrategy: BuildNumberStrategy
        let includeDSYMs: Bool?
        let xcbeautify: Bool

        public enum BuildNumberStrategy {
            // TODO: Add a semantic version strategy
            case autoIncrementingInteger
            case date(format: String = "yy.MM.dd.HH.mm")
            case random(length: Int)
            case project
        }

        public init(
            project: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .generic(platform: .iOS),
            profile: ProvisioningProfile,
            appStoreConnectKey: AppStoreConnect.Key,
            buildNumberStrategy: BuildNumberStrategy = .autoIncrementingInteger,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = project.map { .project($0) }
            self.scheme = scheme
            self.destination = destination
            self.profile = profile
            self.appStoreConnectKey = appStoreConnectKey
            self.buildNumberStrategy = buildNumberStrategy
            self.includeDSYMs = includeDSYMs
            self.xcbeautify = xcbeautify
        }

        @_disfavoredOverload
        public init(
            workspace: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .generic(platform: .iOS),
            profile: ProvisioningProfile,
            appStoreConnectKey: AppStoreConnect.Key,
            buildNumberStrategy: BuildNumberStrategy = .autoIncrementingInteger,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = workspace.map { .workspace($0) }
            self.scheme = scheme
            self.destination = destination
            self.profile = profile
            self.appStoreConnectKey = appStoreConnectKey
            self.buildNumberStrategy = buildNumberStrategy
            self.includeDSYMs = includeDSYMs
            self.xcbeautify = xcbeautify
        }

        public init(
            project: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .generic(platform: .iOS),
            buildNumberStrategy: BuildNumberStrategy = .autoIncrementingInteger,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = project.map(Xcode.Container.project)
            self.scheme = scheme
            self.destination = destination
            self.buildNumberStrategy = buildNumberStrategy
            self.includeDSYMs = includeDSYMs
            self.xcbeautify = xcbeautify
        }

        @_disfavoredOverload
        public init(
            workspace: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .generic(platform: .iOS),
            buildNumberStrategy: BuildNumberStrategy = .autoIncrementingInteger,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = workspace.map { .workspace($0) }
            self.scheme = scheme
            self.destination = destination
            self.buildNumberStrategy = buildNumberStrategy
            self.includeDSYMs = includeDSYMs
            self.xcbeautify = xcbeautify
        }

        public struct Output {
            public let archive: String
            public let export: String
            public let ipa: String
            public let uploadedBuildVersion: String
            public let uploadedBuildNumber: String
        }

        public func run() async throws -> Output {
            let container = try self.container ?? context.xcodeContainer
            let scheme = self.scheme ?? context.xcodeScheme

            guard let container else {
                throw ActionError("Missing Xcode project/workspace. Either pass an explicit project/workspace or call this step from an XcodeAction.")
            }

            let profile: ProvisioningProfile
            let appStoreConnectKey: AppStoreConnect.Key

            if let p = self.profile, let a = self.appStoreConnectKey {
                profile = p
                appStoreConnectKey = a
            } else {
                guard let signingAssets = context.outputs.signingAssets else {
                    throw ActionError("Signing Assets not found from previous outputs. Run 'Signing.Import' before running this action.")
                }

                profile = signingAssets.profile
                appStoreConnectKey = signingAssets.appStoreConnectKey
            }

            let temporaryDirectory = context.fileManager.temporaryDirectory.path
            let buildSettings = try await xcode.getBuildSettings(container: container, scheme: scheme, destination: destination)
            let productName = try buildSettings.require(.productName)
            let archivePath = temporaryDirectory/"Archive/\(productName).xcarchive"
            let exportPath = temporaryDirectory/"Export"
            let bundleID = try buildSettings.require(.bundleIdentifier)
            let buildShortVersion = try buildSettings.require(.version)

            // Look up the app on App Store Connect early so this step can fail early without performing other steps just to fail.
            let app = try await context.appStoreConnectAPI.getApp(bundleID: bundleID, key: appStoreConnectKey)

            var overrideProjectVersion: String?
            switch buildNumberStrategy {
            case .project:
                // Use whatever value the project has defined
                break

            case .random(let length):
                let random = String.random(length: length)
                overrideProjectVersion = random

            case .date(let format):
                let formatter = DateFormatter()
                formatter.dateFormat = format
                let dateString = formatter.string(from: Date())
                overrideProjectVersion = dateString

            case .autoIncrementingInteger:
                if let latestBuild = try await context.appStoreConnectAPI.getLatestBuild(appID: app.id, key: appStoreConnectKey),
                   let latestBuildNumber = Int(latestBuild.attributes.version),
                   let projectBuildNumber = buildSettings[.build].flatMap(Int.init) {
                    if projectBuildNumber <= latestBuildNumber {
                        let newBuildNumber = latestBuildNumber + 1
                        logger.info("Latest build number (\(latestBuildNumber)) is greater than project build number (\(projectBuildNumber)). Overriding project build number setting to \(newBuildNumber).")
                        overrideProjectVersion = "\(newBuildNumber)"
                    }
                } else {
                    overrideProjectVersion = "1"
                }
            }

            // Restore the current directory
            let currentDirectory = context.fileManager.currentDirectoryPath
            defer {
                do {
                    try context.fileManager.changeCurrentDirectory(currentDirectory)
                } catch {
                    logger.error("Failed to change back to the previous current directory \(currentDirectory)")
                }
            }

            // Call xcodebuild from the project's parent directory
            let enclosingDirectory = try container.path.removingLastPathComponent
            if currentDirectory != enclosingDirectory {
                try context.fileManager.changeCurrentDirectory(enclosingDirectory)
            }

            // Archive the build
            try await xcode.archive(
                container: container,
                scheme: scheme,
                configuration: .release,
                destination: destination,
                archivePath: archivePath,
                codeSignStyle: .manual(profile: profile),
                projectVersion: overrideProjectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )

            // Export the archive
            try await xcode.exportArchive(
                archivePath,
                to: exportPath,
                allowProvisioningUpdates: false,
                options: .init(
                    method: .appStore,
                    // NOTE: Uploading to App Store Connect via xcodebuild is preferred, but it isn't working with ASC authentication keys.
                    // As a workaround, we'll upload using the UploadToAppStoreConnect step (uses altool as of now.)
                    export: .appStore(uploadToAppStore: false),
                    // TODO: We should be able to derive the the bundle id and profile uuid somehow
                    signing: .manual(provisioningProfiles: [
                        bundleID: profile.uuid,

                        // TODO: Do we need to specify the app clip's bundle identifier and provisioning profile in order for it to be picked up here?
                        // How would we detect that an app has an app clip? I think it's probably the wrong move to open the .ipa and check if there's an AppClips directory.
                        // https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_parent-application-identifiers
                        // https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_associated-appclip-app-identifiers
                        // https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_on-demand-install-capable

                    ]),
                    teamID: profile.requireTeamIdentifier()
                ),
                appStoreConnectKey: appStoreConnectKey,
                xcbeautify: xcbeautify
            )

            let ipa = exportPath/"\(productName).ipa"

            let uploadOutput = try await appStoreConnect.upload(
                ipa: ipa,
                container: container,
                scheme: scheme,
                bundleID: bundleID,
                bundleVersion: overrideProjectVersion,
                bundleShortVersion: buildShortVersion,
                appStoreConnectKey: appStoreConnectKey
            )

            let output = Output(
                archive: archivePath,
                export: exportPath,
                ipa: ipa,
                uploadedBuildVersion: buildShortVersion,
                uploadedBuildNumber: uploadOutput.buildNumber
            )

            context.outputs.archiveExportUpload = output
            return output
        }
    }
}

public extension Xcode {
    @discardableResult
    func archiveExportUpload(
        project: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .generic(platform: .iOS),
        profile: ProvisioningProfile,
        appStoreConnectKey: AppStoreConnect.Key,
        buildNumberStrategy: ArchiveExportUpload.BuildNumberStrategy = .autoIncrementingInteger,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ArchiveExportUpload.Output {
        try await run(
            ArchiveExportUpload(
                project: project,
                scheme: scheme,
                destination: destination,
                profile: profile,
                appStoreConnectKey: appStoreConnectKey,
                buildNumberStrategy: buildNumberStrategy,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @_disfavoredOverload
    @discardableResult
    func archiveExportUpload(
        workspace: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .generic(platform: .iOS),
        profile: ProvisioningProfile,
        appStoreConnectKey: AppStoreConnect.Key,
        buildNumberStrategy: ArchiveExportUpload.BuildNumberStrategy = .autoIncrementingInteger,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ArchiveExportUpload.Output {
        try await run(
            ArchiveExportUpload(
                workspace: workspace,
                scheme: scheme,
                destination: destination,
                profile: profile,
                appStoreConnectKey: appStoreConnectKey,
                buildNumberStrategy: buildNumberStrategy,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @discardableResult
    func archiveExportUpload(
        project: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .generic(platform: .iOS),
        buildNumberStrategy: ArchiveExportUpload.BuildNumberStrategy = .autoIncrementingInteger,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ArchiveExportUpload.Output {
        try await run(
            ArchiveExportUpload(
                project: project,
                scheme: scheme,
                destination: destination,
                buildNumberStrategy: buildNumberStrategy,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @_disfavoredOverload
    @discardableResult
    func archiveExportUpload(
        workspace: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .generic(platform: .iOS),
        buildNumberStrategy: ArchiveExportUpload.BuildNumberStrategy = .autoIncrementingInteger,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ArchiveExportUpload.Output {
        try await run(
            ArchiveExportUpload(
                workspace: workspace,
                scheme: scheme,
                destination: destination,
                buildNumberStrategy: buildNumberStrategy,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }
}

extension OutputValues {
    private enum Key: OutputKey {
        static var defaultValue: Xcode.ArchiveExportUpload.Output?
    }

    var archiveExportUpload: Xcode.ArchiveExportUpload.Output? {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}
