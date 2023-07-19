import Foundation
import Logging
import SwiftCI

@main
struct Demo: MainAction {
    static let logLevel = Logger.Level.debug

    func run() async throws {
        let project = "/Users/clayellis/Documents/Projects/hx-ios/HX.xcodeproj"
        let simulator = XcodeBuild.Destination.platform(.iOSSimulator, name: "iPhone 14")

        try await buildXcodeProject(
            project,
            scheme: "HX App",
            configuration: .debug,
            destination: simulator,
            xcbeautify: true
        )

        let settings = try getXcodeProjectBuildSettings(
            xcodeProject: project,
            configuration: .debug,
            destination: simulator,
            sdk: .iPhoneSimulator
        )

        let buildDirectory = try settings.require(.configurationBuildDirectory)
        let fullProductName = try settings.require(.fullProductName)
        let artifactURL = URL(string: "\(buildDirectory)/\(fullProductName)")!
        try await uploadGitHubActionArtifact(artifactURL, named: "Simulator Build")
    }
}
