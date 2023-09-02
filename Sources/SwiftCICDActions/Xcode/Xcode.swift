import SwiftCICDCore

/// Namespace for Xcode actions.
public struct Xcode: ActionNamespace {
    public let caller: any Action

    public var container: Container? {
        get throws {
            try context.xcodeContainer
        }
    }

    public var defaultScheme: String? {
        context.defaultXcodeProjectScheme
    }
}

public extension Action {
    var xcode: Xcode { Xcode(caller: self) }
}

// MARK: - Specialized Action

public protocol XcodeAction: Action {
    /// Returns the default Xcode container (either a project or a workspace.) to use when Xcode actions are performed.
    var xcodeContainer: Xcode.Container { get throws }

    /// The default scheme to use when building the project.
    var defaultScheme: String? { get }
}

public extension XcodeAction {
    var defaultScheme: String? { nil }
}

public extension ContextValues {
    /// Returns the Xcode container (either a project or a workspace) when accessed during an `XcodeProjectAction` run.
    var xcodeContainer: Xcode.Container? {
        get throws {
            guard let xcodeAction = inherit((any XcodeAction).self) else {
                let workingDirectory = try self.workingDirectory
                let contents = try fileManager.contentsOfDirectory(atPath: workingDirectory)
                if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                    return .project(workingDirectory/project)
                } else if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
                    return .workspace(workingDirectory/workspace)
                }
                return nil
            }

            return try xcodeAction.xcodeContainer
        }
    }

    var defaultXcodeProjectScheme: String? {
        inherit((any XcodeAction).self)?.defaultScheme
    }
}
