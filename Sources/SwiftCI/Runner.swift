public protocol StepRunner {
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

public protocol WorkflowRunner {
    func workflow<W: Workflow>(name: String?, _ workflow: W) async throws
}

public extension WorkflowRunner {
    func workflow<W: Workflow>(_ workflow: W) async throws {
        try await self.workflow(name: nil, workflow)
    }

    func workflow<W: Workflow>(name: String? = nil, _ workflow: () -> W) async throws {
        try await self.workflow(name: nil, workflow())
    }
}
