import Foundation
import SwiftCICDCore

extension Xcode {
    public struct ImportLocalizations: Action {
        enum Source {
            case file(String)
            case directory(String)
        }

        var container: Xcode.Container?
        let localizationSource: Source
        let xcbeautify: Bool

        init(
            in localizationsDirectory: String,
            container: Xcode.Container? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.localizationSource = .directory(localizationsDirectory)
            self.container = container
            self.xcbeautify = xcbeautify
        }

        public init(
            in localizationsDirectory: String,
            project: String? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.init(
                in: localizationsDirectory,
                container: project.map { .project($0) },
                xcbeautify: xcbeautify
            )
        }

        @_disfavoredOverload
        public init(
            in localizationsDirectory: String,
            workspace: String? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.init(
                in: localizationsDirectory,
                container: workspace.map { .workspace($0) },
                xcbeautify: xcbeautify
            )
        }

        init(
            at localizationPath: String,
            container: Xcode.Container? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.localizationSource = .file(localizationPath)
            self.container = container
            self.xcbeautify = xcbeautify
        }

        public init(
            at localizationPath: String,
            project: String? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.init(
                at: localizationPath,
                container: project.map { .project($0) },
                xcbeautify: xcbeautify
            )
        }

        @_disfavoredOverload
        public init(
            at localizationPath: String,
            workspace: String? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.init(
                at: localizationPath,
                container: workspace.map { .workspace($0) },
                xcbeautify: xcbeautify
            )
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
            let container = try self.container ?? context.xcodeContainer
            var xcodebuild = ShellCommand("xcodebuild -importLocalizations -localizationPath \(path)")
            xcodebuild.append(container?.flag)
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

    @_disfavoredOverload
    func importLocalizations(
        in localizationsDirectory: String,
        workspace: String? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            ImportLocalizations(
                in: localizationsDirectory,
                workspace: workspace,
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

    @_disfavoredOverload
    func importLocalizations(
        at localizationPath: String,
        workspace: String? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            ImportLocalizations(
                at: localizationPath,
                workspace: workspace,
                xcbeautify: xcbeautify
            )
        )
    }
}
