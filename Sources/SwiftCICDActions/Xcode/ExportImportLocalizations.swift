import Foundation
import SwiftCICDCore

struct ImportLocalizations: Action {
    var xcodeProject: String?
    let localizationPath: String
    let xcbeautify: Bool

    init(xcodeProject: String? = nil, localizationPath: String, xcbeautify: Bool = Xcbeautify.default) {
        self.xcodeProject = xcodeProject
        self.localizationPath = localizationPath
        self.xcbeautify = xcbeautify
    }

    func run() async throws -> String {
        logger.info("Importing \(localizationPath)")
        var xcodebuild = ShellCommand("xcodebuild -importLocalizations -localizationPath \(localizationPath)")
        try xcodebuild.append("-project", ifLet: xcodeProject ?? context.xcodeProject)
        return try await xcbeautify(xcodebuild, if: xcbeautify)
    }
}

public struct ExportLocalizations: Action {
    // TODO: Investigate using this argument:
    // -exportLanguage (specifies multiple optional ISO 639-1 languages included in a localization export)
    // We may be able to detect support languages from the project file and then pass those supported languages

    var xcodeProject: String?
    let localizationPath: String
    let failOnWarnings: Bool
    let xcbeautify: Bool

    init(
        xcodeProject: String? = nil,
        localizationPath: String,
        failOnWarnings: Bool = true,
        xcbeautify: Bool = Xcbeautify.default
    ) {
        self.xcodeProject = xcodeProject
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
        var xcodebuild = ShellCommand("xcodebuild -exportLocalizations -localizationPath \(localizationPath)")
        xcodebuild.append("-project", ifLet: try xcodeProject ?? context.xcodeProject)

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

public extension Xcode {
    func importLocalizations(
        fromDirectory localizationsDirectory: String,
        project: String? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        do {
            guard context.fileManager.fileExists(atPath: localizationsDirectory) else {
                context.logger.info("Localizations directory (\(localizationsDirectory)) doesn't exist yet, skipping import localizations step.")
                return
            }
        }

        for file in try context.fileManager.contentsOfDirectory(atPath: localizationsDirectory) {
            guard file.hasSuffix(".xcloc") else { continue }
            try await run(
                ImportLocalizations(
                    xcodeProject: project ?? self.project,
                    localizationPath: localizationsDirectory/file,
                    xcbeautify: xcbeautify
                )
            )
        }
    }

    @discardableResult
    func importLocalizations(
        from localizationPath: String,
        project: String? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> String {
        try await run(
            ImportLocalizations(
                xcodeProject: project ?? self.project,
                localizationPath: localizationPath,
                xcbeautify: xcbeautify
            )
        )
    }

    @discardableResult
    func exportLocalizations(
        to localizationPath: String,
        project: String? = nil,
        failOnWarnings: Bool = true,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> ExportLocalizations.Output {
        try await run(
            ExportLocalizations(
                xcodeProject: project ?? self.project,
                localizationPath: localizationPath,
                failOnWarnings: failOnWarnings,
                xcbeautify: xcbeautify
            )
        )
    }
}
