import Foundation

final class ActionStack {
    final class Frame {
        let id = UUID()
        let action: any Action
        let parent: Frame?

        init(action: any Action, parent: Frame?) {
            self.action = action
            self.parent = parent
        }
    }

    struct Trace: CustomStringConvertible {
        var frames = [Frame]()
        var includeBuilderActions: Bool = false

        var description: String {
            frames
                .filter {
                    includeBuilderActions ? true : !$0.action.isBuilder
                }
                .map(\.action.name)
                .joined(separator: " → ")
        }
    }

    private var stack = [Frame]()

    var root: (any Action)? {
        stack.first?.action
    }

    func push(_ frame: Frame) {
        stack.append(frame)
    }

    func pop() -> Frame? {
        guard !stack.isEmpty else {
            return nil
        }

        return stack.removeLast()
    }

    func peak() -> Frame? {
        stack.last
    }

    func trace(frame: Frame, includeBuilderActions: Bool = false) -> Trace {
        guard var frame = stack.first(where: { $0.id == frame.id }) else {
            return Trace()
        }

        var trace = [frame]
        while let parent = frame.parent {
            trace.append(parent)
            frame = parent
        }

        return Trace(
            frames: trace.reversed(),
            includeBuilderActions: includeBuilderActions
        )
    }

    func traceLastFrame(includeBuilderActions: Bool = false) -> Trace? {
        guard let lastFrame = peak() else {
            return nil
        }

        return trace(frame: lastFrame, includeBuilderActions: includeBuilderActions)
    }

    func generateTable(finalActionFailed: Bool, onlyIncludeActionsRunByMainAction: Bool = true, includeBuilderActions: Bool = false) -> Table {
        let frames = stack
            .filter { onlyIncludeActionsRunByMainAction ? $0.isRunByMain : true }
            .filter { includeBuilderActions ? true : !$0.action.isBuilder }

        return Table(
            headers: [nil, "Action"],
            rows: frames.indices.map {
                [$0 == frames.index(before: frames.endIndex) ? (finalActionFailed ? "x" : "✓") : "✓", frames[$0].action.name]
            }
        )
    }
}

extension ActionStack.Frame {
    var isRunByMain: Bool {
        var current = parent
        while let c = current {
            // Skip builder actions
            if c.action.isBuilder {
                current = current?.parent
            } else {
                return c.action.isMain
            }
        }
        return false
    }
}

extension ContextValues {
    private enum ActionStackKey: ContextKey {
        static let defaultValue = ActionStack()
    }

    var stack: ActionStack {
        get { self[ActionStackKey.self] }
        set { self[ActionStackKey.self] = newValue }
    }
}

extension ContextValues {
    private enum CurrentActionStackFrame: ContextKey {
        static var defaultValue: ActionStack.Frame?
    }

    var currentStackFrame: ActionStack.Frame? {
        get { self[CurrentActionStackFrame.self] }
        set { self[CurrentActionStackFrame.self] = newValue }
    }

    var currentAction: (any Action)? {
        currentStackFrame?.action
    }
}

extension ActionStack {
    func inherit<A>(_ action: A.Type) -> A? {
        stack.lazy.reversed().compactMap { $0.action as? A }.first
    }
}

public extension ContextValues {
    func inherit<A>(_ action: A.Type) -> A? {
        stack.inherit(action)
    }
}
