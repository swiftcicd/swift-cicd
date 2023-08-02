import SwiftCICDCore

struct TestXcodeProject: Action {
    var xcodeProject: String?
    var scheme: String?
    var destination: XcodeBuild.Destination?
    var withoutBuilding: Bool
    let xcbeautify: Bool

    init(
        xcodeProject: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        withoutBuilding: Bool = false,
        xcbeautify: Bool = Xcbeautify.default
    ) {
        self.xcodeProject = xcodeProject
        self.scheme = scheme
        self.destination = destination
        self.withoutBuilding = withoutBuilding
        self.xcbeautify = xcbeautify
    }

    func run() async throws {
        var test = ShellCommand("xcodebuild \(withoutBuilding ? "test-without-building" : "test")")
        test.append("-project", ifLet: xcodeProject)
        test.append("-scheme", ifLet: scheme)
        test.append("-destination", ifLet: destination?.value)
        try await xcbeautify(test, if: xcbeautify)
    }
}

public extension Xcode {
    func test(
        project: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        withoutBuilding: Bool = false,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            TestXcodeProject(
                xcodeProject: project ?? self.project,
                scheme: scheme,
                destination: destination,
                withoutBuilding: withoutBuilding,
                xcbeautify: xcbeautify
            )
        )
    }
}
