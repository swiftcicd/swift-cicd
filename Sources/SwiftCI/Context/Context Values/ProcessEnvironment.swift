import Foundation
import SwiftEnvironment

extension ProcessEnvironment: ContextKey {
    public static let defaultValue = ProcessEnvironment.self
}

public extension ContextValues {
    var environment: ProcessEnvironment.Type {
        get { self[ProcessEnvironment.self] }
        set { self[ProcessEnvironment.self] = newValue }
    }
}

public extension ContextValues {
    var isPullRequestIntoMain: Bool {
        isPullRequest(into: "main")
    }

    func isPullRequest(into branch: String) -> Bool {
        environment.github.pullRequestEvent?.pullRequest.base.ref == branch
    }
}

public extension ProcessEnvironment.GitHub {
    static var pullRequestEvent: PullRequestEvent? {
        guard eventName == "pull_request", let eventPath else {
            return nil
        }

        guard let eventPathContents = FileManager.default.contents(atPath: eventPath) else {
            return nil
        }

        do {
            let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventPathContents)
            return pullRequestEvent
        } catch {
            print(error)
            return nil
        }
    }
}

public struct PullRequestEvent: Decodable {
    public let action: String
    public let number: Int
    public let pullRequest: PullRequest

    enum CodingKeys: String, CodingKey {
        case action
        case number
        case pullRequest = "pull_request"
    }

    public struct PullRequest: Decodable {
        public let id: Int
        public let number: Int
        public let title: String
        public let body: String?
        public let draft: Bool
        public let merged: Bool
        public let base: Ref
        public let head: Ref
    }

    public struct Ref: Decodable {
        public let ref: String
        public let sha: String
    }
}
