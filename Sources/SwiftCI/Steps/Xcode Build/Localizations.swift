extension XcodeBuild {
    public struct ImportLocalizations: CommandStep {
        public let name = "Xcode Build: Import Localizations"

        let localizationPath: String

        public var command: Command {
            Command(command: "xcodebuild", arguments: ["-importLocalizations", "-localizationPath", localizationPath])
        }
    }

    public struct ExportLocalizations: CommandStep {
        public let name = "Xcode Build: Export Localizations"

        let localizationPath: String

        public var command: Command {
            Command(command: "xcodebuild", arguments: ["-exportLocalizations", "-localizationPath", localizationPath])
        }
    }
}

public extension Step where Self == XcodeBuild.ImportLocalizations {
    static func xcodebuild(importLocalizationsFrom localizationPath: String) -> XcodeBuild.ImportLocalizations {
        .init(localizationPath: localizationPath)
    }
}

public extension Step where Self == XcodeBuild.ExportLocalizations {
    static func xcodebuild(exportLocalizationsTo localizationPath: String) -> XcodeBuild.ExportLocalizations {
        .init(localizationPath: localizationPath)
    }
}
