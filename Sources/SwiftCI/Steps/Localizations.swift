import Foundation

public struct ImportLocalizations: Step {
    var xcodeProject: String?
    let localizationPath: String
    let xcbeautify: Bool

    public init(xcodeProject: String? = nil, localizationPath: String, xcbeautify: Bool = false) {
        self.xcodeProject = xcodeProject
        self.localizationPath = localizationPath
        self.xcbeautify = xcbeautify
    }

    public func run() async throws -> String {
        logger.info("Importing \(localizationPath)")
        var xcodebuild = Command("xcodebuild", "-importLocalizations", "-localizationPath", localizationPath)
        xcodebuild.add("-project", ifLet: xcodeProject ?? context.xcodeProject)
        if xcbeautify {
            return try await xcbeautify(xcodebuild, options: .init(preserveUnbeautified: true))
        } else {
            return try context.shell(xcodebuild)
        }
    }
}

public struct ExportLocalizations: Step {
    // TODO: Investigate using this argument:
    // -exportLanguage (specifies multiple optional ISO 639-1 languages included in a localization export)
    // We may be able to detect support languages from the project file and then pass those supported languages

    var xcodeProject: String?
    let localizationPath: String
    let failOnWarnings: Bool
    let xcbeautify: Bool

    public init(xcodeProject: String? = nil, localizationPath: String, failOnWarnings: Bool = true, xcbeautify: Bool = false) {
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
        var xcodebuild = Command("xcodebuild", "-exportLocalizations", "-localizationPath", localizationPath)
        xcodebuild.add("-project", ifLet: xcodeProject ?? context.xcodeProject)

        let commandOutput: String
        if xcbeautify {
            commandOutput = try await xcbeautify(xcodebuild, options: .init(preserveUnbeautified: true))
        } else {
            commandOutput = try context.shell(xcodebuild)
        }

        var output = Output()
        for line in commandOutput.components(separatedBy: "\n") {
            if let warning = warning(from: line) {
                output.warnings.insert(warning)
            }
        }

        if failOnWarnings, !output.warnings.isEmpty {
            throw StepError("""
                Failing on warnings:
                \(output.warnings.map { "\t- \($0.description)" }.joined(separator: "\n"))
                """
            )
        }

        return output
    }

    func warning(from line: String) -> Output.Warning? {
        if #available(macOS 13.0, iOS 16.0, *) {
            guard let match = line.firstMatch(of: #/Key "(?<key>.+)" used with multiple values. Value "(?<kept>.+)" kept. Value "(?<ignored>.+)" ignored./#) else {
                return nil
            }

            return .duplicate(key: String(match.output.key), valueKept: String(match.output.kept), valueIgnored: String(match.output.ignored))

        } else {
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

public extension StepRunner {
    func importLocalizations(fromDirectory localizationsDirectory: String, xcodeProject: String? = nil, xcbeautify: Bool = false) async throws {
        do {
            context.startLogGroup(name: "Preparing to import localizations...")
            defer { context.endLogGroup() }

            guard context.fileManager.fileExists(atPath: localizationsDirectory) else {
                context.logger.info("Localizations directory (\(localizationsDirectory)) doesn't exist yet, skipping import localizations step.")
                return
            }
        }

        for file in try context.fileManager.contentsOfDirectory(atPath: localizationsDirectory) {
            guard file.hasSuffix(".xcloc") else { continue }
            try await step(ImportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationsDirectory/file, xcbeautify: xcbeautify))
        }
    }

    @discardableResult
    func importLocalizations(from localizationPath: String, xcodeProject: String? = nil, xcbeautify: Bool = false) async throws -> String {
        try await step(ImportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationPath, xcbeautify: xcbeautify))
    }

    @discardableResult
    func exportLocalizations(to localizationPath: String, xcodeProject: String? = nil, failOnWarnings: Bool = true, xcbeautify: Bool = false) async throws -> ExportLocalizations.Output {
        try await step(ExportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationPath, failOnWarnings: failOnWarnings, xcbeautify: xcbeautify))
    }
}
