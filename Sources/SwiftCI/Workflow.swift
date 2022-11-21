import Arguments
import Foundation
import Logging

// TODO: Should a workflow have an Outcome (success, failure, etc.) kind of like how a step has an output?
// TODO: Would it be possible to make swift-ci run as a subcommand of swift?
//  - So instead of: swift run name-of-executable
//  - It would be: swift ci

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

public extension Workflow {
    func workflow<W: Workflow>(name: String? = nil, _ workflow: W) async throws {
        // Parents are restored to their current directory after a child workflow runs
        let currentDirectory = context.fileManager.currentDirectoryPath
        defer {
            do {
                try context.fileManager.changeCurrentDirectory(to: currentDirectory)
            } catch {
                logger.error("Failed to restore current directory to \(currentDirectory) after running workflow \(W.name).")
            }
        }

        // TODO: Configurable logging format?
        // Should the child workflow inherit the logging level of the parent?
        logger.info("Workflow: \(name ?? W.name)")
        try await workflow.run()
    }

    @discardableResult
    func step<S: Step>(name: String? = nil, _ step: S) async throws -> S.Output {
        context.stack.push(step)
        context.currentStep = step
        defer { context.currentStep = nil }
        // TODO: Configurable format?
        logger.info("Step: \(name ?? step.name)")
        return try await step.run()
    }
}

public extension Step {
    @discardableResult
    func step<S: Step>(name: String? = nil, _ step: S) async throws -> S.Output {
        context.stack.push(step)
        context.currentStep = step
        defer { context.currentStep = self }
        // TODO: Configurable format?
        logger.info("Step: \(name ?? step.name)")
        return try await step.run()
    }
}

public extension Workflow {
    // TODO: Track which steps were explicitly run by the workflow (current step will be nil when these steps are called.)
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

        let workflow = self.init()
        context.currentWorkflow = workflow
        defer { context.currentWorkflow = nil }

        do {
            try setUpWorkspace()
            try await workflow.run()
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
        while let step = context.stack.pop() {
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
        let workspace: String
        if context.environment.github.isCI {
            workspace = try context.environment.github.$workspace.require()
        } else {
            var arguments = Arguments(usage: Usage(
                overview: nil,
                seeAlso: nil,
                commands: [
                    "your-swift-ci-command", .option("workspace", required: true, description: "The root directory of the package.")
                ]
            ))
            workspace = try arguments.consumeOption(named: "--workspace")
        }

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
    private var steps = [any Step]()

    mutating func push(_ step: any Step) {
        steps.append(step)
    }

    mutating func pop() -> (any Step)? {
        guard !steps.isEmpty else {
            return nil
        }

        return steps.removeLast()
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
