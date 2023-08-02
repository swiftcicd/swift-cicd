import Foundation
import SwiftCICDCore

struct SlackAction: Action {
    enum Message {
        case legacy(Slack.LegacyMessage)
        case blocks(Slack.Message)
    }

    let message: Message
    let webhook: URL

    func run() async throws {
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

public extension Slack {
    func legacyMessage(to webhook: URL, message: LegacyMessage) async throws {
        try await run(SlackAction(message: .legacy(message), webhook: webhook))
    }

    func message(to webhook: URL, message: Message) async throws {
        try await run(SlackAction(message: .blocks(message), webhook: webhook))
    }
}
