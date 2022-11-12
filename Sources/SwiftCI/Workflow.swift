import Foundation

public protocol Workflow {
    static var name: String { get }
    init()
    func run() async throws
}

public extension Workflow {
    static var name: String {
        "\(self)"
    }
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
            print("Starting Workflow: \(Self.name)")

            let workspace = try context.environment.github.$workspace.require()
            context.fileManager.changeCurrentDirectoryPath(workspace)

            let workflow = self.init()
            try await workflow.run()

            exit(0)
        } catch {
            print("""
            Caught error: \(error.localizedDescription)
            \(error)
            """)
            exit(1)
        }
    }
}
