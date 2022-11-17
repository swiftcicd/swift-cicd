//protocol XcodeWorkflow: Workflow {
//    var project: String { get }
//}
//
//// Say this build step builds an xcode project
//struct SomeBuildStep: Step {
//    let project: String
//
//    init(project: String) {
//        self.project = project
//    }
//
//    init() throws {
//        guard let xcodeWorkflow = Self.context.currentWorkflow as? XcodeWorkflow else {
//            throw SwiftCI.StepError("Missing xcode project")
//        }
//
//        self.init(project: xcodeWorkflow.project)
//    }
//
//    func run() async throws {
//        print(project)
//    }
//}
//
//struct BuildProject: XcodeWorkflow {
//    var project: String { "MyApp.xcodeproj" }
//
//    func run() async throws {
//
//        // All of the above enables this
//        try await step(SomeBuildStep())
//        // Instead of
//        try await step(SomeBuildStep(project: "MyApp.xcodeproj"))
//    }
//}
//
//// or....
//
//enum XcodeProjectKey: ContextKey {
//    static let defaultValue: String? = nil
//}
//
//extension ContextValues {
//    var xcodeProject: String? {
//        get { self[XcodeProjectKey.self] }
//        set { self[XcodeProjectKey.self] = newValue }
//    }
//}
//
//// Say this build step builds an xcode project
//struct OtherBuildStep: Step {
//    let project: String
//
//    init(project: String) {
//        self.project = project
//    }
//
//    init() throws {
//        @Context(\.xcodeProject) var xcodeProject
//        try self.init(project: $xcodeProject.require())
//    }
//
//    init(project: String? = nil) throws {
//        @Context(\.xcodeProject) var xcodeProject
//        try self.init(project: project ?? $xcodeProject.require())
//    }
//
//    func run() async throws {
//
//    }
//}


// MARK: - ResultBuilder Syntax

//@propertyWrapper
//struct StepOutput<S: Step> {
//    typealias Output = S.Output
//
//    let stepType: S.Type
//    let container: OutputContainer
//
//    var wrappedValue: OutputContainer {
//        container
//    }
//
//    var projectedValue: OutputContainer {
//        container
//    }
//
//    struct StepOutputError: Error {}
//
//    @dynamicMemberLookup
//    class OutputContainer {
//        private var output: Output?
//
//        func store(_ output: Output) {
//            self.output = output
//        }
//
//        subscript<T>(dynamicMember keyPath: KeyPath<Output, T>) -> () throws -> T {
//            { [output] in
//                guard let output else {
//                    throw StepOutputError()
//                }
//
//                return output[keyPath: keyPath]
//            }
//        }
//    }
//
//    init(_ stepType: S.Type) {
//        self.stepType = stepType
//        self.container = OutputContainer()
//    }
//}
//
//extension Step {
//    func output(_ container: StepOutput<Self>.OutputContainer) -> some Step {
//        StoreOutputStep(step: self, container: container)
//    }
//}
//
//struct StoreOutputStep<BaseStep: Step>: Step {
//    let step: BaseStep
//    let container: StepOutput<BaseStep>.OutputContainer
//    var name: String { step.name }
//
//    func run() async throws -> BaseStep.Output {
//        let output = try await step.run()
//        container.store(output)
//        return output
//    }
//}
//
//struct BuildStep: Step {
//    let project: String
//
//    struct Output {
//        let product: String
//    }
//
//    func run() async throws -> Output {
//        Output(product: "result")
//    }
//}
//
//struct TestStep: Step {
//    let buildProduct: String
//
//    struct Output {
//        let results: Int
//    }
//
//    func run() async throws -> Output {
//        Output(results: 42)
//    }
//}
//
//struct ReportStep: Step {
//    let testResults: Int
//
//    func run() async throws {
//
//    }
//}
//
//struct SomeWorkflow: Workflow {
//    @StepOutput(BuildStep.self) var build
//    @StepOutput(TestStep.self) var test
//
//    func run() async throws {
//        BuildStep(project: "app.xcodeproj")
//            .output($build)
//
//        Using($build) { build in
//            TestStep(buildProduct: build.product)
//                .output($test)
//        }
//
//        try ReportStep(testResults: $test.results())
//    }
//}

//protocol WorkflowComponent {
//    var steps: [any Step] { get }
//}
//@resultBuilder
//struct WorkflowBuilder {
//    static func buildBlock(_ components: WorkflowComponent...) -> _Workflow {
//        _Workflow(steps: components.flatMap(\.steps))
//    }
//
//    static func buildArray(_ components: [WorkflowComponent]) -> _Workflow {
//        _Workflow(steps: components.flatMap(\.steps))
//    }
//}
//
//// a workflow is a list of steps
//
//struct _Workflow {
//    var steps: [any Step]
//}
