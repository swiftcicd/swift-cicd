import OctoKit
import SwiftCICDCore
import SwiftCICDPlatforms

public struct GitHub: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var github: GitHub { GitHub(caller: self) }
}


public extension GitHub {
    var gitHubPullRequestNumber: Int {
        get throws {
            guard let pullRequestNumber = context.environment.github.pullRequestNumber ?? context.environment.github.event?.pullRequest?.number else {
                throw ActionError("Couldn't determine pull request number")
            }

            return pullRequestNumber
        }
    }

    func getWorkflowRuns(where predicate: (Run) -> Bool = { _ in true }) async throws -> [Run] {
        let (owner, repository) = try context.environment.github.requireOwnerRepository()
        let workflow = try context.environment.github.workflowFilename
        let runs = try await context.githubAPI.listRuns(owner: owner, repository: repository, workflow: workflow)
        return runs.filter(predicate)
    }

    func getWorkflowRunsForCurrentPullRequest() async throws -> [Run] {
        let pullRequestNumber = try gitHubPullRequestNumber
        return try await getWorkflowRuns(where: { run in
            run.pullRequests?.contains(where: { $0.number == pullRequestNumber }) ?? false
        })
    }

    func cancelWorkflowRun(id runID: Int) async throws {
        let (owner, repository) = try context.environment.github.requireOwnerRepository()
        try await context.githubAPI.cancelRun(owner: owner, repository: repository, runID: runID)
    }
}
