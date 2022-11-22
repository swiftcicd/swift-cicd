public protocol StepRunner: ContextAware {
    // TODO: Add a retry parameter? It could be useful to retry a step a number of times. For instance, when uploading to App Store Connect.

    @discardableResult
    func step<S: Step>(name: String?, _ step: S) async throws -> S.Output
}

public extension StepRunner {
    @discardableResult
    func step<S: Step>(_ step: S) async throws -> S.Output {
        try await self.step(name: nil, step)
    }

    @discardableResult
    func step<S: Step>(name: String? = nil, _ step: () -> S) async throws -> S.Output {
        try await self.step(name: name, step())
    }
}

public protocol WorkflowRunner: ContextAware {
    func workflow<W: Workflow>(name: String?, _ workflow: W) async throws
}

public extension WorkflowRunner {
    func workflow<W: Workflow>(_ workflow: W) async throws {
        try await self.workflow(name: nil, workflow)
    }

    func workflow(name: String? = nil, _ workflow: () -> any Workflow) async throws {
        try await self.workflow(name: nil, workflow())
    }

    func workflow(name: String? = nil, _ workflow: () -> (any Workflow)?) async throws {
        guard let workflow = workflow() else {
            return
        }

        try await self.workflow(name: nil, workflow)
    }
}
