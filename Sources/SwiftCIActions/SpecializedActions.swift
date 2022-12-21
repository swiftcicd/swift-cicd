import SwiftCICore

public protocol XcodeProjectAction: Action {
    /// Path to Xcode project.
    var xcodeProject: String { get }
}

public extension ContextValues {
    /// Returns the Xcode project when accessed during an `XcodeProjectAction` run.
    var xcodeProject: String? {
        guard let xcodeProjectAction = inherit((any XcodeProjectAction).self) else {
            return nil
        }

        return xcodeProjectAction.xcodeProject
    }
}

public protocol SwiftPackageAction: Action {
    /// Path to Swift Package directory.
    var package: String { get }
}

public extension ContextValues {
    var package: String? {
        guard let swiftPackageAction = inherit((any SwiftPackageAction).self) else {
            return nil
        }

        return swiftPackageAction.package
    }
}
