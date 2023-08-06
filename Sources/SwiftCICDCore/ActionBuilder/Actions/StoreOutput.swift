public struct _StoreOutput<Wrapped: Action>: _BuilderAction {
    let value: Value<Wrapped.Output>
    let action: Wrapped

    public func run() async throws {
        let output = try await self.run(action)
        value.wrappedValue = output
    }
}

public struct _StoreOptionalOutput<Wrapped: Action>: _BuilderAction {
    let value: Value<Optional<Wrapped.Output>>
    let action: Wrapped

    public func run() async throws {
        let output = try await self.run(action)
        value.wrappedValue = output
    }
}

extension Action {
    public func storeOutput(in value: Value<Output>) -> _StoreOutput<Self> {
        _StoreOutput(value: value, action: self)
    }

    public func storeOutput(in value: Value<Optional<Output>>) -> _StoreOptionalOutput<Self> {
        _StoreOptionalOutput(value: value, action: self)
    }
}
