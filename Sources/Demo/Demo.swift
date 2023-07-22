import Foundation
import Logging
import SwiftCI

@main
struct Demo: MainAction {
    static let logLevel = Logger.Level.debug

    func run() async throws {
        let project = "/Users/clayellis/Documents/Projects/hx-ios/HX.xcodeproj"
        let simulator = XcodeBuild.Destination.platform(.iOSSimulator, name: "iPhone 14")

        let who = try await shell("pwd")
        logger.info("whoami: \(who)")

        let output = try await action("Build HX App") {
            BuildXcodeProject(
                project: project,
                scheme: "HX App",
                configuration: .debug,
                destination: simulator,
                xcbeautify: true
            )
        }

        if let product = output.product {
            try await uploadGitHubActionArtifact(product.url, named: "Simulator Build")
        }
    }
}
