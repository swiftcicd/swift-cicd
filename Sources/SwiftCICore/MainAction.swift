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
                    if let errorLines = errorLines(from: error) {
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

    static func errorLines(from error: Error) -> String? {
        let errorLocalizedDescription = error.localizedDescription
        let interpolatedError = "\(error)"
        let errorLines = [errorLocalizedDescription, interpolatedError]
            .joined(separator: "\n")
            .components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("❌") }
            .joined(separator: "\n")

        guard !errorLines.isEmpty else {
            return nil
        }

        return errorLines
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
