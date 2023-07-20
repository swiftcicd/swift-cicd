import Logging

public protocol Action<Output>: ContextAware {

    /// The resulting output from running this action.
    ///
    /// Actions collaborate and communicate with other actions via their output.
    /// If the action doesn't need to communicate with other actions, the output can be `Void`.
    associatedtype Output

    /// The name of this action as it will appear in logs.
    var name: String { get }

    /// The main lifecycle hook where the action is run and returns its output.
    ///
    /// - Returns: The resulting output of running this action.
    func run() async throws -> Output

    /// A lifecycle hook where the action can optionally clean itself up.
    ///
    /// If the action installed any tools, they should be uninstalled; if the action modified the
    /// file system, it should restore it to its previous state; etc..
    ///
    /// - Parameter error: If the action is cleaning up because an error was thrown in the
    /// pipeline, this value will be non-nil. Otherwise, if the action is cleaning up after a successful run,
    /// this value will be `nil`.
    func cleanUp(error: Error?) async throws
}

public extension Action {
    var name: String {
        "\(Self.self)".addingSpacesBetweenWords
    }

    func cleanUp(error: Error?) async throws {
        // Default is no-op.
    }
}

extension Action {
    var rootMainAction: (any MainAction)? {
        context.stack.root as? any MainAction
    }
}

public extension Action {
    @discardableResult
    func action<A: Action>(_ action: A) async throws -> A.Output {
        try await self.action(nil, action)
    }

    @discardableResult
    func action<A: Action>(_ name: String? = nil, _ action: A) async throws -> A.Output {
        let name = name ?? action.name
        let parent = context.currentStackFrame
        let frame = ActionStack.Frame(action: action, parent: parent)
        context.stack.push(frame)

        if !context.isRunningBeforeAction, let rootMainAction {
            try await ContextValues.withValue(\.isRunningBeforeAction, true) {
                try await rootMainAction.before()
            }
        }

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

            let output: A.Output

            if try context.platform.supportsNestedLogGroups {
                output = try await context.withLogGroup(named: "Action: \(name)") {
                    try await action.run()
                }
            } else {
                // Only start a log group if the action's parent (or the action itself) is a MainAction on platforms that don't support nested log groups.
                if parent?.action is any MainAction || action is any MainAction {
                    output = try await context.withLogGroup(named: "Action: \(name)") {
                        try await action.run()
                    }
                } else {
                    // Otherwise, just log the action without a log group.
                    logger.info("Action: \(name)")
                    output = try await action.run()
                }
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
