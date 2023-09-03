import SwiftCICDCore

/// Namespace for Xcode actions.
public struct Xcode: ActionNamespace {
    public let caller: any Action

    public var container: Container? {
        get throws {
            try context.xcodeContainer
        }
    }

    public var scheme: String? {
        context.xcodeScheme
    }
}

public extension Action {
    var xcode: Xcode { Xcode(caller: self) }
}

// MARK: - Specialized Action

public protocol XcodeAction: Action {
    /// Returns the default Xcode container (either a project or a workspace.) to use when Xcode actions are performed.
    /// - Important: The value should a path relative to the working directory.
    /// - Note: `Xcode.Container` is `ExpressibleByStringLiteral` so you can return a string literal as a convenience.
    var xcodeContainer: Xcode.Container? { get throws }

    /// The default scheme to use when building the project.
    var xcodeScheme: String? { get }
}

public extension XcodeAction {
    var xcodeContainer: Xcode.Container? {
        get throws {
            try context.getDefaultXcodeContainer()
        }
    }
    
    var xcodeScheme: String? { nil }
}

public extension ContextValues {
    struct XcodeContainerNotFound: Error {}

    /// Returns the Xcode container (either a project or a workspace) when accessed during an `XcodeProjectAction` run.
    var xcodeContainer: Xcode.Container? {
        get throws {
            guard let xcodeAction = inherit((any XcodeAction).self) else {
                return try getDefaultXcodeContainer()
            }

            return try xcodeAction.xcodeContainer
        }
    }

    var xcodeScheme: String? {
        inherit((any XcodeAction).self)?.xcodeScheme
    }

    internal func getDefaultXcodeContainer() throws -> Xcode.Container? {
        let workingDirectory = try self.workingDirectory
        let contents = try fileManager.contentsOfDirectory(atPath: workingDirectory)

        // Check for project first, even if there is a workspace present.
        // There are actions that require a project over a workspace, such as exporting an archive.
        // Defaulting to project will allow these actions to run smoothly even if the user didn't specify
        // an explict Xcode Container.
        if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
            return .project(workingDirectory/project)
        } else if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return .workspace(workingDirectory/workspace)
        }

        return nil
    }
}
