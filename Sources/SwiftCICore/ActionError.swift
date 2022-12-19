import Foundation

public struct ActionError: LocalizedError, CustomStringConvertible {
    let action: (any Action)?
    let message: String
    let error: Error?
    let file: StaticString
    let line: UInt

    public init(
        _ message: String,
        action: (any Action)? = nil,
        error: Error? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        @Context(\.currentAction) var currentAction
        self.action = action ?? currentAction
        self.message = message
        self.error = error
        self.file = file
        self.line = line
    }

    public var description: String {
        // TODO: Add the trace to the description rather than just the name?
        var description = "An error occurred while running \(action.map { "action: \($0.name)" } ?? "an action"). (file: \(file), line: \(line))"

        if let error {
            description += "\nError: \(error)"
        }

        description += "\nMessage: \(message)"

        return description
    }

    public var errorDescription: String? {
        description
    }
}
