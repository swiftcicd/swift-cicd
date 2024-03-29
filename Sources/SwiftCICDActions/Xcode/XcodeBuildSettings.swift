import Foundation
import SwiftCICDCore

public extension XcodeBuild {
    struct Settings {
        public let settings: [String: String]

        public struct Setting: ExpressibleByStringLiteral {
            public let key: String

            public init(_ key: String) {
                self.key = key
            }

            public init(stringLiteral value: String) {
                self.key = value
            }
        }

        public subscript(setting: Setting) -> String? {
            settings[setting.key]
        }

        public func require(_ setting: Setting, file: StaticString = #fileID, line: UInt = #line) throws -> String {
            guard let value = settings[setting.key] else {
                throw SettingError(setting: setting.key, file: file, line: line)
            }

            return value
        }

        struct SettingError: LocalizedError, CustomStringConvertible {
            let setting: String
            let file: StaticString
            let line: UInt

            var description: String {
                "Required Xcode project setting '\(setting)' not found. (file: \(file), line: \(line))"
            }

            var errorDescription: String? {
                description
            }
        }

        init(
            container: Xcode.Container? = nil,
            scheme: String? = nil,
            configuration: XcodeBuild.Configuration? = nil,
            destination: XcodeBuild.Destination? = nil,
            sdk: XcodeBuild.SDK? = nil,
            derivedDataPath: String? = nil
        ) async throws {
            var command = ShellCommand("xcodebuild")
            try command.append(container?.flag)
            command.append("-scheme", ifLet: scheme)
            command.append("-configuration", ifLet: configuration?.name)
            command.append("-destination", ifLet: destination?.value)
            command.append("-sdk", ifLet: sdk?.value)
            command.append("-showBuildSettings")
            command.append("-derivedDataPath", ifLet: derivedDataPath)
            let output = try await ContextValues.current.shell(command, quiet: true)
            self.init(showBuildSettingsOutput: output)
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

            let settings = Dictionary(keyValuePairs, uniquingKeysWith: { first, second in first })
            self.init(buildSettings: settings)
        }

        init(buildSettings: [String: String]) {
            self.settings = buildSettings
        }
    }
}

public extension XcodeBuild.Settings.Setting {
    /// `PRODUCT_NAME`
    static let productName: Self = "PRODUCT_NAME"

    /// `FULL_PRODUCT_NAME`
    static let fullProductName: Self = "FULL_PRODUCT_NAME"

    /// `PRODUCT_BUNDLE_IDENTIFIER`
    static let bundleIdentifier: Self = "PRODUCT_BUNDLE_IDENTIFIER"

    /// `MARKETING_VERSION`
    /// The version string found in an Xcode target's Identity section under the General tab (in the Version field.)
    /// Also known as CFBundleShortVersionString.
    static let version: Self = "MARKETING_VERSION"

    /// `CURRENT_PROJECT_VERSION`
    /// The build string found in an Xcode target's Identity section under the General tab (in the Build field.)
    /// Also known as CFBundleVersion.
    static let build: Self = "CURRENT_PROJECT_VERSION"

    /// `SOURCE_ROOT`
    static let sourceRoot: Self = "SOURCE_ROOT"

    /// `CONFIGURATION_BUILD_DIR`
    static let configurationBuildDirectory: Self = "CONFIGURATION_BUILD_DIR"
}

public extension Xcode {
    func getBuildSettings(
        project: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = nil,
        destination: XcodeBuild.Destination? = nil,
        sdk: XcodeBuild.SDK? = nil,
        derivedDataPath: String? = nil
    ) async throws -> XcodeBuild.Settings {
        try await getBuildSettings(
            container: project.map(Xcode.Container.project),
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            sdk: sdk,
            derivedDataPath: derivedDataPath
        )
    }

    @_disfavoredOverload
    func getBuildSettings(
        workspace: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = nil,
        destination: XcodeBuild.Destination? = nil,
        sdk: XcodeBuild.SDK? = nil,
        derivedDataPath: String? = nil
    ) async throws -> XcodeBuild.Settings {
        try await getBuildSettings(
            container: workspace.map(Xcode.Container.workspace),
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            sdk: sdk,
            derivedDataPath: derivedDataPath
        )
    }

    internal func getBuildSettings(
        container: Xcode.Container? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = nil,
        destination: XcodeBuild.Destination? = nil,
        sdk: XcodeBuild.SDK? = nil,
        derivedDataPath: String? = nil
    ) async throws -> XcodeBuild.Settings {
        let (container, scheme) = try await caller.getDefault(container: container, scheme: scheme)
        return try await XcodeBuild.Settings(
            container: container,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            sdk: sdk,
            derivedDataPath: derivedDataPath
        )
    }
}
