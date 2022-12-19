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

        var description: String {
            frames.map(\.action.name).joined(separator: " → ")
        }
    }

    private var stack = [Frame]()

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

    func trace(frame: Frame) -> Trace {
        guard var frame = stack.first(where: { $0.id == frame.id }) else {
            return Trace()
        }

        var trace = [frame]
        while let parent = frame.parent {
            trace.append(parent)
            frame = parent
        }
        return Trace(frames: trace.reversed())
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
