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
