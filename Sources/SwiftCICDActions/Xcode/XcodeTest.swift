import SwiftCICDCore

extension Xcode {
    public struct Test: Action {
        var container: Xcode.Container?
        var scheme: String?
        var destination: XcodeBuild.Destination?
        var withoutBuilding: Bool
        let xcbeautify: Bool

        internal init(
            container: Xcode.Container? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            withoutBuilding: Bool = false,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = container
            self.scheme = scheme
            self.destination = destination
            self.withoutBuilding = withoutBuilding
            self.xcbeautify = xcbeautify
        }

        public init(
            project: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            withoutBuilding: Bool = false,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = project.map { .project($0) }
            self.scheme = scheme
            self.destination = destination
            self.withoutBuilding = withoutBuilding
            self.xcbeautify = xcbeautify
        }

        public init(
            workspace: String? = nil,
            scheme: String? = nil,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            withoutBuilding: Bool = false,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = workspace.map { .workspace($0) }
            self.scheme = scheme
            self.destination = destination
            self.withoutBuilding = withoutBuilding
            self.xcbeautify = xcbeautify
        }

        public func run() async throws {
            let container = try self.container ?? context.xcodeContainer
            let scheme = self.scheme ?? context.defaultXcodeProjectScheme
            var test = ShellCommand("xcodebuild \(withoutBuilding ? "test-without-building" : "test")")
            test.append(container?.flag)
            test.append("-scheme", ifLet: scheme)
            test.append("-destination", ifLet: destination?.value)
//            test.append("-derivedDataPath \(XcodeBuild.derivedData.filePath)")
            try await xcbeautify(test, if: xcbeautify)
        }
    }
}

public extension Xcode {
    internal func test(
        container: Xcode.Container? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        withoutBuilding: Bool = false,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            Test(
                container: container,
                scheme: scheme,
                destination: destination,
                withoutBuilding: withoutBuilding,
                xcbeautify: xcbeautify
            )
        )
    }

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

    func test(
        workspace: String? = nil,
        scheme: String? = nil,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        withoutBuilding: Bool = false,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws {
        try await run(
            Test(
                workspace: workspace,
                scheme: scheme,
                destination: destination,
                withoutBuilding: withoutBuilding,
                xcbeautify: xcbeautify
            )
        )
    }
}
