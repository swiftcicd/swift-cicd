extension ProcessEnvironment {
    public static let github = GitHub.self
    public enum GitHub {}

    // TODO: Is it possible to retrieve secrets without them being passed into the environment in the action yml?
}

extension ProcessEnvironment.GitHub {
    static func stringBool(_ value: String) -> Bool? {
        value == "true"
    }

    static func intBool(_ value: String) -> Bool? {
        value == "1"
    }

    static func int(_ value: String) -> Int? {
        Int(value)
    }
}

public extension ProcessEnvironment.GitHub {
    @EnvironmentVariable("CI", transform: stringBool)
    static var ci

    @EnvironmentVariable("GITHUB_ACTION")
    static var action

    @EnvironmentVariable("GITHUB_ACTION_PATH")
    static var actionPath

    @EnvironmentVariable("GITHUB_ACTION_REPOISTORY")
    static var actionRepository

    @EnvironmentVariable("GITHUB_ACTIONS", transform: stringBool)
    static var actions

    @EnvironmentVariable("GITHUB_ACTOR")
    static var actor

    @EnvironmentVariable("GITHUB_API_URL")
    static var apiURL

    @EnvironmentVariable("GITHUB_BASE_REF")
    static var baseRef

    @EnvironmentVariable("GITHUB_ENV")
    static var env

    @EnvironmentVariable("GITHUB_EVENT_NAME")
    static var eventName

    @EnvironmentVariable("GITHUB_EVENT_PATH")
    static var eventPath

    @EnvironmentVariable("GITHUB_GRAPHQL_URL")
    static var graphQLURL

    @EnvironmentVariable("GITHUB_HEAD_REF")
    static var headRef

    @EnvironmentVariable("GITHUB_JOB")
    static var job

    @EnvironmentVariable("GITHUB_PATH")
    static var path

    @EnvironmentVariable("GITHUB_REF")
    static var ref

    @EnvironmentVariable("GITHUB_REF_NAME")
    static var refName

    @EnvironmentVariable("GITHUB_REF_PROTECTED", transform: stringBool)
    static var refProtected

    @EnvironmentVariable("GITHUB_REF_TYPE")
    static var refType

    @EnvironmentVariable("GITHUB_REPOSITORY")
    static var repository

    @EnvironmentVariable("GITHUB_REPOSITORY_OWNER")
    static var repositoryOwner

    @EnvironmentVariable("GITHUB_RETENTION_DAYS", transform: int)
    static var retentionDays

    @EnvironmentVariable("GITHUB_RUN_ATTEMPT", transform: int)
    static var runAttempt

    @EnvironmentVariable("GITHUB_RUN_ID")
    static var runID

    @EnvironmentVariable("GITHUB_RUN_NUMBER", transform: int)
    static var runNumber

    @EnvironmentVariable("GITHUB_SERVER_URL")
    static var serverURL

    @EnvironmentVariable("GITHUB_SHA")
    static var sha

    @EnvironmentVariable("GITHUB_STEP_SUMMARY")
    static var stepSummary

    @EnvironmentVariable("GITHUB_WORKFLOW")
    static var workflow

    @EnvironmentVariable("GITHUB_WORKSPACE")
    static var workspace

    @EnvironmentVariable("RUNNER_ARCH")
    static var runnerArch

    @EnvironmentVariable("RUNNER_DEBUG", transform: intBool)
    static var runnerDebug

    @EnvironmentVariable("RUNNER_NAME")
    static var runnerName

    @EnvironmentVariable("RUNNER_OS")
    static var runnerOS

    @EnvironmentVariable("RUNNER_TEMP")
    static var runnerTemp

    @EnvironmentVariable("RUNNER_TOOL_CACHE")
    static var runnerToolCache
}

public extension ProcessEnvironment.GitHub {
    static var isCI: Bool { ci ?? false }

    static var isPullRequest: Bool {
        eventName == "pull_request"
    }
}
