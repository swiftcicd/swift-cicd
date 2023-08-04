import Logging

public protocol Action<Output>: ContextAware {

    /// The resulting output from running this action.
    ///
    /// Actions collaborate and communicate with other actions via their output.
    /// If the action doesn't need to communicate with other actions, the output can be `Void`.
    associatedtype Output

    #if DEBUG
    associatedtype _Body: Action
    typealias Body = _Body
    #else
    associatedtype Body: Action
    #endif

    @ActionBuilder
    var body: Body { get }

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

extension Action {
    public func run() async throws {
        try await self.run(body)
    }
}

extension Never: Action {}
extension Action where Body == Never {
    public var body: Body {
        fatalError("Do not invoke body directly.")
    }
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

extension Action {
    var isMain: Bool {
        self is any MainAction
    }

    var isBuilder: Bool {
        self is any _BuilderAction
    }

    var isGroup: Bool {
        self is any _GroupAction
    }

    var isContainer: Bool {
        isBuilder || isGroup
    }

    var isRegular: Bool {
        !(isMain || isBuilder || isGroup)
    }
}

extension ActionStack.Frame {
    var firstNonContainerAncestor: ActionStack.Frame? {
        var current = parent
        while let c = current {
            if !c.action.isBuilder {
                return c
            } else {
                current = current?.parent
            }
        }
        return nil
    }
}

public extension Action {
    // TODO: Re-enable this syntax:
    // try await run("Build for Simulator") { try await xcode.build() }

    @discardableResult
    func run<A: Action>(_ action: A) async throws -> A.Output {
        try await self.run(nil, action)
    }

    @discardableResult
    func run<A: Action>(_ name: String? = nil, _ action: A) async throws -> A.Output {
        // Update the stack
        let parent = context.currentStackFrame
        let frame = ActionStack.Frame(action: action, parent: parent)
        context.stack.push(frame)

        // Run the "before" function
        if !context.isRunningBeforeAction, let rootMainAction {
            try await ContextValues.withValue(\.isRunningBeforeAction, true) {
                try await rootMainAction.before()
            }
        }

        // Run the action with the current stack frame
        return try await ContextValues.withValue(\.currentStackFrame, frame) {
            // Capture the current working directory
            let cachedCurrentDirectory = context.fileManager.currentDirectoryPath

            // Restore current working directory after the action runs.
            defer {
                do {
                    try context.fileManager.changeCurrentDirectory(cachedCurrentDirectory)
                } catch {
                    logger.error("Failed to restore current working directory")
                }
            }

            let output: A.Output
            let actionName = "Action: \(name ?? action.name)"

            // Only start a log group if:
            // - The action is a regular action
            // - The action's first non-container ancestor is a main action
            if action.isRegular, let ancestor = frame.firstNonContainerAncestor, ancestor.action.isMain {
                output = try await context.startingLogGroup(named: actionName) {
                    try await action.run()
                }
            } else {
                // Only log the action's name if:
                // - The action is a regular action
                if action.isRegular {
                    logger.info("\(actionName)")
                }
                output = try await action.run()
            }

            return output
        }
    }
}
