public struct RequireValue<V, WrappedAction: Action>: _BuilderAction {
    let wrappedAction: (V) -> WrappedAction
    var getValue: () throws -> V

    @_disfavoredOverload
    public init(
        _ value: Value<V>,
        @ActionBuilder _ action: @escaping (V) -> WrappedAction
    ) {
        wrappedAction = action
        getValue = { value.wrappedValue }
    }

    @_disfavoredOverload
    public init<T>(
        _ value: Value<T>,
        _ keyPath: KeyPath<T, Optional<V>>,
        file: StaticString = #file, line: UInt = #line,
        @ActionBuilder _ action: @escaping (V) -> WrappedAction
    ) {
        wrappedAction = action
        getValue = {
            guard let input = value.wrappedValue[keyPath: keyPath] else {
                throw ActionError("Required keyPath on Value was nil.", file: file, line: line)
            }

            return input
        }
    }

    public init(
        _ value: Value<Optional<V>>,
        file: StaticString = #file, line: UInt = #line,
        @ActionBuilder _ action: @escaping (V) -> WrappedAction
    ) {
        wrappedAction = action
        getValue = {
            guard let input = value.wrappedValue else {
                throw ActionError("Required Value was nil.", file: file, line: line)
            }

            return input
        }
    }

    @_disfavoredOverload
    public init<T>(
        _ value: Value<Optional<T>>,
        _ keyPath: KeyPath<T, V>,
        file: StaticString = #file, line: UInt = #line,
        @ActionBuilder _ action: @escaping (V) -> WrappedAction
    ) {
        wrappedAction = action
        getValue = {
            guard let input = value.wrappedValue?[keyPath: keyPath] else {
                throw ActionError("Required Value was nil.", file: file, line: line)
            }

            return input
        }
    }

    public init<T>(
        _ value: Value<Optional<T>>,
        _ keyPath: KeyPath<T, Optional<V>>,
        file: StaticString = #file, line: UInt = #line,
        @ActionBuilder _ action: @escaping (V) -> WrappedAction
    ) {
        wrappedAction = action
        getValue = {
            guard let value = value.wrappedValue else {
                throw ActionError("Required Value was nil.", file: file, line: line)
            }

            guard let input = value[keyPath: keyPath] else {
                throw ActionError("Required keyPath on Value was nil.", file: file, line: line)
            }

            return input
        }
    }

    public func run() async throws {
        let value = try getValue()
        try await self.run(wrappedAction(value))
    }
}
