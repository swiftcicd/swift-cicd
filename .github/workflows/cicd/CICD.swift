import SwiftCI

@main
struct CICD: Workflow {
    func run() async throws {
        print("HELLO...")
        try await step(.swiftBuild)
        print("...WORLD!")
    }
}
