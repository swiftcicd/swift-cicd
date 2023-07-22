import Foundation
import SwiftCICDCore

public struct SlackAction: Action {
    enum Message {
        case legacy(LegacySlackMessage)
        case blocks(SlackMessage)
    }

    let message: Message
    let webhook: URL

    public func run() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let encodedMessage: Data
        switch message {
        case .blocks(let message): encodedMessage = try encoder.encode(message)
        case .legacy(let message): encodedMessage = try encoder.encode(message)
        }
        logger.info("Sending Slack message:\n\(encodedMessage.string)")
        var request = URLRequest(url: webhook)
        request.httpMethod = "POST"
        request.httpBody = encodedMessage
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ActionError("Invalid status code \(httpResponse.statusCode) — Response: \(String(decoding: data, as: UTF8.self))")
        }
    }
}

public extension Action {
    func slack(to webhook: URL, message: LegacySlackMessage) async throws {
        try await action(SlackAction(message: .legacy(message), webhook: webhook))
    }

    func slack(to webhook: URL, message: SlackMessage) async throws {
        try await action(SlackAction(message: .blocks(message), webhook: webhook))
    }
}
