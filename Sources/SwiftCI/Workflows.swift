public protocol XcodeProjectWorkflow: Workflow {
    var xcodeProject: String { get }
}

public extension ContextValues {
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
