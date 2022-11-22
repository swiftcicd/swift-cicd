public protocol XcodeProjectWorkflow: Workflow {
    var xcodeProject: String { get }
}

public extension ContextValues {
    // TODO: Because of this, we should ensure that all steps and functions that take an xcode project are optional.

    /// Returns the Xcode project when accessed during an `XcodeProjectWorkflow` run.
    var xcodeProject: String? {



        // workflow stack could be an array of [(workflow: Workflow, parent: Workflow?)]
        // then you can go up the stack of workflows, looking for parents that match criteria




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
