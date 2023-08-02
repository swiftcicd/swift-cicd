import SwiftCICD

@main
struct CICD: MainAction {
    func run() async throws {
        try await shell("swift build")
        try await shell("swift test")
    }
}
