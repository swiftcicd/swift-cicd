import Foundation
import SwiftCICD
import SlackActions

@main
struct Demo: MainAction {
    var body: some Action {
        Run {
            let s: Secret = .environmentValue("VALUE")
        }
    }
}
