import Arguments
import Foundation
import Logging

// TODO: Built-in swift-pr support
// TODO: replicate the ssh action (https://github.com/webfactory/ssh-agent/blob/master/index.js, https://github.com/webfactory/ssh-agent/blob/master/cleanup.js)
// TODO: Add build to test flight group
// TODO: Attach build artifacts to GitHub artifacts
// - upload artifact: https://github.com/actions/toolkit/blob/819157bf872a49cfcc085190da73894e7091c83c/packages/artifact/src/internal/upload-http-client.ts#L399
// https://github.com/actions/toolkit/blob/819157bf872a49cfcc085190da73894e7091c83c/packages/artifact/src/internal/utils.ts#L221
// - .app (simulator build)
// - .ipa (distribution build)
// - .xcarchive (archive for flexibility)

// TODO: Should a workflow have an Outcome (success, failure, etc.) kind of like how a step has an output?
// TODO: Would it be possible to make swift-ci run as a subcommand of swift?
//  - So instead of: swift run name-of-executable
//  - It would be: swift ci

// TODO: Simulator builds
// - (set the build number to the PR number, change the bundle identifier to the pr number, and the display name) so that PR builds can be identified on simulator

public protocol Workflow: StepRunner, WorkflowRunner {
    static var name: String { get }
    static var logLevel: Logger.Level { get }
    init()
    func run() async throws
}

public extension Workflow {
    static var name: String {
        "\(self)"
    }

    static var logLevel: Logger.Level {
        .info
    }
}

public extension WorkflowRunner {
    func workflow<W: Workflow>(name: String? = nil, _ workflow: W) async throws {
        // Parents are restored to their current directory after a child workflow runs
        let currentDirectory = context.fileManager.currentDirectoryPath

        // TODO: Configurable logging format?
        // Should the child workflow inherit the logging level of the parent?
        context.logger.info("Running workflow: \(name ?? W.name)")

        context.stack.pushWorkflow(workflow)
        context.currentWorkflow = workflow

        defer {
            context.currentWorkflow = nil
            context.stack.popWorkflow()

            do {
                try context.fileManager.changeCurrentDirectory(to: currentDirectory)
            } catch {
                context.logger.error("Failed to restore current directory to \(currentDirectory) after running workflow \(W.name).")
            }
        }

        try await workflow.run()
    }
}

public extension StepRunner {
    @discardableResult
    func step<S: Step>(name: String? = nil, _ step: S) async throws -> S.Output {
        let currentStep = context.currentStep
        context.stack.pushStep(step)
        context.currentStep = step
        defer {
            context.currentStep = currentStep
        }
        // TODO: Configurable format?
        context.logger.info("Running step: \(name ?? step.name)")
        return try await step.run()
    }
}

public extension Workflow {
    // TODO: Track which steps were explicitly run by the workflow (current step will be nil when these steps are called.)
    // Or, just show all tasks?
    // Output a summary of the workflow run at the end.
    //  - ✅ Step 1
    //  - ✅ Step 2
    //      - ✅ Substep A
    //      - ✅ Substep B
    //  - ✅ Step 3
    //  - ✅ Workflow A
    //      - ✅ Step A.1
    //          - ✅ Substep A.1.A
    //      - ✅ Step A.2
    //  - ❌ Step 4 (Failed)
    //  - ⤵️ Step 4 (Skipped)

    static func main() async {
        // TODO: Allow for log level to be specified on the command line (either as an argument or an environment variable.)
        // If it's password from the outside, use it instead of the workflow's value.
        context.logger.logLevel = Self.logLevel
        logger.info("Starting Workflow: \(Self.name)")
        logger.debug("Environment:\n\(context.environment._dump())")

        do {
            try setUpWorkspace()
            let workflow = self.init()
            try await workflow.workflow(workflow)
            await cleanUp(error: nil)
            exit(0)
        } catch {
            await cleanUp(error: error)

            let errorLocalizedDescription = error.localizedDescription
            let interpolatedError = "\(error)"
            var errorMessage = "Exiting on error:\n"
            if errorLocalizedDescription != interpolatedError {
                errorMessage += """
                \(errorLocalizedDescription)
                \(interpolatedError)
                """
            } else {
                errorMessage += errorLocalizedDescription
            }

            logger.error("\(errorMessage)")
            exit(1)
        }
    }

