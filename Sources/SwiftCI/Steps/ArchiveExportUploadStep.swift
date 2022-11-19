public struct ArchiveExportUpload: Step {

    let xcodeProject: String
    var scheme: String?
    let profile: ProvisioningProfile
    let authentication: XcodeBuild.Authentication

    public init(xcodeProject: String, scheme: String? = nil, profile: ProvisioningProfile, authentication: XcodeBuild.Authentication) {
        self.xcodeProject = xcodeProject
        self.scheme = scheme
        self.profile = profile
        self.authentication = authentication
    }

    public struct Output {
        public let archive: String
        public let export: String
        public let uploadedBuildNumber: String
    }

    public func run() async throws -> Output {
        let buildSettings = try getBuildSettings(fromXcodeProject: xcodeProject)

        guard let bundleID = buildSettings.bundleIdentifier else {
            throw StepError("Failed to get bundle id from \(xcodeProject)")
        }

        guard let productName = buildSettings.productName else {
            throw StepError("Failed to get product name from \(xcodeProject)")
        }

        let archivePath = context.temporaryDirectory/"Archive/\(productName).xcarchive"
        let exportPath = context.temporaryDirectory/"Export"

        // Restore the current directory
        let currentDirectory = context.fileManager.currentDirectoryPath
        defer {
            do {
                try context.fileManager.changeCurrentDirectory(to: currentDirectory)
            } catch {
                logger.error("Failed to change back to the previous current directory \(currentDirectory)")
            }
        }

        // Call xcodebuild from the project's parent directory
        let sourceRoot = xcodeProject.removingLastPathComponent
        if currentDirectory != sourceRoot {
            try context.fileManager.changeCurrentDirectory(to: sourceRoot)
        }

        try await step(.xcodebuild(
            buildScheme: scheme,
            configuration: .release,
            destination: .generic(platform: .iOS),
            archiveTo: archivePath,
            codeSignStyle: .manual(profile: profile)
        ))

        try await step(.xcodeBuild(
            exportArchive: archivePath,
            to: exportPath,
            allowProvisioningUpdates: false,
            options: .init(
                method: .appStore,
                // NOTE: Uploading to App Store Connect via xcodebuild is preferred, but it isn't working with ASC authentication keys.
                // As a workaround, we'll upload using the UploadToAppStoreConnect step (uses altool as of now.)
                export: .appStore(uploadToAppStore: false),
                signing: .manual(
                    provisioningProfiles: [bundleID: profile.uuid]
                ),
                teamID: profile.requireTeamIdentifier()
            ),
            authentication: authentication
        ))

        guard let appStoreConnectKey = AppStoreConnect.Key(id: authentication.id, issuerID: authentication.issuerID, path: authentication.key) else {
            throw StepError("Failed to create App Store Connect Key")
        }

        let uploadOutput = try await step(UploadToAppStoreConnect(
            ipa: exportPath/"\(productName).ipa",
            bundleID: bundleID,
            appStoreConnectKey: appStoreConnectKey
        ))

        return Output(
            archive: archivePath,
            export: exportPath,
            uploadedBuildNumber: uploadOutput.buildNumber
        )
    }
}

public struct XcodeProjectBuildSettings {
    let settings: [String: String]

    var productName: String? {
        settings["PRODUCT_NAME"]
    }

    var bundleIdentifier: String? {
        settings["PRODUCT_BUNDLE_IDENTIFIER"]
    }

    /// The version string found in an Xcode target's Identity section under the General tab (in the Version field.)
    /// Also known as CFBundleVersionShortString.
    var version: String? {
        settings["MARKETING_VERSION"]
    }

    /// The build string found in an Xcode target's Identity section under the General tab (in the Build field.)
    /// Also known as CFBundleVersion.
    var build: String? {
        settings["CURRENT_PROJECT_VERSION"]
    }

    init(showBuildSettingsOutput output: String) {
        let keyValuePairs = output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { line -> (key: String, value: String)? in
                guard let delimeterRange = line.range(of: " = ") else {
                    return nil
                }

                let key = String(line[line.startIndex..<delimeterRange.lowerBound])
                let value = String(line[delimeterRange.upperBound...])
                return (key, value)
            }

        settings = Dictionary(keyValuePairs, uniquingKeysWith: { first, second in first })
    }

    init(xcodeProject: String) throws {
        @Context(\.shell) var shell;
        let output = try shell("xcodebuild", "-project", xcodeProject, "-showBuildSettings", quiet: true)
        self.init(showBuildSettingsOutput: output)
    }
}

public extension Step {
    func getBuildSettings(fromXcodeProject xcodeProject: String) throws -> XcodeProjectBuildSettings {
        let output = try context.shell("xcodebuild", "-project", xcodeProject, "-showBuildSettings", quiet: true)
        return XcodeProjectBuildSettings(showBuildSettingsOutput: output)
    }
}
