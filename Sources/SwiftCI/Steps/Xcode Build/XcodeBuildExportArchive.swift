import Foundation

extension XcodeBuildStep {
    public struct ExportArchive: Step {
        public let name = "Xcode Build: Export Archive"

        /// Specifies the directory where any created archives will be placed, or the archive that should be exported.
        let archivePath: String
        /// Specifies the destination for the product exported from an archive.
        var exportPath: String?
        /// Specifies a path to a plist file that configures archive exporting.
        let exportOptionsPlist: String

        public init(archivePath: String, exportPath: String? = nil, exportOptionsPlist: String) {
            self.archivePath = archivePath
            self.exportPath = exportPath
            self.exportOptionsPlist = exportOptionsPlist
        }

        public init(archivePath: String, exportPath: String? = nil, exportOptions: Options) throws {
            self.archivePath = archivePath
            self.exportPath = exportPath
            let plist = try exportOptions.generatePList()
            let temporaryDirectory = Self.context.temporaryDirectory
            let plistPath = temporaryDirectory + "/exportOptions.plist"
            Self.context.fileManager.createFile(atPath: plistPath, contents: plist)
            self.exportOptionsPlist = plistPath
        }

        public func run() async throws -> String {
            var arguments = [
                "-exportArchive",
                "-archivePath", archivePath,
                "-exportOptionsPlist", exportOptionsPlist
            ]

            if let exportPath {
                arguments.append(contentsOf: [
                    "-exportPath", exportPath
                ])
            }

            return try context.shell("xcodebuild", arguments)
        }
    }
}

public extension Step where Self == XcodeBuildStep.ExportArchive {
    static func xcodeBuild(exportArchive archivePath: String, to exportPath: String? = nil, optionsPlist: String) -> XcodeBuildStep.ExportArchive {
        XcodeBuildStep.ExportArchive(archivePath: archivePath, exportPath: exportPath, exportOptionsPlist: optionsPlist)
    }

    static func xcodeBuild(exportArchive archivePath: String, to exportPath: String? = nil, options: XcodeBuildStep.ExportArchive.Options) throws -> XcodeBuildStep.ExportArchive {
        try XcodeBuildStep.ExportArchive(archivePath: archivePath, exportPath: exportPath, exportOptions: options)
    }
}

extension XcodeBuildStep.ExportArchive {
    public struct Options: Encodable {
        public enum Destination: String, Encodable {
            case export
            case upload
        }

        public enum InstallerAutomaticSelector: String {
            case developerIDInstaller = "Developer ID Installer"
            case macInstallterDistribution = "Mac Installer Distribution"
        }

        public enum AutomaticSelector: String, Encodable {
            case macAppDistribution = "Mac App Distribution"
            case iOSDistribution = "iOS Distribution"
            case iOSDeveloper = "iOS Developer"
            case developerIDApplication = "Developer ID Application"
            case appleDistribution = "Apple Distribution"
            case macDeveloper = "Mac Developer"
            case appleDevelopment = "Apple Development"
        }

