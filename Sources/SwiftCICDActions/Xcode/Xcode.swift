import SwiftCICDCore

/// Namespace for Xcode actions.
public struct Xcode: ActionNamespace {
    public let caller: any Action

    public var project: String? {
        get throws {
            try context.xcodeProject
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

public protocol XcodeProjectAction: Action {
    /// Path to Xcode project.
    var xcodeProject: String { get throws }

    /// The default scheme to use when building the project.
    var defaultScheme: String? { get }
}

public extension XcodeProjectAction {
    var defaultScheme: String? { nil }
}

public extension ContextValues {
    /// Returns the Xcode project when accessed during an `XcodeProjectAction` run.
    var xcodeProject: String? {
        get throws {
            guard let xcodeProjectAction = inherit((any XcodeProjectAction).self) else {
                let workingDirectory = try self.workingDirectory
                let contents = try fileManager.contentsOfDirectory(atPath: workingDirectory)
                if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                    return workingDirectory/project
                } else if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
                    return workingDirectory/workspace
                }
                return nil
            }

            return try xcodeProjectAction.xcodeProject
        }
    }

    var defaultXcodeProjectScheme: String? {
        inherit((any XcodeProjectAction).self)?.defaultScheme
    }
}
