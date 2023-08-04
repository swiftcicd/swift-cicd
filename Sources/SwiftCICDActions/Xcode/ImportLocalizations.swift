import Foundation
import SwiftCICDCore

extension Xcode {
    public struct ImportLocalizations: Action {
        enum Source {
            case file(String)
            case directory(String)
        }

        var project: String?
        let localizationSource: Source
        let xcbeautify: Bool

        public init(
            in localizationsDirectory: String,
            project: String? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.localizationSource = .directory(localizationsDirectory)
            self.project = project
            self.xcbeautify = xcbeautify
        }

        public init(
            at localizationPath: String,
            project: String? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.localizationSource = .file(localizationPath)
            self.project = project
            self.xcbeautify = xcbeautify
        }

        public func run() async throws {
            switch localizationSource {
            case .file(let filePath):
                try await importLocalizationFile(path: filePath)

            case .directory(let directory):
                do {
                    guard context.fileManager.fileExists(atPath: directory) else {
                        context.logger.info("Localizations directory (\(directory)) doesn't exist yet, skipping import localizations step.")
                        return
                    }
                }

                for file in try context.fileManager.contentsOfDirectory(atPath: directory) {
                    guard file.hasSuffix(".xcloc") else { continue }
                    try await importLocalizationFile(path: directory/file)
                }
            }
        }

        func importLocalizationFile(path: String) async throws {
            logger.info("Importing \(path)")
            let project = try self.project ?? context.xcodeProject
            var xcodebuild = ShellCommand("xcodebuild -importLocalizations -localizationPath \(path)")
            xcodebuild.append("-project", ifLet: project)
            try await xcbeautify(xcodebuild, if: xcbeautify)
        }
    }
}

public extension Xcode {
    func importLocalizations(
        in localizationsDirectory: String,
        project: String? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            ImportLocalizations(
                in: localizationsDirectory,
                project: project,
                xcbeautify: xcbeautify
            )
        )
    }

    func importLocalizations(
        at localizationPath: String,
        project: String? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            ImportLocalizations(
                at: localizationPath,
                project: project,
                xcbeautify: xcbeautify
            )
        )
    }
}
