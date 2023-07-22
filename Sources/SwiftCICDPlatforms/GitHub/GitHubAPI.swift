import OctoKit
import SwiftCICDCore
import SwiftEnvironment

public typealias GitHubAPI = Octokit

public extension ProcessEnvironment.GitHub {
    @EnvironmentVariable("GITHUB_TOKEN")
    static var token
}

public extension ContextValues {
    enum GitHubAPIKey: ContextKey {
        public static let defaultValue: GitHubAPI = {
            if let token = ContextValues.current.environment.github.token {
                return GitHubAPI(TokenConfiguration(bearerToken: token))
            } else {
                return GitHubAPI()
            }
        }()
    }

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
