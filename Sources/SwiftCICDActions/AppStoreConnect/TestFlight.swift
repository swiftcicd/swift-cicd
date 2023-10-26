import Foundation
import SwiftCICDCore

extension AppStoreConnect {
    public struct AddBuildToTestFlightGroups: Action {
        let container: Xcode.Container?
        let scheme: String?
        let buildID: String?
        let bundleID: String?
        let appStoreConnectKey: AppStoreConnect.Key
        let groups: [String]

        public init(
            project: String? = nil,
            scheme: String? = nil,
            buildID: String? = nil,
            bundleID: String? = nil,
            appStoreConnectKey: AppStoreConnect.Key,
            groups: String...
        ) {
            self.container = project.map { .project($0) }
            self.scheme = scheme
            self.buildID = buildID
            self.bundleID = bundleID
            self.appStoreConnectKey = appStoreConnectKey
            self.groups = groups
        }

        @_disfavoredOverload
        public init(
            workspace: String? = nil,
            scheme: String? = nil,
            buildID: String? = nil,
            bundleID: String? = nil,
            appStoreConnectKey: AppStoreConnect.Key,
            groups: String...
        ) {
            self.container = workspace.map { .workspace($0) }
            self.scheme = scheme
            self.buildID = buildID
            self.bundleID = bundleID
            self.appStoreConnectKey = appStoreConnectKey
            self.groups = groups
        }

        public func run() async throws {
            let (container, scheme) = try await getDefault(container: container, scheme: scheme)
            var bundleID = self.bundleID
            var buildID = self.buildID

            if buildID == nil {
                logger.debug("Detecting build id...")

                if bundleID == nil {
                    logger.debug("Detecting bundle id from build settings...")

                    let buildSettings = try await xcode.getBuildSettings(
                        container: container,
                        scheme: scheme
                    )

                    bundleID = try buildSettings.require(.bundleIdentifier)
                }

                guard let bundleID else {
                    throw ActionError("Missing bundle id")
                }

                logger.debug("Detected bundle id: \(bundleID)")

                let app = try await context.appStoreConnectAPI.getApp(
                    bundleID: bundleID,
                    key: appStoreConnectKey
                )

                guard let build = try await context.appStoreConnectAPI.getLatestBuild(
                    appID: app.id,
                    key: appStoreConnectKey
                ) else {
                    throw ActionError("No builds found for app \(app.id) (\(bundleID)).")
                }

                logger.debug("Detected build id: \(build.id)")
                buildID = build.id
            }

            guard let buildID else {
                throw ActionError(
                    """
                    Cannot add build to TestFlight groups because the \
                    build ID either wasn't supplied or couldn't be determined.
                    """
                )
            }

            let groups = try await context.appStoreConnectAPI.getBetaGroups(
                key: appStoreConnectKey
            )

            let groupsToAdd = groups.filter { 
                self.groups.contains($0.attributes.name)
            }

            logger.info("Adding build \(buildID) to groups: \(groupsToAdd.map { "\($0.attributes.name) (\($0.id))" }.joined(separator: ", "))")

            try await context.appStoreConnectAPI.addBuild(
                id: buildID,
                toGroups: groupsToAdd.map(\.id),
                key: appStoreConnectKey
            )
        }
    }
}