        public enum SigningCertificate<Selector: RawRepresentable<String>>: Encodable {
            case certificate(name: String)
            case sha1(hash: String)
            case automatic(selector: Selector)

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .certificate(let name):
                    try container.encode(name)
                case .sha1(let hash):
                    try container.encode(hash)
                case .automatic(let selector):
                    try container.encode(selector.rawValue)
                }
            }
        }

        public enum Method: String, Encodable {
            case adHoc = "ad-hoc"
            case appStore = "app-store"
            case developerID = "developer-id"
            case development
            case enterprise
            case macApplication = "mac-application"
            case package
            case validation
        }

        public enum SigningStyle: String, Encodable {
            case manual
            case automatic
        }

        public enum Thinning: Encodable {
            case thinForAllVariants
            case thin(deviceIdentifier: String)

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .thinForAllVariants:
                    try container.encode("thin-for-all-variants")
                case .thin(let deviceIdentifier):
                    try container.encode(deviceIdentifier)
                }
            }
        }

        /// For non-App Store exports, should Xcode re-compile the app from bitcode? Defaults to true.
        var compileBitcode = true

        /// Determines whether the app is exported locally or uploaded to Apple. Options are export or upload. The available options vary based on the selected distribution method. Defaults to export.
        var destination: Destination = .export

        /// Reformat archive to focus on eligible target bundle identifier.
        var distributionBundleIdentifier: String?

        // TODO: Make this follow the behavior outlined in the documentation
        /// For non-App Store exports, if the app uses On Demand Resources and this is true, asset packs are embedded in the app bundle so that the app can be tested without a server to host asset packs.
        /// Defaults to true unless onDemandResourcesAssetPacksBaseURL is specified.
        var embedOnDemandResourcesAssetPacksInBundle = true

        /// For App Store exports, should Xcode generate App Store Information for uploading with iTMSTransporter? Defaults to false.
        var generateApStoreInformation = false

        /// If the app is using CloudKit, this configures the "com.apple.developer.icloud-container-environment" entitlement.
        /// Available options vary depending on the type of provisioning profile used, but may include: Development and Production.
        var iCloudContainerEnvironment: String? = nil

        /// For manual signing only. Provide a certificate name, SHA-1 hash, or automatic selector to use for signing. Automatic selectors allow Xcode to pick the newest installed certificate of a particular type.
        /// The available automatic selectors are "Developer ID Installer" and "Mac Installer Distribution". Defaults to an automatic certificate selector matching the current distribution method.
        var installerSigningCertificate: SigningCertificate<InstallerAutomaticSelector>? = nil

        /// Should Xcode manage the app's build number when uploading to App Store Connect? Defaults to true.
        var manageAppVersionAndBuildNumber = true

        /// For non-App Store exports, users can download your app over the web by opening your distribution manifest file in a web browser.
        /// To generate a distribution manifest, the value of this key should be a dictionary with three sub-keys: appURL, displayImageURL, fullSizeImageURL.
        /// The additional sub-key assetPackManifestURL is required when using on-demand resources.
        var manifest: [String: String]? = nil

        /// Describes how Xcode should export the archive. Available options: app-store, validation, ad-hoc, package, enterprise, development, developer-id, and mac-application.
        /// The list of options varies based on the type of archive. Defaults to development.
        var method: Method = .development

        /// For non-App Store exports, if the app uses On Demand Resources and embedOnDemandResourcesAssetPacksInBundle isn't true, this should be a base URL specifying where asset packs are going to be hosted.
        /// This configures the app to download asset packs from the specified URL.
        var onDemandResourcesAssetPacksBaseURL: String? = nil

        /// For manual signing only. Specify the provisioning profile to use for each executable in your app. Keys in this dictionary are the bundle identifiers of executables; values are the provisioning profile name or UUID to use.
        var provisioningProfiles: [String: String]? = nil

        /// For manual signing only. Provide a certificate name, SHA-1 hash, or automatic selector to use for signing. Automatic selectors allow Xcode to pick the newest installed certificate of a particular type.
        /// The available automatic selectors are "Mac App Distribution", "iOS Distribution", "iOS Developer", "Developer ID Application", "Apple Distribution", "Mac Developer", and "Apple Development".
        /// Defaults to an automatic certificate selector matching the current distribution method.
        var signingCertificate: SigningCertificate<AutomaticSelector>? = nil

        /// The signing style to use when re-signing the app for distribution. Options are manual or automatic.
        /// Apps that were automatically signed when archived can be signed manually or automatically during distribution, and default to automatic.
        /// Apps that were manually signed when archived must be manually signed during distribtion, so the value of signingStyle is ignored.
        var signingStyle: SigningStyle

        /// Should symbols be stripped from Swift libraries in your IPA? Defaults to true.
        var stripSwiftSymbols = true

        /// The Developer Portal team to use for this export. Defaults to the team used to build the archive.
        var teamID: String? = nil

        /// For non-App Store exports, should Xcode thin the package for one or more device variants?
        ///
        /// Available options:
        /// - nil (Xcode produces a non-thinned universal app),
        /// - thin-for-all-variants (Xcode produces a universal app and all available thinned variants),
        /// - or a model identifier for a specific device (e.g. "iPhone7,1").
        /// Defaults to nil.
        var thinning: Thinning? = nil

        /// For App Store exports, should the package include symbols? Defaults to true.
        var uploadSymbols = true

        // TODO: Create specific initializers for the semantics of the plist
        // manual signing (certain keys don't apply, certain ones are necessary)
        // automatic signing (certain keys don't apply, certain ones are necessary)

        public init(
            compileBitcode: Bool = true,
            destination: Destination,
            distributionBundleIdentifier: String? = nil,
            embedOnDemandResourcesAssetPacksInBundle: Bool = true,
            generateApStoreInformation: Bool = false,
            iCloudContainerEnvironment: String? = nil,
            installerSigningCertificate: SigningCertificate<InstallerAutomaticSelector>? = nil,
            manageAppVersionAndBuildNumber: Bool = true,
            manifest: [String : String]? = nil,
            method: Method,
            onDemandResourcesAssetPacksBaseURL: String? = nil,
            provisioningProfiles: [String : String]? = nil,
            signingCertificate: SigningCertificate<AutomaticSelector>? = nil,
            signingStyle: SigningStyle,
            stripSwiftSymbols: Bool = true,
            teamID: String? = nil,
            thinning: Thinning? = nil,
            uploadSymbols: Bool = true
        ) {
            self.compileBitcode = compileBitcode
            self.destination = destination
            self.distributionBundleIdentifier = distributionBundleIdentifier
            self.embedOnDemandResourcesAssetPacksInBundle = embedOnDemandResourcesAssetPacksInBundle
            self.generateApStoreInformation = generateApStoreInformation
            self.iCloudContainerEnvironment = iCloudContainerEnvironment
            self.installerSigningCertificate = installerSigningCertificate
            self.manageAppVersionAndBuildNumber = manageAppVersionAndBuildNumber
            self.manifest = manifest
            self.method = method
            self.onDemandResourcesAssetPacksBaseURL = onDemandResourcesAssetPacksBaseURL
            self.provisioningProfiles = provisioningProfiles
            self.signingCertificate = signingCertificate
            self.signingStyle = signingStyle
            self.stripSwiftSymbols = stripSwiftSymbols
            self.teamID = teamID
            self.thinning = thinning
            self.uploadSymbols = uploadSymbols
        }
    }
}

extension XcodeBuildStep.ExportArchive.Options {
    func generatePList() throws -> Data {
        try PropertyListEncoder().encode(self)
    }
}