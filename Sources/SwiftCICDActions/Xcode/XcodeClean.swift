import SwiftCICDCore

struct XcodeClean: Action {
    let container: XcodeBuild.Container?
    let scheme: String?

    func run() async throws {
        var command = ShellCommand("xcodebuild clean")
        command.append(container?.flag)
        command.append("-scheme", ifLet: scheme)
        try await shell(command)
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
            XcodeClean(
                container: project.map(XcodeBuild.Container.project),
                scheme: scheme ?? self.defaultScheme
            )
        )
    }

    /// Cleans the workspace's derived data by running `xcodebuild clean`.
    /// - Parameters:
    ///   - workspace: The workspace to clean.
    ///   - scheme: The scheme to clean, if specified.
    func clean(workspace: String, scheme: String? = nil) async throws {
        try await run(
            XcodeClean(
                container: .workspace(workspace),
                scheme: scheme ?? self.defaultScheme
            )
        )
    }
}
