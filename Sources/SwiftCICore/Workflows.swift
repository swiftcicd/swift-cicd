///// A namespace for discoverable workflows.
//public enum Workflows {}
//
//public extension Workflows {
//    typealias XcodeProject = XcodeProjectWorkflow
//    typealias SwiftPackage = SwiftPackageWorkflow
//}
//
//public protocol XcodeProjectWorkflow: Workflow {
//    var xcodeProject: String { get }
//}
//
//public extension ContextValues {
//    // TODO: Because of this, we should ensure that all steps and functions that take an xcode project are optional.
//
//    /// Returns the Xcode project when accessed during an `XcodeProjectWorkflow` run.
//    var xcodeProject: String? {
//        guard let xcodeProjectWorkflow = inheritWorkflow(XcodeProjectWorkflow.self) else {
//            return nil
//        }
//
//        return xcodeProjectWorkflow.xcodeProject
//    }
//}
//
//public protocol SwiftPackageWorkflow: Workflow {
//    var package: String { get }
//}
