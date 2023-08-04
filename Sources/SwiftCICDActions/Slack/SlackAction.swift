import Foundation
import SwiftCICDCore

extension Slack {
    public struct SendMessage: Action {
        enum _Message {
            case legacy(LegacyMessage)
            case blocks(Message)
        }

        let message: _Message
        let webhook: String

        init(message: _Message, webhook: String) {
            self.message = message
            self.webhook = webhook
        }

        public init(to webhook: String, message: Message) {
            self.init(message: .blocks(message), webhook: webhook)
        }

        public init(to webhook: String, message: LegacyMessage) {
            self.init(message: .legacy(message), webhook: webhook)
        }

        public func run() async throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let encodedMessage: Data
            switch message {
            case .blocks(let message): encodedMessage = try encoder.encode(message)
            case .legacy(let message): encodedMessage = try encoder.encode(message)
            }
            logger.info("Sending Slack message:\n\(encodedMessage.string)")
            guard let webhookURL = URL(string: webhook) else {
                throw ActionError("Slack webhook was not a valid url: \(webhook)")
            }
            var request = URLRequest(url: webhookURL)
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
}

public extension Slack {
    func legacyMessage(to webhook: String, message: LegacyMessage) async throws {
        try await run(SendMessage(to: webhook, message: message))
    }

    func message(to webhook: String, message: Message) async throws {
        try await run(SendMessage(to: webhook, message: message))
    }
}
