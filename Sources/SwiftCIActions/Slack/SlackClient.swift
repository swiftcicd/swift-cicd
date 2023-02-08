import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol SlackClient {
    func send(_ message: SlackMessage, to webhookURL: URL) async throws
}

public enum SlackClientError: Error {
    case invalidResponseType
    case invalidStatusCode(Int, response: Data)
}

extension URLSession: SlackClient {
    public func send(_ message: SlackMessage, to webhookURL: URL) async throws {
        let encodedMessage = try JSONEncoder().encode(message)
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.httpBody = encodedMessage
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await self.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SlackClientError.invalidStatusCode(httpResponse.statusCode, response: data)
        }
    }
}
