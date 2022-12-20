import OctoKit
import SwiftEnvironment
import SwiftCICore
import SwiftCIPlatforms

// TODO: Should this be moved into a GitHub-specific actions directory? Maybe under SwiftCIPlatforms?

public struct SetGitHubCommitStatus: Action {
    let commitSHA: String
    let statusState: Status.State
    var context: String?
    var description: String?
    var detailsURL: String?
    var owner: String?
    var repository: String?

    public init(
        commitSHA: String,
        statusState: Status.State,
        context: String? = nil,
        description: String? = nil,
        detailsURL: String? = nil,
        owner: String? = nil,
        repository: String? = nil
    ) {
        self.commitSHA = commitSHA
        self.statusState = statusState
        self.context = context
        self.description = description
        self.detailsURL = detailsURL
        self.owner = owner
        self.repository = repository
    }

    public func run() async throws {
        let environmentOwnerRepository = Self.context.environment.github.ownerRepository
        let owner = owner ?? environmentOwnerRepository?.owner
        let repository = repository ?? environmentOwnerRepository?.repository

        guard let owner else {
            throw ActionError("Missing repository owner")
        }

        guard let repository else {
            throw ActionError("Missing repository")
        }

        logger.info("Setting commit \(commitSHA.prefix(5)) status to \(statusState) for context: \(context ?? "nil")")

        let response = try await Self.context.githubAPI.createCommitStatus(
            owner: owner,
            repository: repository,
            sha: commitSHA,
            state: statusState,
            targetURL: detailsURL,
            description: description,
            context: context
        )

        logger.debug("""
            Response:
            \("\(response)".indented())
            """
        )
    }
}

public extension Action {
    func setGitHubCommit(
        sha: String,
        status: Status.State,
        context: String? = nil,
        description: String? = nil,
        detailsURL: String? = nil,
        owner: String? = nil,
        repository: String? = nil
    ) async throws {
        try await action(SetGitHubCommitStatus(
            commitSHA: sha,
            statusState: status,
            context: context,
            description: description,
            detailsURL: detailsURL,
            owner: owner,
            repository: repository
        ))
    }
}
