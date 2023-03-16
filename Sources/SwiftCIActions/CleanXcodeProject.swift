import SwiftCICore

public struct CleanXcodeProject: Action {
    fileprivate enum XcodeContainer {
        case project(String)
        case workspace(String)

        var project: String? {
            switch self {
            case .project(let project): return project
            case .workspace: return nil
            }
        }

        var workspace: String? {
            switch self {
            case .workspace(let workspace): return workspace
            case .project: return nil
            }
        }
    }

    fileprivate let container: XcodeContainer?
    let scheme: String?

    public func run() async throws {
        var command = ShellCommand("xcodebuild clean")
        command.append("-workspace", ifLet: container?.workspace)
        command.append("-project", ifLet: container?.project)
        command.append("-scheme", ifLet: scheme)
        try context.shell(command)
    }
}

public extension Action {
    /// Cleans the project's derived data by running `xcodebuild clean`.
    /// - Parameters:
    ///   - project: The project to clean. If a project isn't specified, the contextual Xcode project will be used (if it can be found.)
    ///   - scheme: The scheme to clean, if specified.
    func cleanXcodeProject(_ project: String? = nil, scheme: String? = nil) async throws {
        let project = try? project ?? context.xcodeProject
        try await action(CleanXcodeProject(container: project.map(CleanXcodeProject.XcodeContainer.project), scheme: scheme))
    }

    /// Cleans the workspace's derived data by running `xcodebuild clean`.
    /// - Parameters:
    ///   - workspace: The workspace to clean.
    ///   - scheme: The scheme to clean, if specified.
    func cleanXcodeWorkspace(_ workspace: String, scheme: String? = nil) async throws {
        try await action(CleanXcodeProject(container: .workspace(workspace), scheme: scheme))
    }
}
