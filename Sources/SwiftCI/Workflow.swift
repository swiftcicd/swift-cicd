import Arguments
import Foundation
import Logging

// TODO: Would it be possible to make swift-ci run as a subcommand of swift?
//  - So instead of: swift run name-of-executable
//  - It would be: swift ci

// TODO: Should a workflow have an Outcome (success, failure, etc.) kind of like how a step has an output?

public protocol Workflow {
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
    static var context: ContextValues { .shared }
    var context: ContextValues { .shared }

    func workflow<W: Workflow>(_ workflow: W) async throws {
        // TODO: Configurable logging format?
        // Should the child workflow inherit the logging level of the parent?
        logger.info("Workflow: \(W.name)")
        try await workflow.run()
    }

    func workflow(_ workflow: () -> some Workflow) async throws {
        try await self.workflow(workflow())
    }

    @discardableResult
    func step<S: Step>(_ step: S) async throws -> S.Output {
        // TODO: Configurable logging format?
        logger.info("Step: \(step.name)")
        return try await step.run()
    }

    @discardableResult
    func step<S: Step>(_ step: () -> S) async throws -> S.Output {
        try await self.step(step())
    }
}

public extension Workflow {
    static func main() async {
        do {
            context.logger.logLevel = Self.logLevel
            logger.info("Starting Workflow: \(Self.name)")
            try setUpWorkspace()
            let workflow = self.init()
            try await workflow.run()
            exit(0)
        } catch {
            logger.error("""
            Caught error: \(error.localizedDescription)
            \(error)
            """)
            exit(1)
        }
    }

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
        guard context.fileManager.changeCurrentDirectoryPath(workspace) else {
            throw InternalWorkflowError(message: "Failed to set current directory")
        }
    }
}

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
