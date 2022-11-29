import OctoKit
import SwiftEnvironment

public typealias GitHubAPI = Octokit

public extension ProcessEnvironment.GitHub {
    @EnvironmentVariable("GITHUB_TOKEN")
    static var token
}

enum GitHubAPIKey: ContextKey {
    static let defaultValue: GitHubAPI = {
        if let token = ContextValues.shared.environment.github.token {
            return GitHubAPI(TokenConfiguration(bearerToken: token))
        } else {
            return GitHubAPI()
        }
    }()
}

public extension ContextValues {
    var githubAPI: GitHubAPI {
        get { self[GitHubAPIKey.self] }
        set { self[GitHubAPIKey.self] = newValue }
    }
}

public extension ProcessEnvironment.GitHub {
    static var api: GitHubAPI {
        @Context(\.githubAPI) var api
        return api
    }
}
