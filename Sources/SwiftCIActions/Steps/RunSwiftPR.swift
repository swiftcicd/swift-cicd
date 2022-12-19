import Foundation
import OctoKit
import SwiftPR

public struct RunSwiftPR: Step {
    let prCheck: PRCheck.Type

    public init(prCheck: PRCheck.Type) {
        self.prCheck = prCheck
    }

    public struct Output {
        public let status: Status.State
        public let comment: Comment
    }

    public func run() async throws -> Output {
        try await prCheck.main()
        let status = prCheck.statusState
        // If the swift-pr comment is created for the first time it may be slow to appear on the API.
        // It usually appears between 30 and 60 seconds.
        return try await retry(every: 15, times: 5) {
            guard let comment = try await prCheck.getSwiftPRComment() else {
                throw StepError("SwiftPR comment not found")
            }

            return Output(status: status, comment: comment)
        }
    }
}

public extension StepRunner {
    @discardableResult
    func runSwiftPR(_ prCheck: PRCheck.Type) async throws -> RunSwiftPR.Output {
        try await step(RunSwiftPR(prCheck: prCheck))
    }
}
