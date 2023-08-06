import Foundation

public enum RetryError: Error {
    case retryFailed
    case retryFailedAfterAllAttempts(Error)
}

public extension Action {
    func retry<R>(every interval: Double, times: Int, operation: () async throws -> R) async throws -> R {
        try await retry(atIntervals: Array(repeating: interval, count: times), operation: operation)
    }

    func retry<R>(atIntervals intervals: [Double], operation: () async throws -> R) async throws -> R {
        var backoff = intervals
        repeat {
            do {
                let result = try await operation()
                if intervals.count != backoff.count {
                    let attempts = intervals.count - backoff.count
                    logger.debug("Successful after \(attempts) retry attempt\(attempts == 1 ? "" : "s")")
                }
                return result
            } catch {
                logger.debug("Retry attempt failed: \(error)")

                if backoff.isEmpty {
                    logger.debug("All retry attempts failed.")
                    throw RetryError.retryFailedAfterAllAttempts(error)
                }
            }

            let delay = backoff.removeFirst()
            logger.debug("Retrying in \(delay)...")
            if #available(macOS 13.0, *) {
                try await Task.sleep(for: .seconds(delay))
            } else {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(delay))
            }
        } while !backoff.isEmpty

        // Should be unreachable.
        throw RetryError.retryFailed
    }
}
