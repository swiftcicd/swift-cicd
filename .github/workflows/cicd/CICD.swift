import SwiftCI

@main
struct CICD: Workflow {
    func run() async throws {
        try await step(.swiftBuild)
        try await step(.swiftTest)
    }
}
