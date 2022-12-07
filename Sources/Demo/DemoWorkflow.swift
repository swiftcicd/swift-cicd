import Logging
import SwiftCI

@main
struct Demo: Workflow {
    static let logLevel: Logger.Level = .debug

    func run() async throws {
//        let fileSecret: String = try loadSecret(.base64EncodedEnvironmentValue("FILE"))
//        let file = try await saveFile(name: "file.txt", contents: fileSecret)
//        print(fileSecret)
//        print(file.filePath)

        try await build(project: "Demo/Demo.xcodeproj", cleanBuild: true, xcbeautify: true)
    }
}
