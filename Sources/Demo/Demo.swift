import SwiftCICD

@main
struct Demo: MainAction {
    func run() async throws {
        try await xcode.buildProject()
    }
}
