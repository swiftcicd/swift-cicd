import SwiftCICore
import OctoKit

public struct CancelExistingGitHubActionWorkflowRunsForCurrentPullRequest: Action {
    public func run() async throws {
        let pullReuqestNumber = try context.environment.github.requirePullRequestNumber()
        let runsToCancel = try await getCurrentWorkflowRuns {
            $0.pullRequests?.contains(where: { $0.number == pullReuqestNumber }) ?? false
                && $0.status == .queued || $0.status == .inProgress
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
    func cancelExistingGitHubActionWorkflowRunsForCurrentPullRequest() async throws {
        try await action(CancelExistingGitHubActionWorkflowRunsForCurrentPullRequest())
    }
}
