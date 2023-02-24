import OctoKit
import SwiftCICore
import SwiftCIPlatforms

public struct CancelGitHubActionWorkflowRuns: Action {
    let predicate: (Run) -> Bool

    init(where predicate: @escaping (Run) -> Bool) {
        self.predicate = predicate
    }

    public func run() async throws {
        let runsToCancel = try await getCurrentWorkflowRuns(where: predicate)
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
        let pullReuqestNumber = try context.environment.github.requirePullRequestNumber()
        try await cancelGitHubActionWorkflowRuns { run in
            run.pullRequests?.contains(where: { $0.number == pullReuqestNumber }) ?? false
                && run.status == .queued || run.status == .inProgress
                && predicate(run)
        }
    }
}
