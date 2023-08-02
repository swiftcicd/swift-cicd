public protocol ActionNamespace: ContextAware {
    var caller: any Action { get }
}

public extension ActionNamespace {
    @discardableResult
    func run<A: Action>(_ action: A) async throws -> A.Output {
        try await caller.run(action)
    }
}
