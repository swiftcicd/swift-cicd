import Foundation
import SwiftCICore

public struct XcodeProjectBuildSettings {
    public let settings: [String: String]

    public struct BuildSetting: ExpressibleByStringLiteral {
        public let key: String

        public init(_ key: String) {
            self.key = key
        }

        public init(stringLiteral value: String) {
            self.key = value
        }
    }

    public subscript(setting: BuildSetting) -> String? {
        settings[setting.key]
    }

    public func require(_ setting: BuildSetting, file: StaticString = #fileID, line: UInt = #line) throws -> String {
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

    public init(xcodeProject: String) throws {
        let output = try ContextValues.current.shell("xcodebuild -project \(xcodeProject) -showBuildSettings", quiet: true)
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

public extension XcodeProjectBuildSettings.BuildSetting {
    /// `PRODUCT_NAME`
    static let productName: Self = "PRODUCT_NAME"

    /// `PRODUCT_BUNDLE_IDENTIFIER`
    static let bundleIdentifier: Self = "PRODUCT_BUNDLE_IDENTIFIER"

    /// `MARKETING_VERSION`
    /// The version string found in an Xcode target's Identity section under the General tab (in the Version field.)
    /// Also known as CFBundleVersionShortString.
    static let version: Self = "MARKETING_VERSION"

    /// `CURRENT_PROJECT_VERSION`
    /// The build string found in an Xcode target's Identity section under the General tab (in the Build field.)
    /// Also known as CFBundleVersion.
    static let build: Self = "CURRENT_PROJECT_VERSION"

    /// `SOURCE_ROOT`
    static let sourceRoot: Self = "SOURCE_ROOT"
}

public extension Action {
    func getBuildSettings(fromXcodeProject xcodeProject: String) throws -> XcodeProjectBuildSettings {
        try XcodeProjectBuildSettings(xcodeProject: xcodeProject)
    }
}
