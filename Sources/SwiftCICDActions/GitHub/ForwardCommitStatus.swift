import OctoKit
import SwiftCICDCore
import SwiftPR

public enum GitHubStatusContext {
    case statusCheck(String)
    case swiftPRCheck(PRCheck.Type)
}

extension GitHubStatusContext: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .statusCheck(value)
    }
}

extension GitHub {
    public struct ForwardCommitStatus: Action {
        let status: OctoKit.Status.State
        let contexts: [GitHubStatusContext]

        public init(
            _ status: OctoKit.Status.State = .success,
            to contexts: [GitHubStatusContext]
        ) {
            self.status = status
            self.contexts = contexts
        }

        public func run() async throws {
            guard let latestCommitSHA = try await context.git.latestCommitSHA else {
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

                switch statusContext {
                case .statusCheck(let name):
                    status = self.status
                    contextName = name
                    let currentJobURL = try await github.getCurrentWorkflowRunJob(named: contextName)
                    detailsURL = currentJobURL.htmlURL

                case .swiftPRCheck(let prCheck):
                    status = prCheck.statusState
                    contextName = prCheck.statusContext
                    guard let prCheckComment = try await prCheck.getSwiftPRComment() else {
                        throw ActionError("Couldn't get SwiftPR comment for check: \(prCheck.name)")
                    }
                    detailsURL = prCheckComment.htmlURL.absoluteString
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
}

public extension GitHub {
    func forwardCommitStatus(
        _ status: OctoKit.Status.State = .success,
        to contexts: [GitHubStatusContext]
    ) async throws {
        try await run(ForwardCommitStatus(status, to: contexts))
    }
}