    private static func cleanUp(error: Error?) async {
        while let step = context.stack.popStep() {
            logger.info("Cleaning up after step: \(step.name)")
            do {
                try await step.cleanUp(error: error)
            } catch {
                logger.error("Failed to clean up after \(step.name): \(error)")
            }
        }
    }
}

// MARK: - Workspace

enum WorkflowWorkspaceKey: ContextKey {
    // We need a safe default, and the safest place I can think of is the temp directory.
    static let defaultValue = FileManager.default.temporaryDirectory.path
}

public extension ContextValues {
    var workspace: String {
        get { self[WorkflowWorkspaceKey.self] }
        set { self[WorkflowWorkspaceKey.self] = newValue }
    }
}

extension Workflow {
    private static func setUpWorkspace() throws {
        let workspace = try context.environment.github.$workspace.require()
        logger.debug("Setting current directory: \(workspace)")
        try context.fileManager.changeCurrentDirectory(to: workspace)
        context.workspace = workspace
    }
}

// MARK: - Workflow Error

struct InternalWorkflowError: LocalizedError {
    let message: String
    private let file: StaticString
    private let line: UInt
    private let function: StaticString

    var errorDescription: String? {
        """
        Internal Workflow Error: \(message)
        (file: \(file), line: \(line), function: \(function))
        """
    }

    init(message: String, file: StaticString = #fileID, line: UInt = #line, function: StaticString = #function) {
        self.message = message
        self.file = file
        self.line = line
        self.function = function
    }
}

// MARK: - Current Workflow/Step

enum CurrentWorkflowKey: ContextKey {
    static let defaultValue: (any Workflow)? = nil
}

public extension ContextValues {
    internal(set) var currentWorkflow: (any Workflow)? {
        get { self[CurrentWorkflowKey.self] }
        set { self[CurrentWorkflowKey.self] = newValue }
    }
}

enum CurrentStepKey: ContextKey {
    static var defaultValue: (any Step)?
}

public extension ContextValues {
    internal(set) var currentStep: (any Step)? {
        get { self[CurrentStepKey.self] }
        set { self[CurrentStepKey.self] = newValue }
    }
}

// MARK: - Workflow Stack

struct WorkflowStack {

    private var workflows = [any Workflow]()
    private var steps = [any Step]()

    mutating func pushWorkflow(_ workflow: any Workflow) {
        workflows.append(workflow)
    }

    @discardableResult
    mutating func popWorkflow() -> (any Workflow)? {
        guard !workflows.isEmpty else {
            return nil
        }

        return workflows.removeLast()
    }

    mutating func pushStep(_ step: any Step) {
        steps.append(step)
    }

    mutating func popStep() -> (any Step)? {
        guard !steps.isEmpty else {
            return nil
        }

        return steps.removeLast()
    }

    func inheritWorkflow<W>(_ workflowType: W.Type) -> W? {
        for workflow in workflows.lazy.reversed() {
            if let targetType = workflow as? W {
                return targetType
            }
        }

        return nil
    }
}

extension ContextValues {
    public func inheritWorkflow<W>(_ workflowType: W.Type) -> W? {
        stack.inheritWorkflow(workflowType)
    }
}

extension WorkflowStack: ContextKey {
    static let defaultValue = WorkflowStack()
}

private extension ContextValues {
    var stack: WorkflowStack {
        get { self[WorkflowStack.self] }
        set { self[WorkflowStack.self] = newValue }
    }
}
