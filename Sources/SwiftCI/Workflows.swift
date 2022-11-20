public protocol XcodeProjectWorkflow: Workflow {
    var xcodeProject: String { get }
}

public extension ContextValues {
    // TODO: Because of this, we should ensure that all steps and functions that take an xcode project are optional.

    /// Returns the Xcode project when accessed during an `XcodeProjectWorkflow` run.
    var xcodeProject: String? {
        if let xcodeProjectWorkflow = currentWorkflow as? XcodeProjectWorkflow {
            return xcodeProjectWorkflow.xcodeProject
        } else {
            return nil
        }
    }
}

public protocol SwiftPackageWorkflow: Workflow {
    var package: String { get }
}
