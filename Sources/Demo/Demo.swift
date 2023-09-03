import Foundation
import SwiftCICD
import SlackActions

@main
struct Demo: MainAction {
    var body: some Action {
        Run {
            _ = try await context.tools.xcbeautify
        }
    }
}
