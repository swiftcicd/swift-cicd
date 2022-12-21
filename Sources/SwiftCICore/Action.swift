import Foundation
import Logging

public protocol Action<Output>: ContextAware {
    associatedtype Output
    var name: String { get }
    func run() async throws -> Output
    func cleanUp(error: Error?) async throws
}

public extension Action {
    var name: String { "\(Self.self)" }
    func cleanUp(error: Error?) async throws {}
}

public extension Action {
    // TODO: Allow the action's name to be overridden by the caller

    @discardableResult
    func action<A: Action>(_ action: A) async throws -> A.Output {
        let parent = context.currentStackFrame
        let frame = ActionStack.Frame(action: action, parent: parent)
        context.stack.push(frame)

        return try await ContextValues.withValue(\.currentStackFrame, frame) {
            // Restore current working directory after the action runs.
            let cachedCurrentDirectory = context.fileManager.currentDirectoryPath
            defer {
                do {
                    try context.fileManager.changeCurrentDirectory(cachedCurrentDirectory)
                } catch {
                    logger.error("Failed to restore current working directory")
                }
            }

            let output = try await context.withLogGroup(named: "Action: \(action.name)") {
                try await action.run()
            }

            return output
        }
    }

    func action(_ selection: () async throws -> (any Action<Void>)?) async throws {
        try await context.withLogGroup(named: "Selecting which action to run next...") {
            guard let action = try await selection() else {
                logger.info("No action selected")
                return
            }

            logger.info("Selected: \(action.name)")
            try await self.action(action)
        }
    }
}
