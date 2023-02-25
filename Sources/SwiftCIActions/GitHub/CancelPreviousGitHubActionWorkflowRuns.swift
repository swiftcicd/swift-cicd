import OctoKit
import SwiftCICore
import SwiftCIPlatforms

public struct CancelGitHubActionWorkflowRuns: Action {
    let predicate: (Run) -> Bool

    init(where predicate: @escaping (Run) -> Bool) {
        self.predicate = predicate
    }

    public func run() async throws {
        let currentRunID = try context.environment.github.$runID.require()
        let runsToCancel = try await getCurrentWorkflowRuns(where: predicate).filter {
            // Never cancel the current run
            $0.id != currentRunID
        }

        if runsToCancel.isEmpty {
            logger.info("No existing workflow runs to cancel")
            return
        }

        for run in runsToCancel {
            do {
                logger.info("Cancelling existing workflow run \(run.id)")
                try await cancelWorkflowRun(id: run.id)
            } catch {
                logger.error("Failed to cancel workflow run: \(run.id)")
            }
        }
    }
}

public extension Action {
    func cancelGitHubActionWorkflowRuns(where predicate: @escaping (Run) -> Bool = { _ in true }) async throws {
        try await action(CancelGitHubActionWorkflowRuns(where: predicate))
    }

    func cancelExistingGitHubActionWorkflowRunsForCurrentPullRequest(where predicate: @escaping (Run) -> Bool = { _ in true }) async throws {
        guard let pullReuqestNumber = context.environment.github.pullRequestNumber ?? context.environment.github.event?.pullRequest?.number else {
            throw ActionError("Couldn't determine pull request number")
        }

        try await cancelGitHubActionWorkflowRuns { run in
            run.pullRequests?.contains(where: { $0.number == pullReuqestNumber }) ?? false
                && run.status == .queued || run.status == .inProgress
                && predicate(run)
        }
    }
}
