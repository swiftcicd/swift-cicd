import Logging
import SwiftCI

@main
struct Demo: MainAction {
    static let logLevel = Logger.Level.debug

    func run() async throws {
        let secret = try await getSecret(.onePassword(
            reference: "op://thdjmad6w45caxqbkdzxwayzdu/nvv6zhv4y24dlfudmi24x5nzue/text",
            serviceAccountToken: .environmentValue("op_token")
        ))

        logger.info("Got 1Password secret:\n\(secret.string)")
    }
}
