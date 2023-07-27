import Foundation
import Logging
import SwiftCICD

@main
struct Demo: MainAction {
    static let logLevel = Logger.Level.debug

    func run() async throws {
        let project = "/Users/clayellis/Documents/Projects/hx-ios/HX.xcodeproj"
        try await buildXcodeProject(project)
        try await testXcodeProject(project, withoutBuilding: true)
    }
}
