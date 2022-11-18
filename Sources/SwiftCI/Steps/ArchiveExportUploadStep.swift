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
        guard let bundleID = try getBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", fromXcodeProject: xcodeProject) else {
            throw StepError("Failed to get bundle id from \(xcodeProject)")
        }

        guard let productName = try getBuildSetting("PRODUCT_NAME", fromXcodeProject: xcodeProject) else {
            throw StepError("Failed to get product name from \(xcodeProject)")
        }

        let archivePath = context.temporaryDirectory/"Archive"
        let exportPath = context.temporaryDirectory/"Export"

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

        let uploadOutput = try await step(UploadToAppStoreConnect(
            ipa: exportPath/"\(productName).ipa",
            bundleID: bundleID,
            authentication: .apiKey(
                authentication.id,
                issuerID: authentication.issuerID,
                keyDirectory: authentication.key.removingLastPathComponent
            )
        ))

        return Output(
            archive: archivePath,
            export: exportPath,
            uploadedBuildNumber: uploadOutput.buildNumber
        )
    }
}

extension Step {
    func getBuildSetting(_ buildSetting: String, fromXcodeProject xcodeProject: String, quiet: Bool = false) throws -> String? {
        try context.shell("xcodebuild", "-project", xcodeProject, "-showBuildSettings", quiet: quiet)
            .components(separatedBy: "\n")
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(buildSetting) = ") })?
            .components(separatedBy: " = ")
            .last
    }
}

//public extension Step where Self == ArchiveExportUploadStep {
//    static func archiveExportUpload(
//        appBundleID: String,
//        scheme: String,
//        profile: ProvisioningProfile,
//        authentication: XcodeBuild.Authentication,
//        archivePath: String? = nil,
//        exportPath: String? = nil
//    ) -> ArchiveExportUploadStep {
//        ArchiveExportUploadStep(
//            appBundleID: appBundleID,
//            scheme: scheme,
//            profile: profile,
//            authentication: authentication,
//            archivePath: archivePath ?? context.temporaryDirectory + "Archive",
//            exportPath: exportPath ?? context.temporaryDirectory + "Export"
//        )
//    }
//}
