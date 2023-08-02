import OctoKit
import SwiftCICDCore
import SwiftPR

public protocol GitHubStatusContext {
    var context: String { get }
}

public struct NamedContext: GitHubStatusContext, ExpressibleByStringLiteral {
    public let context: String

    public init(_ context: String) {
        self.context = context
    }

    public init(stringLiteral value: StaticString) {
        self.init("\(value)")
    }
}

public struct PRCheckContext: GitHubStatusContext {
    let prCheck: PRCheck.Type
    public let context: String

    public init(_ prCheck: PRCheck.Type) {
        self.prCheck = prCheck
        self.context = prCheck.statusContext
    }
}

public extension GitHubStatusContext where Self == NamedContext {
    static func context(_ name: String) -> NamedContext {
        NamedContext(name)
    }
}

public extension GitHubStatusContext where Self == PRCheckContext {
    static func prCheck(_ prCheck: PRCheck.Type) -> PRCheckContext {
        PRCheckContext(prCheck)
    }
}

struct ForwardCommitStatus: Action {
    let status: OctoKit.Status.State
    let contexts: [GitHubStatusContext]

    func run() async throws {
        guard let latestCommitSHA = try await git.latestCommitSHA else {
            throw ActionError("Couldn't get latest commit sha")
        }

        guard try latestCommitSHA != context.environment.github.$sha.require() else {
            logger.info("No later commits found than the one that triggered this action")
            return
        }

        for statusContext in contexts {
            let status: OctoKit.Status.State
            let contextName: String
            let detailsURL: String

            if let prCheckContext = type(of: statusContext) as? PRCheck.Type {
                status = prCheckContext.statusState
                contextName = prCheckContext.statusContext
                guard let prCheckComment = try await prCheckContext.getSwiftPRComment() else {
                    throw ActionError("Couldn't get SwiftPR comment for check: \(prCheckContext.name)")
                }
                detailsURL = prCheckComment.htmlURL.absoluteString
            } else {
                status = self.status
                contextName = statusContext.context
                let currentJobURL = try await github.getCurrentWorkflowRunJob()
                detailsURL = currentJobURL.htmlURL
            }

            try await github.setCommit(
                sha: latestCommitSHA,
                status: status,
                context: contextName,
                description: "Status forwarded from previous check",
                detailsURL: detailsURL
            )
        }
    }
}

public extension GitHub {
    func forwardCommitStatus(
        _ status: OctoKit.Status.State,
        to contexts: [any GitHubStatusContext]
    ) async throws {
        try await run(
            ForwardCommitStatus(
                status: status,
                contexts: contexts
            )
        )
    }

    func forwardCommitStatus(
        _ status: OctoKit.Status.State,
        to contexts: [String]
    ) async throws {
        try await forwardCommitStatus(status, to: contexts.map { .context($0) })
    }
}
