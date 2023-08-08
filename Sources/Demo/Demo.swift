import Foundation
import SwiftCICD
import SlackActions

@main
struct Demo: MainAction {
    func run() async throws {
        let uploadedBuildVersion = "1.0.0"
        let uploadedBuildNumber = "42"
        let pr: String? = "pr value"

        let message = SlackMessage(color: "#FFF") {
            MarkdownBlock {
                """
                *New TestFlight Build Available*
                HX \(uploadedBuildVersion) (\(uploadedBuildNumber))
                """

                if let pr {
                    "pr: \(pr)"
                }
            }

            if let pr {
                MarkdownBlock {
                    "PR: \(pr)"
                }
            }

            ContextBlock {
                MarkdownBlock {
                    "Markdown"
                }

                TextBlock {
                    "Plain text"
                }

                "Does this work"

                if let pr {
                    MarkdownBlock {
                        "pr: \(pr)"
                    }

                    TextBlock {
                        "this"
                    }

                    "that"
                }
            }

            ActionsBlock {
                LinkButton(url: "https://link.com") {
                    "Link 1"
                }

                LinkButton(url: "https://link.com") {
                    "Link 2"
                }
            }

            LinkButton(url: "https://link.com") {
                "This is a link outside of an explicit action block"
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let messageJSON = try encoder.encode(message).string
        print(messageJSON)
    }
}
