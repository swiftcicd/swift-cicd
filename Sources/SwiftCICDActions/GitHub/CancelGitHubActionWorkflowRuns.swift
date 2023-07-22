import Foundation
import OctoKit
import SwiftCICDCore
import SwiftCICDPlatforms

public struct GitHubActionWorkflowRunCancelled: LocalizedError {
    let cancelledRunNumber: Int
    let newerRunNumber: Int

    public var errorDescription: String? {
        // NOTE: Using one of the error prefixes that will cause this error to be picked up as an error preview.
        // It would be nice to have a static property that can be referenced though.
        // FIXME: The error isn't getting picked up for previewing even though it has the right prefix.
        "error: Cancelling run \(cancelledRunNumber) in favor of run \(newerRunNumber)."
    }
}

public struct CancelGitHubActionWorkflowRuns: Action {
    let runsToCancel: [Int]

    init(runs: [Run]) {
        self.runsToCancel = runs.map(\.id)
    }

    init(runIDs: [Int]) {
        self.runsToCancel = runIDs
    }

    public func run() async throws {
        if runsToCancel.isEmpty {
            logger.info("No existing workflow runs to cancel")
            return
        }

        for runID in runsToCancel {
            do {
                logger.info("Cancelling existing workflow run \(runID)")
                try await cancelWorkflowRun(id: runID)
            } catch {
                logger.error("Failed to cancel workflow run: \(runID)")
            }
        }
    }
}

public extension Action {
    func cancelGitHubActionWorkflowRuns(where predicate: (Run) -> Bool = { _ in true }) async throws {
        let runs = try await getWorkflowRuns(where: predicate)
        try await action(CancelGitHubActionWorkflowRuns(runs: runs))
    }

    func cancelOtherExistingGitHubActionWorkflowRunsForCurrentPullRequest(where predicate: (Run) -> Bool = { _ in true }) async throws {
        let currentRunID = try context.environment.github.$runID.require()
        let runs = try await getWorkflowRunsForCurrentPullRequest().filter {
            $0.id != currentRunID
                && $0.status == .queued || $0.status == .inProgress
                && predicate($0)
        }
        return try await action(CancelGitHubActionWorkflowRuns(runs: runs))
    }

    /// Cancels the current GitHub action workflow run if another action is queued and then throws an error to stop the execution.
    func cancelGitHubActionWorkflowRunIfNewerRunForCurrentPullRequestIsQueuedOrInProgress() async throws {
        let currentRunID = try context.environment.github.$runID.require()
        let currentRunNumber = try context.environment.github.$runNumber.require()

        let newerRuns = try await getWorkflowRunsForCurrentPullRequest().filter { otherRun in
            otherRun.id != currentRunID
                && otherRun.runNumber > currentRunNumber
                && (otherRun.status == .queued || otherRun.status == .inProgress)
        }

        if let newerRun = newerRuns.first {
            logger.info("A newer run (\(newerRun.runNumber)) was detected. Cancelling the current run (\(currentRunNumber)).")
            try await cancelWorkflowRun(id: currentRunID)
            throw GitHubActionWorkflowRunCancelled(cancelledRunNumber: currentRunNumber, newerRunNumber: newerRun.runNumber)
        }
    }
}
