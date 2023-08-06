public struct _Then<Wrapped: Action, Next: Action>: _BuilderAction {
    let wrapped: Wrapped
    let next: (Wrapped.Output) -> Next

    init(wrapped: Wrapped, next: @escaping (Wrapped.Output) -> Next) {
        self.wrapped = wrapped
        self.next = next
    }

    public func run() async throws -> () {
        let output = try await self.run(wrapped)
        try await self.run(next(output))
    }
}

public extension Action {
    func then<Next: Action>(@ActionBuilder _ next: @escaping (Output) -> Next) -> _Then<Self, Next> {
        _Then(wrapped: self, next: next)
    }
}
