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
        
        // Check for a workspace first.
        // Usually if both a workspace and a project exist, the workspace is the intended result.
        if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return .workspace(workingDirectory/workspace)
        } else if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
            return .project(workingDirectory/project)
        }

        return nil
    }
}
