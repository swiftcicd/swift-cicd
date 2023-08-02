import SwiftCICDCore

/// Namespace for Xcode actions.
public struct Xcode {
    public let caller: any Action
}

public extension Action {
    var xcode: Xcode { Xcode(caller: self) }
}

public extension Xcode {
    @discardableResult
    func buildProject(
        _ project: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = .debug,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        sdk: XcodeBuild.SDK? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> BuildXcodeProject.Output {
        try await caller.run(
            BuildXcodeProject(
                project: project,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }
}
