public struct Environment {
    var environment: [String: String] = [:]

    var dump: String {
        environment.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    public subscript(key: String) -> String? {
        environment[key]
    }

    public subscript(variable: Variable) -> String? {
        self[variable.rawValue]
    }

    public func require(_ variable: Variable) throws -> String {
        guard let value = self[variable] else {
            throw RequiredVariableError(variable: variable)
        }

        return value
    }
}

extension Environment {
    public struct RequiredVariableError: Error {
        let variable: Variable
    }

    public enum Variable: String {
        case repository = "GITHUB_REPOSITORY"
        case repositoryOwner = "GITHUB_REPOSITORY_OWNER"
        case refName = "GITHUB_REF_NAME"
        case workspace = "GITHUB_WORKSPACE"
        case ci = "CI"
        case eventName = "GITHUB_EVENT_NAME"
        case token = "GITHUB_TOKEN"
        case runID = "GITHUB_RUN_ID"
    }
}

public extension Environment {
    /// Example: `"LumioHX/hx-ios"`
    var repository: String? {
        self[.repository]
    }

    /// Example: `"LumioHX"`
    var repositoryOwner: String? {
        self[.repositoryOwner]
    }

    /// Example: `"59/merge"`
    var refName: String? {
        self[.refName]
    }

    /// The root of the cloned repository.
    /// Example: `"/Users/clay/actions-runner/_work/hx-ios/hx-ios"`
    var workspace: String? {
        self[.workspace]
    }

    /// Example: `"true"`
    var ci: String? {
        self[.ci]
    }

    /// Example: `"pull_request"`
    var eventName: String? {
        self[.eventName]
    }

    /// Example: `"abc123"`
    var token: String? {
        self[.token]
    }

    var runID: String? {
        self[.runID]
    }
}

public extension Environment {
    var isCI: Bool {
        ci == "true"
    }

    var isPullRequest: Bool {
        eventName == "pull_request"
    }
}

extension Environment: ContextKey {
    public static let defaultValue = Environment()
}

public extension ContextValues {
    var environment: Environment {
        get { self[Environment.self] }
        set { self[Environment.self] = newValue }
    }
}
