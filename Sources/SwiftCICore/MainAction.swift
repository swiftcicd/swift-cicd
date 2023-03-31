import Foundation
import Logging

public protocol MainAction: Action<Void> {
    static var logLevel: Logger.Level { get }
    init()
}

extension MainAction {
    public static var logLevel: Logger.Level { .debug }

    public static func main() async {
        await ContextValues.withValues { $0.logger.logLevel = Self.logLevel } operation: {
            do {
                let platform = try context.platform
                try logEnvironment()
                logger.info("Running on \(platform.name)")
                try context.fileManager.changeCurrentDirectory(platform.workingDirectory)
                let mainAction = self.init()
                try await mainAction.action(mainAction)
                await cleanUp(error: nil)
                try? context.endLogGroup()
                exit(0)
            } catch {
                let trace = context.stack.traceLastFrame()
                logger.error("\n❌ \(errorMessage(from: error))")
                await cleanUp(error: error)
                try? context.endLogGroup()
                if let trace {
                    logger.error("\n❌ An error occurred while running action: \(trace)")
                    if let errorLines = errorPreview(from: error) {
                        logger.error("\n\(errorLines)")
                    }
                }
                exit(1)
            }
        }
    }

    static func logEnvironment() throws {
        try context.withLogGroup(named: "Environment") {
            logger.debug("""
                Environment:
                \(context.environment._dump().indented())
                """
            )
        }
    }

    static func errorMessage(from error: Error) -> String {
        var errorMessage = "Exiting on error:\n"
        let errorLocalizedDescription = error.localizedDescription
        let interpolatedError = "\(error)"
        if errorLocalizedDescription != interpolatedError {
            errorMessage += """
            \(errorLocalizedDescription)
            \(interpolatedError)
            """
        } else {
            errorMessage += errorLocalizedDescription
        }
        return errorMessage
    }

    static func errorPreview(from error: Error) -> String? {
        let errorLocalizedDescription = error.localizedDescription
        let interpolatedError = "\(error)"

        let lines = [errorLocalizedDescription, interpolatedError]
            .joined(separator: "\n")
            .components(separatedBy: "\n")

        var errorLines = [String]()
        for lineIndex in errorLines.indices {
            let line = errorLines[lineIndex]
            // If the line line starts with the error marker and we don't already have that error captured (in case the
            // localized error description and the interpolated error description are the same.)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("❌"), !errorLines.contains(line) {
                errorLines.append(line)
                // Look ahead two lines for an annotated line
                if let lookAheadIndex = errorLines.index(lineIndex, offsetBy: 2, limitedBy: errorLines.endIndex) {
                    let lookAheadLine = errorLines[lookAheadIndex]
                    if lookAheadLine.contains("^~") {
                        errorLines.append(errorLines[lineIndex + 1])
                        errorLines.append(errorLines[lineIndex + 2])
                    }
                }
            }
        }

        guard !errorLines.isEmpty else {
            return nil
        }

        return errorLines.joined(separator: "\n")
    }

    static func cleanUp(error: Error?) async {
        do {
            try await context.withLogGroup(named: "Cleaning up...") {
                while let action = context.stack.pop()?.action {
                    do {
                        logger.info("Cleaning up after action: \(action.name).")
                        try await action.cleanUp(error: error)
                    } catch {
                        logger.error("Failed to clean up after action: \(action.name). Error: \(error)")
                    }
                }
            }
        } catch {
            logger.error("Failed to clean up: \(error)")
        }
    }
}
