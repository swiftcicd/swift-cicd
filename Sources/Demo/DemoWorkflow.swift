import Logging
import SwiftCI

@main
struct Demo: Workflow {
    static let logLevel: Logger.Level = .debug

    func run() async throws {
        let file = try await step(.loadFile(fromEnvironmentKey: "FILE", as: "file.txt")).filePath
        print(file)
    }
}
