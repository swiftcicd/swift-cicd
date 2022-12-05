import Foundation

public struct ImportLocalizations: Step {
    var xcodeProject: String?
    let localizationPath: String

    public init(xcodeProject: String? = nil, localizationPath: String) {
        self.xcodeProject = xcodeProject
        self.localizationPath = localizationPath
    }

    public func run() async throws -> String {
        logger.info("Importing \(localizationPath)")
        var xcodebuild = Command("xcodebuild", "-importLocalizations", "-localizationPath", localizationPath)
        xcodebuild.add("-project", ifLet: xcodeProject ?? context.xcodeProject)
        return try context.shell(xcodebuild)
    }
}

public struct ExportLocalizations: Step {
    // TODO: Investigate using this argument:
    // -exportLanguage (specifies multiple optional ISO 639-1 languages included in a localization export)
    // We may be able to detect support languages from the project file and then pass those supported languages

    var xcodeProject: String?
    let localizationPath: String

    public init(xcodeProject: String? = nil, localizationPath: String) {
        self.xcodeProject = xcodeProject
        self.localizationPath = localizationPath
    }

    public struct Output {
        public enum Warning {
            static let token = "--- WARNING: "
            static let duplicateToken = #"Key (?<key>".+") used with multiple values. Value (?<valueKept>".+") kept. Value (?<valueIgnored>".+") ignored."#

            case duplicate(key: String, valueKept: String, valueIgnored: String)
            case other(String)
        }

        public var warnings = [Warning]()
    }

    public func run() async throws -> Output {
        var xcodebuild = Command("xcodebuild", "-exportLocalizations", "-localizationPath", localizationPath)
        xcodebuild.add("-project", ifLet: xcodeProject ?? context.xcodeProject)
        let commandOutput = try context.shell(xcodebuild)
        var output = Output()
        for line in commandOutput.components(separatedBy: "\n") {
            if let warningToken = line.range(of: Output.Warning.token) {
                let warningBody = line[line.index(after: warningToken.upperBound)...]
                output.warnings.append(warning(from: String(warningBody)))
            }
        }
        return output
    }

    func warning(from line: String) -> Output.Warning {
        let other = Output.Warning.other(String(line))

        if #available(macOS 13.0, *) {
            guard let match = line.wholeMatch(of: #/Key (?<key>".+") used with multiple values. Value (?<kept>".+") kept. Vlaue (?<ignored>".+") ignored./#) else {
                return other
            }

            return .duplicate(key: String(match.output.key), valueKept: String(match.output.kept), valueIgnored: String(match.output.ignored))

        } else {
            let key = "key"
            let kept = "kept"
            let ignored = "ignored"
            let regex = try! NSRegularExpression(pattern: "Key (?<\(key)>\".+\") used with multiple values. Value (?<\(kept)>\".+\") kept. Value (?<\(ignored)>\".+\") ignored.")
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) else {
                return other
            }

            func captureGroup(named name: String) -> String? {
                let nsRange = match.range(withName: name)
                guard nsRange.location != NSNotFound, let range = Range(nsRange, in: line) else {
                    return nil
                }
                return String(line[...][range])
            }

            guard let capturedKey = captureGroup(named: key) else { return other }
            guard let capturedKept = captureGroup(named: kept) else { return other }
            guard let capturedIgnored = captureGroup(named: ignored) else { return other }

            return .duplicate(key: capturedKey, valueKept: capturedKept, valueIgnored: capturedIgnored)
        }
    }
}

public extension StepRunner {
    func importLocalizations(fromDirectory localizationsDirectory: String, xcodeProject: String? = nil) async throws {
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
            try await step(ImportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationsDirectory/file))
        }
    }

    @discardableResult
    func importLocalizations(from localizationPath: String, xcodeProject: String? = nil) async throws -> String {
        try await step(ImportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationPath))
    }

    @discardableResult
    func exportLocalizations(to localizationPath: String, xcodeProject: String? = nil) async throws -> ExportLocalizations.Output {
        try await step(ExportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationPath))
    }
}
