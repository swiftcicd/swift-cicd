import Foundation

public protocol Workflow {
    static var name: String { get }
    init()
    func run() async throws
}

public extension Workflow {

    static var context: ContextValues { .shared }
    var context: ContextValues { .shared }

    func workflow(_ workflow: any Workflow) async throws {
        try await workflow.run()
    }

    @discardableResult
    func step<S: Step>(_ step: S) async throws -> S.Output {
        try await step.run()
    }

    static func main() async {
        do {
            let workspace = try context.environment.github.$workspace.require()
            context.fileManager.changeCurrentDirectoryPath(workspace)

            let workflow = self.init()
            try await workflow.run()

            exit(0)
        } catch {
            exit(1)
        }
    }
}

// Make a Context object that Workflow instances can access
// context.fileManager
// context.github
// context.environment
// context.git
// context.secrets

// Or workflows and steps should reach into the context via
// @Context(\.environment) var environment
// to grab whatever context they need to do their work

// Steps should be able to extend the context (almost like dependency values)
// context.swiftPR
