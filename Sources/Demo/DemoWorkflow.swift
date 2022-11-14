import Logging
import SwiftCI

@main
struct Demo: Workflow {
    static let logLevel: Logger.Level = .debug

    func run() async throws {
        try await step(.swiftBuild)
        try await step(.swiftTest)
    }
}
