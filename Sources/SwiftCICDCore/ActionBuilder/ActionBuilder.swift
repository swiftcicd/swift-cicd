/// Marker protocol for specialized actions used by ``ActionBuilder``.
protocol _BuilderAction: Action {}

@resultBuilder
public enum ActionBuilder {
    public static func buildArray<A: Action>(_ actions: [A]) -> _SequenceMany<A> {
        _SequenceMany(actions: actions)
    }

    public static func buildBlock() -> _EmptyAction {
        _EmptyAction()
    }

    public static func buildBlock<A: Action>(_ action: A) -> A {
        action
    }

    public static func buildEither<A0: Action, A1: Action>(first action: A0) -> _Conditional<A0, A1> {
        .first(action)
    }

    public static func buildEither<A0: Action, A1: Action>(second action: A1) -> _Conditional<A0, A1> {
        .second(action)
    }

    public static func buildExpression<A: Action>(_ expression: A) -> A {
        expression
    }

    public static func buildFinalResult<A: Action>(_ action: A) -> A {
        action
    }

    public static func buildLimitedAvailability<A: Action>(_ action: A) -> A {
        action
    }

    public static func buildOptional<A: Action>(_ wrapped: A?) -> _Conditional<A, _EmptyAction> {
        if let wrapped {
            return .first(wrapped)
        } else {
            return .second(_EmptyAction())
        }
    }

    public static func buildPartialBlock<A: Action>(first: A) -> A {
        first
    }

    public static func buildPartialBlock<A0: Action, A1: Action>(
        accumulated: A0, next: A1
    ) -> _Sequence<A0, A1> {
        _Sequence(accumulated, next)
    }

    public struct _EmptyAction: _BuilderAction {
        public func run() async throws -> () {}
    }

    public enum _Conditional<First: Action, Second: Action>: _BuilderAction {
        case first(First)
        case second(Second)

        public func run() async throws {
            switch self {
            case .first(let first):
                try await self.run(first)

            case .second(let second):
                try await self.run(second)
            }
        }
    }

    public struct _Sequence<A0: Action, A1: Action>: _BuilderAction {
        let a0: A0
        let a1: A1

        init(_ a0: A0, _ a1: A1) {
            self.a0 = a0
            self.a1 = a1
        }

        public func run() async throws {
            try await self.run(a0)
            try await self.run(a1)
        }
    }

    public struct _SequenceMany<Element: Action>: _BuilderAction {
        let actions: [Element]

        init(actions: [Element]) {
            self.actions = actions
        }

        public func run() async throws {
            for action in actions {
                try await self.run(action)
            }
        }
    }
}
