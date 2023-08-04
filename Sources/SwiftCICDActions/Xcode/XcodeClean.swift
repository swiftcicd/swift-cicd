import SwiftCICDCore

extension Xcode {
    public struct Clean: Action {
        let container: XcodeBuild.Container?
        let scheme: String?

        internal init(
            container: XcodeBuild.Container? = nil,
            scheme: String? = nil
        ) {
            self.container = container
            self.scheme = scheme
        }

        public init(project: String? = nil, scheme: String? = nil) {
            self.init(
                container: project.map { .project($0) },
                scheme: scheme
            )
        }

        public init(workspace: String, scheme: String? = nil) {
            self.init(
                container: .workspace(workspace),
                scheme: scheme
            )
        }

        public func run() async throws {
            var command = ShellCommand("xcodebuild clean")
            // TODO: Default the project
            let scheme = self.scheme ?? context.defaultXcodeProjectScheme
            let container = try self.container ?? context.xcodeProject.map { .project($0) }
            command.append(container?.flag)
            command.append("-scheme", ifLet: scheme)
//            command.append("-derivedDataPath \(XcodeBuild.derivedData.filePath)")
            try await shell(command)
        }
    }
}

public extension Xcode {
    /// Cleans the project's derived data by running `xcodebuild clean`.
    /// - Parameters:
    ///   - project: The project to clean. If a project isn't specified, the contextual Xcode project will be used (if it can be found.)
    ///   - scheme: The scheme to clean, if specified.
    func clean(project: String? = nil, scheme: String? = nil) async throws {
        let project = try? project ?? context.xcodeProject
        try await run(
            Clean(
                container: project.map(XcodeBuild.Container.project),
                scheme: scheme
            )
        )
    }

    /// Cleans the workspace's derived data by running `xcodebuild clean`.
    /// - Parameters:
    ///   - workspace: The workspace to clean.
    ///   - scheme: The scheme to clean, if specified.
    func clean(workspace: String, scheme: String? = nil) async throws {
        try await run(
            Clean(
                container: .workspace(workspace),
                scheme: scheme
            )
        )
    }
}
