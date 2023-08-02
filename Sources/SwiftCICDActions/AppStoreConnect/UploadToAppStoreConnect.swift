import Foundation
import SwiftCICDCore

public struct UploadToAppStoreConnect: Action {
    /// Path to .ipa file.
    let ipa: String

    /// The Xcode project the .ipa file was exported from.
    var xcodeProject: String?

    /// The Xcode project scheme the .ipa file was exported from.
    var scheme: String?

    /// The package type,
    var type: PackageType

    /// The Apple ID of the app to be uploaded.
    var appAppleID: String?

    /// The CFBundleIdentifier of the app to be uploaded.
    var bundleID: String?

    /// The CFBundleVersion of the app to be uploaded.
    var bundleVersion: String?

    /// The CFBundleShortVersionString of the app to be uploaded.
    var bundleShortVersion: String?

    /// Required with --notarize-app and --notarization-history when a user account is associated with multiple providers and using username/password authentication.
    /// You can use the --list-providers command to retrieve the providers associated with your accounts. You may instead use --asc-provider or --asc-public-id.
    var ascPublicID: String?

    /// The type of authentication to use.
    let appStoreConnectKey: AppStoreConnect.Key

    public struct Output {
        public let buildNumber: String
    }

    public enum PackageType: String {
        case macOS = "macos"
        case iOS = "ios"
        case tvOS = "appletvos"
    }

    init(
        ipa: String,
        xcodeProject: String? = nil,
        scheme: String? = nil,
        type: PackageType = .iOS,
        appAppleID: String? = nil,
        bundleID: String? = nil,
        bundleVersion: String? = nil,
        bundleShortVersion: String? = nil,
        ascPublicID: String? = nil,
        appStoreConnectKey: AppStoreConnect.Key
    ) {
        self.ipa = ipa
        self.xcodeProject = xcodeProject
        self.scheme = scheme
        self.type = type
        self.appAppleID = appAppleID
        self.bundleID = bundleID
        self.bundleVersion = bundleVersion
        self.bundleShortVersion = bundleShortVersion
        self.ascPublicID = ascPublicID
        self.appStoreConnectKey = appStoreConnectKey
    }

    public func run() async throws -> Output {
        // TODO: Allow for the build version to be specified by an environment variable. (This could be useful on a system like Bitrise that has its own build numbers.)
        // Then a build number could be specified from the outside. It would always win out over what's detected internally.

        guard ipa.hasSuffix(".ipa") else {
            throw ActionError("Expected ipa to be the path to an .ipa, but got \(ipa) instead.")
        }

        var appAppleID = self.appAppleID
        var bundleVersion = self.bundleVersion
        var bundleShortVersion = self.bundleShortVersion
        var bundleID = self.bundleID

        versions: if bundleShortVersion == nil || bundleVersion == nil || bundleID == nil {
            guard let project = try xcodeProject ?? context.xcodeProject else {
                logger.debug("Couldn't detect bundle short version or bundle version because Xcode project wasn't specified explicitly or contextually.")
                break versions
            }

            guard let buildSettings = try? await xcode.getBuildSettings(project: project, scheme: scheme) else {
                logger.debug("Couldn't detect bundle short version or bundle version because couldn't get build settings from Xcode project.")
                break versions
            }

            if bundleShortVersion == nil {
                if let projectBundleShortVersion = buildSettings[.version] {
                    bundleShortVersion = projectBundleShortVersion
                    logger.debug("Detected bundle short version from xcode project: \(projectBundleShortVersion)")
                } else {
                    logger.debug("Couldn't detect bundle short version from Xcode project build settings.")
                }
            }

            if bundleVersion == nil {
                if let projectBundleVersion = buildSettings[.build] {
                    bundleVersion = projectBundleVersion
                    logger.debug("Detected bundle version from xcode project: \(projectBundleVersion)")
                } else {
                    logger.debug("Couldn't detect bundle version from Xcode project build settings.")
                }
            }

            if bundleID == nil {
                if let projectBundleID = buildSettings[.bundleIdentifier] {
                    bundleID = projectBundleID
                    logger.debug("Detected bundle id from xcode project: \(projectBundleID)")
                } else {
                    logger.debug("Couldn't detect bundle version from Xcode project build settings.")
                }
            }
        }

        guard let bundleVersion else { throw ActionError("Missing bundleVersion") }
        guard let bundleShortVersion else { throw ActionError("Missing bundleShortVersion") }
        guard let bundleID else { throw ActionError("Missing bundleID") }

        let apps = try await context.appStoreConnectAPI.getApps(key: appStoreConnectKey)
        guard let app = apps.first(where: { $0.attributes.bundleId == bundleID }) else {
            throw ActionError("No app with bundle id \(bundleID) found on App Store Connect. Either the bundle id isn't correct or the app hasn't been created on App Store Connect yet.")
        }

        if appAppleID == nil {
            appAppleID = app.id
            logger.debug("Detected app Apple ID from App Store Connect: \(app.id)")
        }

        guard let appAppleID else { throw ActionError("Missing appAppleID") }

        logger.info("""
            Uploading \(ipa.lastPathComponent ?? ipa) to App Store Connect:
             - App ID: \(appAppleID)
             - Bundle ID: \(bundleID)
             - Version: \(bundleShortVersion)
             - Build: \(bundleVersion)
            """
        )

        try await shell("""
            env API_PRIVATE_KEYS_DIR=\(appStoreConnectKey.path.removingLastPathComponent) \
            xcrun altool \
            --apiKey \(appStoreConnectKey.id) \
            --apiIssuer \(appStoreConnectKey.issuerID) \
            --upload-package \(ipa) \
            --type \(type.rawValue) \
            --apple-id \(appAppleID) \
            --bundle-version \(bundleVersion) \
            --bundle-short-version-string \(bundleShortVersion) \
            --bundle-id \(bundleID)
            """
        )

        return Output(buildNumber: bundleVersion)
    }
}

public extension AppStoreConnect {
    func upload(
        ipa: String,
        xcodeProject: String? = nil,
        scheme: String? = nil,
        type: UploadToAppStoreConnect.PackageType = .iOS,
        appAppleID: String? = nil,
        bundleID: String? = nil,
        bundleVersion: String? = nil,
        bundleShortVersion: String? = nil,
        ascPublicID: String? = nil,
        appStoreConnectKey: AppStoreConnect.Key
    ) async throws -> UploadToAppStoreConnect.Output {
        try await run(UploadToAppStoreConnect(
            ipa: ipa,
            xcodeProject: xcodeProject,
            scheme: scheme,
            type: type,
            appAppleID: appAppleID,
            bundleID: bundleID,
            bundleVersion: bundleVersion,
            bundleShortVersion: bundleShortVersion,
            ascPublicID: ascPublicID,
            appStoreConnectKey: appStoreConnectKey
        ))
    }
}
