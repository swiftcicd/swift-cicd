import Logging
import SwiftCI

@main
struct Demo: Workflow {
    static let logLevel: Logger.Level = .debug

    func run() async throws {
        let fileSecret: String = try loadSecret(.init(source: .environment("FILE"), encoding: .base64))
        let file = try await saveFile(name: "file.txt", contents: fileSecret)
        print(fileSecret)
        print(file.filePath)
    }
}
