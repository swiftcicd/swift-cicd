import SwiftPR

public struct RunSwiftPR: Step {
    let prCheck: PRCheck

    public init(prCheck: PRCheck) {
        self.prCheck = prCheck
    }

    public func run() async throws {
        try await type(of: prCheck).main()
    }
}

public extension StepRunner {
    func swiftPR(_ prCheck: PRCheck) async throws {
        try await step(RunSwiftPR(prCheck: prCheck))
    }
}
