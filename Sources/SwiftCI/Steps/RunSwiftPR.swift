import OctoKit
import SwiftPR

public struct RunSwiftPR: Step {
    let prCheck: PRCheck.Type

    public init(prCheck: PRCheck.Type) {
        self.prCheck = prCheck
    }

    public struct Output {
        let status: Status.State
    }

    public func run() async throws -> Output {
        try await prCheck.main()
        let status = prCheck.statusState
        return Output(status: status)
    }
}

public extension StepRunner {
    func runSwiftPR(_ prCheck: PRCheck.Type) async throws -> RunSwiftPR.Output {
        try await step(RunSwiftPR(prCheck: prCheck))
    }
}
