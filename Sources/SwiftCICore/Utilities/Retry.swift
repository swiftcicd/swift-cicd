import Foundation

public enum RetryError: Error {
    case retryFailedAfterAllAttempts
}

public func retry<R>(every interval: Double, times: Int, operation: () async throws -> R) async throws -> R {
    try await retry(atIntervals: Array(repeating: interval, count: times), operation: operation)
}

public func retry<R>(atIntervals intervals: [Double], operation: () async throws -> R) async throws -> R {
    @Context(\.logger) var logger
    var backoff = intervals
    repeat {
        do {
            let result = try await operation()
            if intervals.count != backoff.count {
                let attempts = intervals.count - backoff.count
                logger.debug("Successful after \(attempts) retry attempt(s)")
            }
            return result
        } catch {
            logger.debug("Attempt failed: \(error)")

            if backoff.isEmpty {
                logger.debug("All attempts failed. Not retrying.")
                throw error
            }
        }

        let delay = backoff.removeFirst()
        logger.debug("Retrying in \(delay)...")
        try await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(delay))
    } while !backoff.isEmpty

    // Should be unreachable.
    throw RetryError.retryFailedAfterAllAttempts
}
