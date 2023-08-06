public struct Run<Output>: _BuilderAction {
    let action: () async throws -> Output

    public init(_ action: @escaping () async throws -> Output) {
        self.action = action
    }

    public func run() async throws -> Output {
        try await action()
    }
}
