// Modeling this code off of OctoKit's own sources

#if canImport(FoundationNetworking)
import FoundationNetworking
#else
import Foundation
#endif
import OctoKit
import SwiftCICore
import RequestKit

// MARK: Model

open class Run: Codable {
    public enum Status: String, Codable {
        case completed = "completed"
        case actionRequired = "action_required"
        case cancelled = "cancelled"
        case failure = "failure"
        case neutral = "neutral"
        case skipped = "skipped"
        case stale = "stale"
        case success = "success"
        case timedOut = "timed_out"
        case inProgress = "in_progress"
        case queued = "queued"
        case requested = "requested"
        case waiting = "waiting"
        case pending = "pending"
    }

    open internal(set) var id: Int = -1
    open var name: String
    open var status: Status?
    open var pullRequests: [PullRequestMinimal]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case pullRequests = "pull_requests"
    }
}

public struct PullRequestMinimal: Codable {
    public let id: Int
    public let number: Int
    public let url: String
}

private struct ListRunsResponse: Codable {
    let workflow_runs: [Run]
}

// MARK: Request

public extension Octokit {
    func listRuns(
        _ session: RequestKitURLSession = URLSession.shared,
        owner: String,
        repository: String,
        workflow: String
    ) async throws -> [Run] {
        let router = RunsRouter.listRunsForWorkflow(configuration, owner: owner, repository: repository, workflow: workflow)
        return try await router.load(session, dateDecodingStrategy: .formatted(Time.rfc3339DateFormatter), expectedResultType: ListRunsResponse.self).workflow_runs
    }

    func cancelRun(
        _ session: RequestKitURLSession = URLSession.shared,
        owner: String,
        repository: String,
        runID: Int
    ) async throws {
        let router = RunsRouter.cancelWorkflowRun(configuration, owner: owner, repository: repository, runID: runID)
        try await router.load(session)
    }
}

// MARK: Router

enum RunsRouter: Router {
    case listRunsForWorkflow(Configuration, owner: String, repository: String, workflow: String)
    case cancelWorkflowRun(Configuration, owner: String, repository: String, runID: Int)

    var configuration: Configuration {
        switch self {
        case let .listRunsForWorkflow(config, _, _, _): return config
        case let .cancelWorkflowRun(config, _, _, _): return config
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listRunsForWorkflow: return .GET
        case .cancelWorkflowRun: return .POST
        }
    }

    var encoding: HTTPEncoding {
        return .url
    }

    var path: String {
        switch self {
        case let .listRunsForWorkflow(_, owner, repository, workflow):
            return "repos/\(owner)/\(repository)/actions/workflows/\(workflow)/runs"
        case let .cancelWorkflowRun(_, owner, repository, runID):
            return "repos/\(owner)/\(repository)/actions/runs/\(runID)/cancel"
        }
    }

    var params: [String: Any] {
        return [:]
    }
}

public extension Action {
    func getCurrentWorkflowRuns(where predicate: (Run) -> Bool = { _ in true }) async throws -> [Run] {
        let (owner, repository) = try context.environment.github.requireOwnerRepository()
        let workflow = try context.environment.github.workflowFilename
        let runs = try await context.githubAPI.listRuns(owner: owner, repository: repository, workflow: workflow)
        return runs.filter(predicate)
    }

    func cancelWorkflowRun(id runID: Int) async throws {
        let (owner, repository) = try context.environment.github.requireOwnerRepository()
        try await context.githubAPI.cancelRun(owner: owner, repository: repository, runID: runID)
    }
}
