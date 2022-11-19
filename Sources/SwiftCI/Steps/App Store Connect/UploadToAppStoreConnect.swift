import Foundation

public struct UploadToAppStoreConnect: Step {
    /// Path to .ipa file.
    let ipa: String

    /// The xcode project the .ipa file was exported from.
    var xcodeProject: String?

    /// The package type,
    var type: PackageType

    /// Required with --notarize-app and --notarization-history when a user account is associated with multiple providers and using username/password authentication.
    /// You can use the --list-providers command to retrieve the providers associated with your accounts. You may instead use --asc-provider or --asc-public-id.
    var ascPublicID: String?

    /// The Apple ID of the app to be uploaded.
    var appAppleID: String?

    /// The CFBundleVersion of the app to be uploaded.
    var bundleVersion: String?

    /// The CFBundleShortVersionString of the app to be uploaded.
    var bundleShortVersion: String?

    /// The CFBundleIdentifier of the app to be uploaded.
    var bundleID: String?

    /// The type of authentication to use.
    let authentication: Authentication

    var showProgress: Bool
    var verbose: Bool

    public struct Output {
        public let buildNumber: String
    }

    public enum Authentication {
        // TODO: Username/Password authentication

        /// apiKey. Required for JWT authentication (in lieu of username/password).
        ///
        /// This option will search the following directories in sequence for a private key file with the name of 'AuthKey_<api_key>.p8': './private_keys', '~/private_keys', '~/.private_keys', and '~/.appstoreconnect/private_keys'.
        ///
        /// Additionally, you can set the environment variable $API_PRIVATE_KEYS_DIR or a user default API_PRIVATE_KEYS_DIR to specify the directory where your AuthKey file is located.
        ///
        /// Issuer ID. Required if --apiKey is specified.
        case apiKey(String, issuerID: String, keyDirectory: String)
    }

    public enum PackageType: Argument {
        case macOS
        case iOS
        case tvOS

        public var argument: String {
            switch self {
            case .macOS: return "macos"
            case .iOS: return "ios"
            case .tvOS: return "appletvos"
            }
        }
    }

    public init(
        ipa: String,
        xcodeProject: String? = nil,
        type: PackageType = .iOS,
        ascPublicID: String? = nil,
        appAppleID: String? = nil,
        bundleVersion: String? = nil,
        bundleShortVersion: String? = nil,
        bundleID: String? = nil,
        authentication: Authentication,
        showProgress: Bool = false,
        verbose: Bool = false
    ) {
        self.ipa = ipa
        self.xcodeProject = xcodeProject
        self.type = type
        self.ascPublicID = ascPublicID
        self.appAppleID = appAppleID
        self.bundleVersion = bundleVersion
        self.bundleShortVersion = bundleShortVersion
        self.bundleID = bundleID
        self.authentication = authentication
        self.showProgress = showProgress
        self.verbose = verbose
    }

    private func newALToolCommand() -> Command {
        if case .apiKey(let apiKey, let issuerID, let keyDirectory) = authentication {
            return Command("env", "API_PRIVATE_KEYS_DIR=\(keyDirectory)", "xcrun", "altool", "--apiKey", apiKey, "--apiIssuer", issuerID)
        } else {
            return Command("xcrun", "altool")
        }
    }

