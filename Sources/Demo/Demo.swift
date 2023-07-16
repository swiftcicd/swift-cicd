import Logging
import SwiftCI

@main
struct Demo: MainAction {
    static let logLevel = Logger.Level.debug

    func run() async throws {
        let secret = try await getSecret(.onePassword(
            reference: "op://thdjmad6w45caxqbkdzxwayzdu/Certificate.p12/Certificates.p12",
            serviceAccountToken: .environmentValue("op_token")
        ))

        print("SECRET:\n\(secret)")
    }
}
