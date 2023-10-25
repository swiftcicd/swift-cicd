import SwiftCICDCore

/// Namespace for Xcode actions.
public struct Xcode: ActionNamespace {
    private static var hasOutputXcodeInfo = false
    public let caller: any Action

    public var container: Container? {
        get throws {
            try context.xcodeContainer
        }
    }

    public var scheme: String? {
        context.xcodeScheme
    }

//    @discardableResult
//    func run<A: Action>(_ action: A) async throws -> A.Output {
//        // The first time that an Xcode action is run, automatically output the current Xcode info.
//        if !Self.hasOutputXcodeInfo {
//            Self.hasOutputXcodeInfo = true
//            // Throw away any errors that might occur.
//            _ = try? await caller.run(Info())
//        }
//
//        return try await caller.run(action)
//    }
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

        let containers = contents.compactMap { file -> Xcode.Container? in
            if file.hasSuffix(".xcodeproj") {
                return .project(file)
            } else if file.hasSuffix(".xcworkspace") {
                return .workspace(file)
            } else {
                return nil
            }
        }

        if containers.isEmpty {
            logger.notice(
                """
                There wasn't an Xcode container (either an .xcodeproj or an .xcworkspace) at \
                the root of the working directory. Please specify an Xcode container either by \
                making your main action conform to `XcodeAction` and return one from `xcodeContainer` \
                or pass the container to the action you're trying to run.
                """
            )
            return nil
        } else if containers.count > 1 {
            let workspaces = containers.filter(\.isWorkspace)
            let projects = containers.filter(\.isProject)

            if workspaces.count == 0 {
                logger.notice(
                    """
                    Multiple .xcodeproj files were found at the root of the working directory. \
                    Please specify which .xcodeproj to use by making your main action conform to \
                    `XcodeAction` and return one from `xcodeContainer` or pass the project to the \
                    action you're trying to run.
                    """
                )
                return nil
            } else if workspaces.count == 1 {
                // Prefer workspaces over projects. 
                // Normally, if both are present, the workspace is the intended container.
                logger.notice(
                    """
                    Multiple Xcode containers (either an .xcodeproj or an .xcworkspace) were found at \
                    the root of the working directory. There was only one .xcworkspace (\(workspaces[0].name)) \
                    which will be used by default.
                    """
                )
                return workspaces[0]
            } else {
                logger.notice(
                    """
                    Multiple .xcodeproj and .xcworkspaces were found at the root of the working directory. \
                    Please specify which one to use by making your main action conform to `XcodeAction` and \
                    return one from `xcodeContainer` or pass one to the action you're trying to run.
                    """
                )
                return nil
            }
        } else {
            return containers[0]
        }
    }
}
