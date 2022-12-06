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
        // FIXME: If the swift-pr comment is created for the first time it may be slow to appear on the API.
        // We may need to introduce a slight delay here, or potentially a retry.
        // Try 3 times with one, two, three seconds in between before failing?
        return try await retry(atIntervals: [0, 1, 2, 3, 5, 10, 15, 30]) {
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

enum RetryError: Error {
    case retryFailedAfterAllAttempts
}

func retry<R>(atIntervals backoff: [Double], operation: () async throws -> R) async throws -> R {
    var backoff = backoff
    while !backoff.isEmpty {
        let delay = backoff.removeFirst()
        if delay > 0 {
            ContextValues.shared.logger.debug("Retrying in \(delay)...")
            try await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(delay))
        }

        do {
            let result = try await operation()
            return result
        } catch {
            ContextValues.shared.logger.debug("Attempt failed: \(error)")

            if backoff.isEmpty {
                ContextValues.shared.logger.debug("All attempts failed. Not retrying.")
                throw error
            }
        }
    }

    throw RetryError.retryFailedAfterAllAttempts
}