    public func run() async throws -> Output {
        guard ipa.hasSuffix(".ipa"), let ipaName = ipa.lastPathComponent else {
            throw StepError("Expected ipa to be the path to an .ipa, but got \(ipa) instead.")
        }

        var appAppleID = self.appAppleID
        var bundleVersion = self.bundleVersion
        var bundleShortVersion = self.bundleShortVersion
        var bundleID = self.bundleID

        distributionSummary: if bundleVersion == nil || bundleShortVersion == nil || bundleID == nil {
            guard let distributionSummary = getDistributionSummary() else {
                logger.debug("Couldn't detect bundleVersion, bundleShortVersion, or bundleID because distribution summary couldn't be found.")
                break distributionSummary
            }

            guard let summary = distributionSummary.summaries[ipaName]?.first else {
                logger.debug("Couldn't detect bundleVersion, bundleShortVersion, or bundleID because distribution summary for \(ipaName) couldn't be found.")
                break distributionSummary
            }

            if bundleVersion == nil {
                bundleVersion = summary.buildNumber
                logger.debug("Detected bundle version (build number) from distribution summary.")
            }

            if bundleShortVersion == nil {
                bundleShortVersion = summary.versionNumber
                logger.debug("Detected bundle short version from distribution summary.")
            }

            if bundleID == nil {
                bundleID = summary.entitlements.bundleID
                logger.debug("Detected bundle id from distribution summary.")
            }
        }

        versions: if bundleShortVersion == nil || bundleVersion == nil {
            guard let project = xcodeProject ?? context.xcodeProject else {
                logger.debug("Couldn't detect bundle short version or bundle version because xcode project wasn't specified explicitly or contextually.")
                break versions
            }

            guard let buildSettings = try? getBuildSettings(fromXcodeProject: project) else {
                logger.debug("Couldn't detect bundle short version or bundle version because couldn't get build settings from Xcode project.")
                break versions
            }

            if bundleShortVersion == nil {
                if let projectBundleShortVersion = buildSettings.version {
                    bundleShortVersion = projectBundleShortVersion
                    logger.debug("Detected bundle short version from xcode project")
                } else {
                    logger.debug("Couldn't detect bundle short version because the xcode project is missing the MARKETING_VERSION build setting.")
                }
            }

            if bundleVersion == nil {
                if let projectBundleVersion = buildSettings.build {
                    bundleVersion = projectBundleVersion
                    logger.debug("Detected bundle version from xcode project")
                } else {
                    logger.debug("Couldn't detect bundle version because the xcode project is missing the MARKETING_VERSION build setting.")
                }
            }
        }

        guard let bundleVersion else { throw StepError("Missing bundleVersion") }
        guard let bundleShortVersion else { throw StepError("Missing bundleShortVersion") }
        guard let bundleID else { throw StepError("Missing bundleID") }

        if appAppleID == nil {
            let apps = try await listApps()
            if let matchingApp = apps.applications.first(where: { $0.bundleID == bundleID }) {
                appAppleID = matchingApp.appleID
                logger.debug("Detected app Apple ID from listing apps.")
            } else {
                logger.debug("Couldn't detect app Apple ID from listing apps.")
            }
        }

        guard let appAppleID else { throw StepError("Missing appAppleID") }

        logger.info("Uploading \(ipaName) version \(bundleShortVersion) build \(bundleVersion)")

        // TODO: Allow for the build version to be specified by an environment variable. (This could be useful on a system like Bitrise that has its own build numbers.)
        // Then a build number could be specified from the outside. It would always win out over what's detected internally.

        // TODO: Should we use --validate-package before --upload-package and have a chance at resolving the build number error?

        var altool = newALToolCommand()
        altool.add(
            "--upload-package", ipa,
            "--type", type,
            "--apple-id", appAppleID,
            "--bundle-version", bundleVersion,
            "--bundle-short-version-string", bundleShortVersion,
            "--bundle-id", bundleID
        )

        if let ascPublicID {
            altool.add("--asc-public-id", ascPublicID)
        }

        if showProgress {
            altool.add("--show-progress")
        }

        if verbose {
            altool.add("--verbose")
        }

        try context.shell(altool)

        return Output(buildNumber: bundleVersion)
    }
}

extension UploadToAppStoreConnect {
    struct ListAppsReponse: Decodable {
        let applications: [App]

        struct App: Decodable {
            let appleID: String
            let bundleID: String

            enum CodingKeys: String, CodingKey {
                case appleID = "AppleID"
                case bundleID = "ReservedBundleIdentifier"
            }
        }
    }

    func listApps() async throws -> ListAppsReponse {
        var listApps = newALToolCommand()
        listApps.add("--list-apps", "--output-format", "json")
        let responseString = try context.shell(listApps, quiet: true)
        let responseData = Data(responseString.utf8)
        let response = try JSONDecoder().decode(ListAppsReponse.self, from: responseData)
        return response
    }
}

extension UploadToAppStoreConnect {
    struct DistributionSummary: Decodable {
        let summaries: [String: [ProductSummary]]

        struct ProductSummary: Decodable {
            let buildNumber: String
            let versionNumber: String
            let entitlements: Entitlements

            struct Entitlements: Decodable {
                let applicationIdentifier: String
                let teamIdentifier: String

                enum CodingKeys: String, CodingKey {
                    case applicationIdentifier = "application-identifier"
                    case teamIdentifier = "com.apple.developer.team-identifier"
                }

                var bundleID: String? {
                    let prefix = teamIdentifier + "."

                    guard applicationIdentifier.hasPrefix(prefix) else {
                        return nil
                    }

                    return String(applicationIdentifier.dropFirst(prefix.count))
                }
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            summaries = try container.decode([String: [ProductSummary]].self)
        }
    }

    func getDistributionSummary() -> DistributionSummary? {
        var distributionSummaryPath: String

        if ipa.hasSuffix(".ipa") {
            distributionSummaryPath = ipa
                .components(separatedBy: "/")
                .dropLast()
                .joined(separator: "/")
                + "/"
        } else {
            distributionSummaryPath = ipa
        }

        distributionSummaryPath += "DistributionSummary.plist"

        guard let contents = context.fileManager.contents(atPath: distributionSummaryPath) else {
            return nil
        }

        do {
            let distributionSummary = try PropertyListDecoder().decode(DistributionSummary.self, from: contents)
            return distributionSummary
        } catch {
            logger.error("Failed to decode distribution summary: \(error)")
            return nil
        }
    }
}
