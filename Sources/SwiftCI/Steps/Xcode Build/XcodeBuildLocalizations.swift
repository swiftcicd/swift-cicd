extension XcodeBuildStep {
    public struct ImportLocalizations: Step {
        public let name = "Xcode Build: Import Localizations"

        let localizationPath: String

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
