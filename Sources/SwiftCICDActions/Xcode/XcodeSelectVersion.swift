import SwiftCICDCore

extension Xcode {
    public struct Select: Action {
        public let name = "Select Xcode Version"

        private let version: String

        public init(version: String) {
            self.version = version
        }

        public func run() async throws {
            // Opting to use `xcodes` instead of just `xcode-select -s` so that
            // users can just specify a version of Xcode instead of a path.

            let xcodes = try await context.tools.xcodes
            let isInstalled = try await xcodes.isVersionInstalled(version)
            guard isInstalled else {
                let installedVersions = try await xcodes.listInstalledVersions()
                throw ActionError("Xcode \(version) is not installed. Available installations are:\n\(installedVersions)")
            }

            try await xcodes.select(version)
        }
    }
}

extension Xcode {
    public func select(version: String) async throws {
        try await run(Select(version: version))
    }
}

// Using `xcodes install` on a CI machine doesn't work because Apple requires a 2FA code.
// There are potential solutions to this by following what fastlane outlines here: https://docs.fastlane.tools/getting-started/ios/authentication/
// If we can figure out a way to do something similar to what fastlane spaceship is doing with storing
// an authenticated cookie and then injecting it into the calls to download Xcode inside of xcodes then
// we could potentially restore this functionality:

// Inside Xcode.Select:
//        private let installCredentials: InstallCredentials?
//
//        public struct InstallCredentials {
//            let appleID: String
//            let password: Secret
//            let useExperimentalUnxip: Bool
//
//            public init(appleID: String, password: Secret, useExperimentalUnxip: Bool = false) {
//                self.appleID = appleID
//                self.password = password
//                self.useExperimentalUnxip = useExperimentalUnxip
//            }
//        }
//        public init(_ version: String, installIfNeededUsing installCredentials: InstallCredentials? = nil) throws {
//            self.version = version
//            self.installCredentials = installCredentials
//        }
//
//        public func run() async throws {
//            let xcodes = try await context.tools.xcodes
//
//            let isInstalled = try await xcodes.isVersionInstalled(version)
//            if !isInstalled {
//                logger.warning("Xcode \(version) is not installed.")
//                let installedVersions = try await xcodes.listInstalledVersions()
//                logger.warning("Available installations are:\n\(installedVersions)")
//
//                guard let installCredentials else {
//                    throw ActionError("""
//                        Xcode \(version) is not installed and can't be selected. Try passing InstallCredentials \
//                        to this action to install that version of Xcode if it's available.
//                        """
//                    )
//                }
//
//                if try await !xcodes.isVersionListed(version) {
//                    logger.warning("Xcode \(version) isn't listed as available to install. Will attempt to install regardless.")
//                }
//
//                logger.info("Attempting to install Xcode \(version)")
//                try await xcodes.install(
//                    version,
//                    appleID: installCredentials.appleID,
//                    password: installCredentials.password,
//                    useExperimentalUnxip: installCredentials.useExperimentalUnxip
//                )
//            }
//
//            try await xcodes.select(version)
//        }

// Action extension:
//    public func select(
//        _ version: String,
//        installIfNeededUsing installCredentials: Xcode.Select.InstallCredentials? = nil
//    ) async throws {
//        try await run(Select(version, installIfNeededUsing: installCredentials))
//    }
