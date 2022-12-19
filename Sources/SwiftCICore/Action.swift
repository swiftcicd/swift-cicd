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
            let cachedCurrentDirectory = context.files.currentDirectoryPath
            defer {
                do {
                    try context.files.changeCurrentDirectory(cachedCurrentDirectory)
                } catch {
                    logger.error("Failed to restore current working directory")
                }
            }

            let output = try await context.performInLogGroup(named: action.name) {
                try await action.run()
            }

            return output
        }
    }
}

@propertyWrapper
public struct State<T> {
    private class Storage {
        var state: T

        init(state: T) {
            self.state = state
        }
    }

    private let storage: Storage

    public init(wrappedValue: T) {
        self.storage = Storage(state: wrappedValue)
    }

    public var wrappedValue: T {
        get { storage.state }
        nonmutating set { storage.state = newValue }
    }
}
