/// An `ActionBuilder` entry point.
public struct Actions<A: Action>: _BuilderAction {
    let inner: A

    public init(@ActionBuilder _ actions: () -> A) {
        self.inner = actions()
    }

    public func run() async throws {
        try await run(inner)
    }
}

public extension Action {
    /// An entry point to run a list of actions using a `ActionBuilder` from another action's `run` method.
    /// This can be thought of as an "escape hatch" from imperative actions to declarative actions.
    func actions<A: Action>(@ActionBuilder _ actions: @escaping () -> A) async throws {
        try await self.run(Actions(actions))
    }
}
