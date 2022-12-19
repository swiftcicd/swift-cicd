import OctoKit
import SwiftEnvironment

public struct SetCommitStatus: Step {
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
            throw StepError("Missing repository owner")
        }

        guard let repository else {
            throw StepError("Missing repository")
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

public extension StepRunner {
    func setCommit(
        sha: String,
        status: Status.State,
        context: String? = nil,
        description: String? = nil,
        detailsURL: String? = nil,
        owner: String? = nil,
        repository: String? = nil
    ) async throws {
        try await step(SetCommitStatus(
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
