public struct Run<Output>: _BuilderAction {
    public let name: String
    let action: () async throws -> Output

    public init(_ name: String? = nil, _ action: @escaping () async throws -> Output) {
        self.name = name ?? "Run"
        self.action = action
    }

    public func run() async throws -> Output {
        try await action()
    }
}
