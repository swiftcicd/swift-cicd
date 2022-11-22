import Logging
import SwiftCI

@main
struct Demo: Workflow {
    static let logLevel: Logger.Level = .debug

    func run() async throws {
        let fileSecret: String = try loadSecret(.base64EncodedEnvironmentValue("FILE"))
        let file = try await saveFile(name: "file.txt", contents: fileSecret)
        print(fileSecret)
        print(file.filePath)
    }
}

// Root workflow
//  starts workflow A       <-- xcode project workflow
//      starts workflow B
//  starts workflow C

// root.xcodeProject: nil
// a.xcodeProject: some
// b.xcodeProject: some (via a)
// c.xcodeProject: nil

//        root
//        /  \
//       A*   C
//      /
//     B*

//@main
//struct Root: Workflow {
//    func run() async throws {
//        print("Root: \(context.xcodeProject)")
//        try await workflow(A())
//        try await workflow(C())
//    }
//}
//
//struct A: XcodeProjectWorkflow {
//    var xcodeProject: String { "some.xcodeproj" }
//
//    func run() async throws {
//        print("A: \(context.xcodeProject)")
//        try await workflow(B())
//    }
//}
//
//struct B: Workflow {
//    func run() async throws {
//        print("B: \(context.xcodeProject)")
//    }
//}
//
//struct C: Workflow {
//    func run() async throws {
//        print("C: \(context.xcodeProject)")
//    }
//}
