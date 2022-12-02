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

    public func run() async throws -> String {
        var xcodebuild = Command("xcodebuild", "-exportLocalizations", "-localizationPath", localizationPath)
        xcodebuild.add("-project", ifLet: xcodeProject ?? context.xcodeProject)
        return try context.shell(xcodebuild)
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
    func exportLocalizations(to localizationPath: String, xcodeProject: String? = nil) async throws -> String {
        try await step(ExportLocalizations(xcodeProject: xcodeProject, localizationPath: localizationPath))
    }
}
