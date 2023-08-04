import SwiftCICDCore

public struct WithOutput<Input, WrappedAction: Action>: Action {
    let wrappedAction: (Input) -> WrappedAction
    var getInput: () throws -> Input

    @_disfavoredOverload
    public init(
        _ output: KeyPath<OutputValues, Input>,
        @ActionBuilder _ action: @escaping (Input) -> WrappedAction
    ) {
        wrappedAction = action
        getInput = { Self.context.outputs[keyPath: output] }
    }

    public init(
        _ output: KeyPath<OutputValues, Optional<Input>>,
        file: StaticString = #file, line: UInt = #line,
        @ActionBuilder _ action: @escaping (Input) -> WrappedAction
    ) {
        wrappedAction = action
        getInput = {
            guard let input = Self.context.outputs[keyPath: output] else {
                throw ActionError("Output was missing.", file: file, line: line)
            }

            return input
        }
    }

    public func run() async throws {
        let input = try getInput()
        try await self.run(wrappedAction(input))
    }
}
