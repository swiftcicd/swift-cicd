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

//public extension ContextValues {
//    var isPullRequestIntoMain: Bool {
//        isPullRequest(into: "main")
//    }
//
//    func isPullRequest(into branch: String) -> Bool {
//        switch environment.github.event {
//        case .pullRequest(let pullRequest):
//            return pullRequest.base.ref == branch
//        default:
//            return false
//        }
//    }
//}

public extension ProcessEnvironment.GitHub {
    enum Event {
        case pullRequest(PullRequestEvent)
        case other(name: String, contents: Data)
    }

    static var event: Event? {
        let context = ContextValues.shared

        do {
            let name = try context.environment.github.$eventName.require()
            let contents: Data

            if context.environment.github.isCI {
                let eventPath = try context.environment.github.$eventPath.require()
                guard let eventContents = context.fileManager.contents(atPath: eventPath) else {
                    return nil
                }
                contents = eventContents
            } else {
                let stringContents = try context.environment.require("GITHUB_EVENT_CONTENTS")
                contents = stringContents.data
            }
            
            func decodeEvent<E: Decodable>(_ event: (E) -> Event) -> Event? {
                do {
                    context.logger.debug("""
                        Decoding GitHub event payload \(E.self):
                        \(contents.string)

                        """
                    )
                    let payload = try JSONDecoder().decode(E.self, from: contents)
                    return event(payload)
                } catch {
                    if context.environment.github.isCI {
                        context.logger.error("""
                            Failed to decode GitHub event \(Event.self). Please submit an issue to swift-ci and attach the error body that follows. \
                            In the meantime, you can manually inspect the event by using the eventName and eventPath properties. \
                            Error:
                            \(error)
                            Contents:
                            \(contents.string)
                            (End of error)


                            """
                        )
                    } else {
                        context.logger.error("""
                            Failed to decode simulated GitHub event \(Event.self). Error:
                            \(error)


                            """
                        )
                    }
                    return nil
                }
            }
            
            switch eventName {
            case "pull_request":
                return decodeEvent(Event.pullRequest)
            default:
                return .other(name: name, contents: contents)
            }
        } catch {
            context.logger.error("Error while getting GitHub event details: \(error)")
            return nil
        }
    }
}

@dynamicMemberLookup
public struct PullRequestEvent: Decodable {
    public let action: Action
    private let pullRequest: PullRequest

    public subscript<T>(dynamicMember keyPath: KeyPath<PullRequest, T>) -> T {
        pullRequest[keyPath: keyPath]
    }

    enum CodingKeys: String, CodingKey {
        case action
        case pullRequest = "pull_request"
    }

    public struct PullRequest: Decodable {
        public let id: Int
        public let number: Int
        public let title: String
        public let body: String?
        public let isDraft: Bool
        public let isMerged: Bool
        public let base: Ref
        public let head: Ref

        enum CodingKeys: String, CodingKey {
            case id
            case number
            case title
            case body
            case isDraft = "draft"
            case isMerged = "merged"
            case base
            case head
        }
    }

    public struct Ref: Decodable {
        public let ref: String
        public let sha: String
    }

    // https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request
    public enum Action: String, Decodable {
        case assigned
        case unassigned
        case labeled
        case unlabeled
        case opened
        case edited
        case closed
        case reopened
        case synchronize
        case converted_to_draft = "converted_to_draft"
        case readyForReview = "ready_for_review"
        case locked
        case unlocked
        case reviewRequested = "review_requested"
        case reviewRequestRemoved = "review_request_removed"
        case autoMergeEnabled = "auto_merge_enabled"
        case autoMergeDisabled = "auto_merge_disabled"
    }
}
