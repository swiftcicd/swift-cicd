import SwiftCICDCore

extension Xcode {
    public struct Test: Action {
        var project: String?
        var scheme: String?
        var destination: XcodeBuild.Destination?
        var withoutBuilding: Bool
        let xcbeautify: Bool

        public init(
            project: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            withoutBuilding: Bool = false,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.project = project
            self.scheme = scheme
            self.destination = destination
            self.withoutBuilding = withoutBuilding
            self.xcbeautify = xcbeautify
        }

        public func run() async throws {
            let project = try self.project ?? context.xcodeProject
            let scheme = self.scheme ?? context.defaultXcodeProjectScheme
            var test = ShellCommand("xcodebuild \(withoutBuilding ? "test-without-building" : "test")")
            test.append("-project", ifLet: project)
            test.append("-scheme", ifLet: scheme)
            test.append("-destination", ifLet: destination?.value)
//            test.append("-derivedDataPath \(XcodeBuild.derivedData.filePath)")
            try await xcbeautify(test, if: xcbeautify)
        }
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
            Test(
                project: project,
                scheme: scheme,
                destination: destination,
                withoutBuilding: withoutBuilding,
                xcbeautify: xcbeautify
            )
        )
    }
}
