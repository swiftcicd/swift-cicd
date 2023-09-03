import Foundation
import SwiftCICDCore

extension Xcode {
    public struct ExportLocalizations: Action {
        // TODO: Investigate using this argument:
        // -exportLanguage (specifies multiple optional ISO 639-1 languages included in a localization export)
        // We may be able to detect support languages from the project file and then pass those supported languages

        var container: Xcode.Container?
        let localizationPath: String
        let failOnWarnings: Bool
        let xcbeautify: Bool

        public init(
            to localizationPath: String,
            project: String? = nil,
            failOnWarnings: Bool = true,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = project.map { .project($0) }
            self.localizationPath = localizationPath
            self.failOnWarnings = failOnWarnings
            self.xcbeautify = xcbeautify
        }

        @_disfavoredOverload
        public init(
            to localizationPath: String,
            workspace: String? = nil,
            failOnWarnings: Bool = true,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = workspace.map { .workspace($0) }
            self.localizationPath = localizationPath
            self.failOnWarnings = failOnWarnings
            self.xcbeautify = xcbeautify
        }

        public struct Output {
            public enum Warning: Hashable, CustomStringConvertible {
                case duplicate(key: String, valueKept: String, valueIgnored: String)
                case other(String)

                public var description: String {
                    switch self {
                    case let .duplicate(key, valueKept, valueIgnored):
                        return "Duplicate localization key found: \"\(key)\". Keeping value: \"\(valueKept)\". Ignoring value: \"\(valueIgnored)\"."
                    case let .other(warning):
                        return warning
                    }
                }
            }

            public var warnings = Set<Warning>()
        }

        public func run() async throws -> Output {
            logger.info("Exporting localizations")
            let container = try self.container ?? context.xcodeContainer
            var xcodebuild = ShellCommand("xcodebuild -exportLocalizations -localizationPath \(localizationPath)")
            try xcodebuild.append(container?.flag)

            let commandOutput = try await xcbeautify(xcodebuild, if: xcbeautify)

            var output = Output()
            for line in commandOutput.components(separatedBy: "\n") {
                if let warning = warning(from: line) {
                    output.warnings.insert(warning)
                }
            }

            if failOnWarnings, !output.warnings.isEmpty {
                throw ActionError("""
                    Failing on warnings:
                    \(output.warnings.map { "\t- \($0.description)" }.joined(separator: "\n"))
                    """
                )
            }

            return output
        }

        func warning(from line: String) -> Output.Warning? {
            let key = "key"
            let kept = "kept"
            let ignored = "ignored"
            let regex = try! NSRegularExpression(pattern: "Key \"(?<\(key)>.+)\" used with multiple values. Value \"(?<\(kept)>.+)\" kept. Value \"(?<\(ignored)>.+)\" ignored.")
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) else {
                return nil
            }

            func captureGroup(named name: String) -> String? {
                let nsRange = match.range(withName: name)
                guard nsRange.location != NSNotFound, let range = Range(nsRange, in: line) else {
                    return nil
                }
                return String(line[...][range])
            }

            guard let capturedKey = captureGroup(named: key) else { return nil }
            guard let capturedKept = captureGroup(named: kept) else { return nil }
            guard let capturedIgnored = captureGroup(named: ignored) else { return nil }

            return .duplicate(key: capturedKey, valueKept: capturedKept, valueIgnored: capturedIgnored)
        }
    }
}

public extension Xcode {
    @discardableResult
    func exportLocalizations(
        to localizationPath: String,
        project: String? = nil,
        failOnWarnings: Bool = true,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ExportLocalizations.Output {
        try await run(
            ExportLocalizations(
                to: localizationPath,
                project: project,
                failOnWarnings: failOnWarnings,
                xcbeautify: xcbeautify
            )
        )
    }

    @_disfavoredOverload
    @discardableResult
    func exportLocalizations(
        to localizationPath: String,
        workspace: String? = nil,
        failOnWarnings: Bool = true,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ExportLocalizations.Output {
        try await run(
            ExportLocalizations(
                to: localizationPath,
                workspace: workspace,
                failOnWarnings: failOnWarnings,
                xcbeautify: xcbeautify
            )
        )
    }

}
