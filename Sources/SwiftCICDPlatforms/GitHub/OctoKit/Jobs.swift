// Modeling this code off of OctoKit's own sources

#if canImport(FoundationNetworking)
import FoundationNetworking
#else
import Foundation
#endif
import OctoKit
import SwiftCICDCore
import RequestKit

// MARK: Model

open class Job: Codable {
    open internal(set) var id: Int = -1
    open var name: String
    open var htmlURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case htmlURL = "html_url"
    }
}

private struct ListJobsResponse: Codable {
    let jobs: [Job]
}

// MARK: Request

public extension Octokit {
    func listJobs(
        _ session: RequestKitURLSession = URLSession.shared,
        owner: String,
        repository: String,
        runID: Int,
        attemptNumber: Int
    ) async throws -> [Job] {
        let router = JobsRouter.listJobsForWorkflowRunAttempt(configuration, owner: owner, repository: repository, runID: runID, attemptNumber: attemptNumber)
        return try await router.load(session, dateDecodingStrategy: .formatted(Time.rfc3339DateFormatter), expectedResultType: ListJobsResponse.self).jobs
    }
}

// MARK: Router

enum JobsRouter: Router {
    case listJobsForWorkflowRunAttempt(Configuration, owner: String, repository: String, runID: Int, attemptNumber: Int)

    var configuration: Configuration {
        switch self {
        case let .listJobsForWorkflowRunAttempt(config, _, _, _, _): return config
        }
    }

    var method: HTTPMethod {
        return .GET
    }

    var encoding: HTTPEncoding {
        return .url
    }

    var path: String {
        switch self {
        case let .listJobsForWorkflowRunAttempt(_, owner, repository, runID, attemptNumber):
            return "repos/\(owner)/\(repository)/actions/runs/\(runID)/attempts/\(attemptNumber)/jobs"
        }
    }

    var params: [String: Any] {
        return [:]
    }
}

public extension Action {
    func getCurrentWorkflowRunJobs() async throws -> [Job] {
        let (owner, repository) = try context.environment.github.requireOwnerRepository()
        let runID = try context.environment.github.$runID.require()
        let attempt = try context.environment.github.$runAttempt.require()
        return try await context.githubAPI.listJobs(owner: owner, repository: repository, runID: runID, attemptNumber: attempt)
    }

    func getCurrentWorkflowRunJob(named jobName: String? = nil) async throws -> Job {
        let jobs = try await getCurrentWorkflowRunJobs()
        let jobName = try jobName ?? context.environment.github.$job.require()
        guard let job = jobs.first(where: { $0.name == jobName }) else {
            throw ActionError("Couldn't find current workflow job named '\(jobName)'")
        }
        return job
    }
}
