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
        get async throws {
            try await context.xcodeScheme
        }
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

public typealias MainXcodeAction = MainAction & XcodeAction

public protocol XcodeAction: Action {
    /// Returns the default Xcode container (either a project or a workspace.) to use when Xcode actions are performed.
    /// - Important: The value should a path relative to the working directory.
    /// - Note: `Xcode.Container` is `ExpressibleByStringLiteral` so you can return a string literal as a convenience.
    var xcodeContainer: Xcode.Container? { get throws }

    /// The default scheme to use when building the project.
    var xcodeScheme: String? { get async throws }
}

public extension XcodeAction {
    var xcodeContainer: Xcode.Container? {
        get throws {
            try context.getDefaultXcodeContainer()
        }
    }
    
    var xcodeScheme: String? {
        get async throws {
            try await context.getDefaultXcodeScheme()
        }
    }
}

public extension Action {
    func getDefault(container: Xcode.Container?, scheme: String?) async throws -> (container: Xcode.Container?, scheme: String?) {
        let c = try container ?? self.context.xcodeContainer
        let s = try await nilCoalesce(scheme) { try await self.context.xcodeScheme }
        return (c, s)
    }
}

public extension ContextValues {
    private static var cachedDefaultXcodeContainer: Xcode.Container?
    private static var cachedDefaultXcodeScheme: String?

    struct XcodeContainerNotFound: Error {}

    /// Returns the Xcode container (either a project or a workspace) when accessed during an `XcodeAction` run.
    var xcodeContainer: Xcode.Container? {
        get throws {
            guard let xcodeAction = inherit((any XcodeAction).self) else {
                return try getDefaultXcodeContainer()
            }

            return try xcodeAction.xcodeContainer
        }
    }

    var xcodeScheme: String? {
        get async throws {
            guard let xcodeAction = inherit((any XcodeAction).self) else {
                return try await getDefaultXcodeScheme()
            }

            return try await xcodeAction.xcodeScheme
        }
    }

    internal func getDefaultXcodeContainer() throws -> Xcode.Container? {
        if let cached = Self.cachedDefaultXcodeContainer {
            return cached
        }

        let workingDirectory = try self.workingDirectory
        let contents = try fileManager.contentsOfDirectory(atPath: workingDirectory)

        let containers = contents.compactMap { file -> Xcode.Container? in
            if file.hasSuffix(".xcodeproj") {
                let container = Xcode.Container.project(file)
                Self.cachedDefaultXcodeContainer = container
                return container
            } else if file.hasSuffix(".xcworkspace") {
                let container = Xcode.Container.workspace(file)
                Self.cachedDefaultXcodeContainer = container
                return container
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
                let container = workspaces[0]
                Self.cachedDefaultXcodeContainer = container
                return container
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
            let container = containers[0]
            Self.cachedDefaultXcodeContainer = container
            return container
        }
    }

    internal func getDefaultXcodeScheme() async throws -> String? {
        if let cached = Self.cachedDefaultXcodeScheme {
            return cached
        }

        let info = try await XcodeBuild.getInfo()
        // The only reasonable default is to return the first scheme in the list
        let scheme = info.schemes.first
        Self.cachedDefaultXcodeScheme = scheme
        return scheme
    }
}
