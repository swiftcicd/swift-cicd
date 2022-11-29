import OctoKit
import SwiftEnvironment

public struct SetCommitStatus: Step {
    var owner: String?
    var repository: String?
    let commitSHA: String
    let statusState: Status.State
    var targetURL: String?
    var description: String?
    var context: String?

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

        logger.info("Setting commit \(commitSHA.prefix(5)) status to \(statusState)")

        let response = try await Self.context.githubAPI.createCommitStatus(
            owner: owner,
            repository: repository,
            sha: commitSHA,
            state: statusState,
            targetURL: targetURL,
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

extension ProcessEnvironment.GitHub {
    static var ownerRepository: (owner: String, repository: String)? {
        try? requireOwnerRepository()
    }

    static func requireOwnerRepository() throws -> (owner: String, repository: String) {
        let owner = try $repositoryOwner.require()
        let ownerRespository = try $repository.require()
        let repository = String(ownerRespository.dropFirst((owner + "/").count))
        return (owner: owner, repository: repository)
    }
}
