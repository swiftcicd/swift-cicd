import Foundation
import SwiftCICDCore

extension AppStoreConnect {
    public struct ValidateArchive: Action {
        public enum ValidationError: Error {
            case invalidDuplicate(previousBundleVersion: Int)
        }

        /// Path to .xcarchive file.
        let archive: String

        /// The package type.
        var type: PackageType

        /// Authentication.
        let appStoreConnectKey: AppStoreConnect.Key

        public init(
            archive: String,
            type: PackageType = .iOS,
            appStoreConnectKey: AppStoreConnect.Key
        ) {
            self.archive = archive
            self.type = type
            self.appStoreConnectKey = appStoreConnectKey
        }

        public func run() async throws {
            do {
                try await shell("""
                    env API_PRIVATE_KEYS_DIR=\(appStoreConnectKey.path.removingLastPathComponent) \
                    xcrun altool \
                    --apiKey \(appStoreConnectKey.id) \
                    --apiIssuer \(appStoreConnectKey.issuerID) \
                    --validate-app \
                    --file \(archive) \
                    --type \(type.rawValue)
                    """
                )
            } catch let shellError as ShellError {
                // Over time we can take a more sophisticated approach to parse known errors.
                // But for now, all I care about is the "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE" error.
                // So that's all I'm looking for.
                let lines = shellError.message.components(separatedBy: .newlines)
                for line in lines.reversed() {
                    let line = line.trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("previousBundleVersion = ") && line.hasSuffix(";") {
                        let number = line.components(separatedBy: " = ")[1].dropLast()
                        guard let int = Int(number) else {
                            continue
                        }

                        throw ValidationError.invalidDuplicate(previousBundleVersion: int)
                    }
                }

                throw shellError
            }
        }
    }
}

public extension AppStoreConnect {
    func validateArchive(
        _ archivePath: String,
        type: PackageType = .iOS,
        appStoreConnectKey: AppStoreConnect.Key
    ) async throws -> ValidateArchive.Output {
        try await run(
            ValidateArchive(
                archive: archivePath,
                type: type,
                appStoreConnectKey: appStoreConnectKey
            )
        )
    }
}
