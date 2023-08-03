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

    func getCurrentWorkflowRunJobs() async throws -> [Job] {
        let (owner, repository) = try context.environment.github.requireOwnerRepository()
        let runID = try context.environment.github.$runID.require()
        let attempt = try context.environment.github.$runAttempt.require()
        return try await context.githubAPI.listJobs(owner: owner, repository: repository, runID: runID, attemptNumber: attempt)
    }

    func getCurrentWorkflowRunJob(named jobName: String? = nil) async throws -> Job {
        let jobs = try await getCurrentWorkflowRunJobs()
        // github.job (GITHUB_JOB) returns the job.id which is the unique id of the job *not* the job.name:
        // https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_id
        //
        // So if the user has specified a name for their job (job.name) in their workflow yaml file, the github.job won't match.
        // https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idname
        let jobName = try jobName ?? context.environment.github.$job.require()

        // Look for the job by name. Otherwise, just return the first job.
        if let job = jobs.first(where: { $0.name == jobName }) {
            context.logger.info("Found current workflow run job named '\(jobName)'")
            return job
        } else if jobs.count == 1 {
            // Otherwise just return the first job in the list (if it's the only one.)
            let job = jobs[0]
            context.logger.info("Couldn't find current workflow job named '\(jobName)', returning the only job in the list: '\(job.name)'.")
            return job
        } else {
            throw ActionError("Couldn't find current workflow job named '\(jobName)'. Available jobs are: \(jobs.map { "'\($0.name)'" }.joined(separator: ", "))")
        }
    }
}
