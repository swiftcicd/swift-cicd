public struct Recover<A: Action, R: Action>: _BuilderAction {
    let action: () -> A
    let recoveryAction: (Error) -> R

    public init(
        @ActionBuilder action: @escaping () -> A,
        @ActionBuilder `catch` recoveryAction: @escaping (Error) -> R
    ) {
        self.action = action
        self.recoveryAction = recoveryAction
    }

    public func run() async throws {
        let action = action()
        do {
            try await self.run(action)
        } catch {
            let recoveryAction = recoveryAction(error)
            logger.info("\(action.name) failed. Recovering by running \(recoveryAction.name). Error: \(error)")
            try await self.run(recoveryAction)
        }
    }
}
