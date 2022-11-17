extension XcodeBuildStep {
    public struct ImportLocalizations: Step {
        public let name = "Xcode Build: Import Localizations"

        let localizationPath: String

        // TODO: Investigate using this argument:
//        -exportLanguage                                          specifies multiple optional ISO 639-1 languages included in a localization export
        // Maybe we should use that instead of looping over files
        // We may be able to detect support languages from the project file and then pass those supported languages


        public func run() async throws -> String {
            try context.shell("xcodebuild", "-importLocalizations", "-localizationPath", localizationPath)
        }
    }

    public struct ExportLocalizations: Step {
        public let name = "Xcode Build: Export Localizations"

        let localizationPath: String

        public func run() async throws -> String {
            try context.shell("xcodebuild", "-exportLocalizations", "-localizationPath", localizationPath)
        }
    }
}

public extension Step where Self == XcodeBuildStep.ImportLocalizations {
    static func xcodebuild(importLocalizationsFrom localizationPath: String) -> XcodeBuildStep.ImportLocalizations {
        .init(localizationPath: localizationPath)
    }
}

public extension Step where Self == XcodeBuildStep.ExportLocalizations {
    static func xcodebuild(exportLocalizationsTo localizationPath: String) -> XcodeBuildStep.ExportLocalizations {
        .init(localizationPath: localizationPath)
    }
}
