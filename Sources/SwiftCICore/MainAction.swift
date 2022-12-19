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
                logEnvironment()
                let platform = try detectPlatform()
                logger.info("Running on \(platform.name)")
                try await ContextValues.withValue(\.platform, platform) {
                    try context.fileSystem.changeCurrentWorkingDirectory(to: platform.workspace())
                    let mainAction = self.init()
                    try await mainAction.action(mainAction)
                    await cleanUp(error: nil)
                }
                exit(0)
            } catch {
                let failedFrame = context.stack.peak()!
                let trace = context.stack.trace(frame: failedFrame)
                logger.error("\n❌ \(errorMessage(error: error))")
                await cleanUp(error: error)
                logger.error("\n❌ An error occurred while running action: \(trace)")
                exit(1)
            }
        }
    }

    static func logEnvironment() {
        context.performInLogGroup(named: "Environment") {
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
        await context.performInLogGroup(named: "Cleaning up...") {
            while let action = context.stack.pop()?.action {
                do {
                    logger.info("Cleaning up after action: \(action.name).")
                    try await action.cleanUp(error: error)
                } catch {
                    logger.error("Failed to clean up after action: \(action.name). Error: \(error)")
                }
            }
        }
    }
}

extension ContextValues {
    enum WorkspaceKey: ContextKey {
        static let defaultValue: AbsolutePath = {
            do {
                let workspace = try ContextValues.current.environment.github.$workspace.require()
                return try AbsolutePath(validating: workspace)
            } catch {
                // TODO: Should this fatalError?
                // Falling back on the temporary directory is probably the best we can do.
                return try! AbsolutePath(validating: FileManager.default.temporaryDirectory.path)
            }
        }()
    }

    public var workspace: AbsolutePath {
        get { self[WorkspaceKey.self] }
        set { self[WorkspaceKey.self] = newValue }
    }
}
