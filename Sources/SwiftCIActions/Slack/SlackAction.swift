import Foundation
import SwiftCICore

public struct SlackAction: Action {
    let message: LegacySlackMessage
    let webhook: URL
    let client: SlackClient

    public func run() async throws {
        try await client.send(message, to: webhook)
    }
}

public extension Action {
    func sendSlackMessage(_ message: LegacySlackMessage, to webhook: URL, using client: SlackClient = URLSession.shared) async throws {
        try await action(SlackAction(message: message, webhook: webhook, client: client))
    }
}
