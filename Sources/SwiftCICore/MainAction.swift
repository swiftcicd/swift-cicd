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
                try context.endCurrentLogGroup()
                try logEnvironment()
                logger.info("Running on \(platform.name)")
                try context.fileManager.changeCurrentDirectory(platform.workspace)
                let mainAction = self.init()
                try await mainAction.action(mainAction)
                await cleanUp(error: nil)
                exit(0)
            } catch {
                let trace = context.stack.traceLastFrame()
                logger.error("\n❌ \(errorMessage(error: error))")
                await cleanUp(error: error)
                if let trace {
                    logger.error("\n❌ An error occurred while running action: \(trace)")
                }
                exit(1)
            }
        }
    }

    static func logEnvironment() throws {
        try context.performInLogGroup(named: "Environment") {
            logger.debug("""
                Environment:
                \(context.environment._dump().indented())
                """
            )
        }
    }

    static func errorMessage(error: Error) -> String {
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

    static func cleanUp(error: Error?) async {
        do {
            try await context.performInLogGroup(named: "Cleaning up...") {
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
