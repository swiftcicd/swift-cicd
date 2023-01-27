import Foundation
import SwiftCICore

public struct ArchiveExportUploadXcodeProject: Action {
    var xcodeProject: String?
    var scheme: String?
    let profile: ProvisioningProfile
    let appStoreConnectKey: AppStoreConnect.Key
    let buildNumberStrategy: BuildNumberStrategy
    let xcbeautify: Bool

    public enum BuildNumberStrategy {
        // TODO: Add a semantic version strategy
        case autoIncrementingInteger
        case date(format: String = "yy.MM.dd.HH.mm")
        case random(length: Int)
        case project
    }

    public init(
        xcodeProject: String? = nil,
        scheme: String? = nil,
        profile: ProvisioningProfile,
        appStoreConnectKey: AppStoreConnect.Key,
        buildNumberStrategy: BuildNumberStrategy = .autoIncrementingInteger,
        xcbeautify: Bool = false
    ) {
        self.xcodeProject = xcodeProject
        self.scheme = scheme
        self.profile = profile
        self.appStoreConnectKey = appStoreConnectKey
        self.buildNumberStrategy = buildNumberStrategy
        self.xcbeautify = xcbeautify
    }

    public struct Output {
        public let archive: String
        public let export: String
        public let uploadedBuildNumber: String
    }

    public func run() async throws -> Output {
        let xcodeProject = try xcodeProject ?? context.xcodeProject

        guard let xcodeProject else {
            throw ActionError("Missing Xcode project. Either pass an explicit xcodeProject or call this step from an XcodeProjectWorkflow.")
        }

        let temporaryDirectory = context.fileManager.temporaryDirectory.path
        let buildSettings = try getBuildSettings(fromXcodeProject: xcodeProject, scheme: scheme)
        let productName = try buildSettings.require(.productName)
        let archivePath = temporaryDirectory/"Archive/\(productName).xcarchive"
        let exportPath = temporaryDirectory/"Export"
        let bundleID = try buildSettings.require(.bundleIdentifier)

        // Look up the app on App Store Connect early so this step can fail early without performing other steps just to fail.
        let apps = try await context.appStoreConnect.getApps(key: appStoreConnectKey)
        guard let app = apps.first(where: { $0.attributes.bundleId == bundleID }) else {
            throw ActionError("No app with bundle id \(bundleID) found on App Store Connect. Either the bundle id isn't correct or the app hasn't been created on App Store Connect yet.")
        }

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
            if let latestBuild = try await context.appStoreConnect.getLatestBuild(appID: app.id, key: appStoreConnectKey),
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
        let sourceRoot = xcodeProject.removingLastPathComponent
        if currentDirectory != sourceRoot {
            try context.fileManager.changeCurrentDirectory(sourceRoot)
        }

        // Archive the build
        try await buildXcodeProject(
            xcodeProject,
            scheme: scheme,
            configuration: .release,
            destination: .generic(platform: .iOS),
            archivePath: archivePath,
            codeSignStyle: .manual(profile: profile),
            projectVersion: overrideProjectVersion,
            xcbeautify: xcbeautify
        )

        // Export the archive
        try await exportXcodeProjectArchive(
            xcodeProject,
            exportArchive: archivePath,
            to: exportPath,
            allowProvisioningUpdates: false,
            options: .init(
                method: .appStore,
                // NOTE: Uploading to App Store Connect via xcodebuild is preferred, but it isn't working with ASC authentication keys.
                // As a workaround, we'll upload using the UploadToAppStoreConnect step (uses altool as of now.)
                export: .appStore(uploadToAppStore: false),
                // TODO: We should be able to derive the the bundle id and profile uuid somehow
                signing: .manual(provisioningProfiles: [bundleID: profile.uuid]),
                teamID: profile.requireTeamIdentifier()
            ),
            appStoreConnectKey: appStoreConnectKey,
            xcbeautify: xcbeautify
        )

        let uploadOutput = try await uploadToAppStoreConnect(
            ipa: exportPath/"\(productName).ipa",
            bundleID: bundleID,
            bundleVersion: overrideProjectVersion,
            appStoreConnectKey: appStoreConnectKey
        )

        return Output(
            archive: archivePath,
            export: exportPath,
            uploadedBuildNumber: uploadOutput.buildNumber
        )
    }
}

public extension Action {
    func archiveExportUpload(
        xcodeProject: String? = nil,
        scheme: String? = nil,
        profile: ProvisioningProfile,
        appStoreConnectKey: AppStoreConnect.Key,
        buildNumberStrategy: ArchiveExportUploadXcodeProject.BuildNumberStrategy = .autoIncrementingInteger,
        xcbeautify: Bool = false
    ) async throws {
        try await action(ArchiveExportUploadXcodeProject(
            xcodeProject: xcodeProject,
            scheme: scheme,
            profile: profile,
            appStoreConnectKey: appStoreConnectKey,
            buildNumberStrategy: buildNumberStrategy,
            xcbeautify: xcbeautify
        ))
    }
}
