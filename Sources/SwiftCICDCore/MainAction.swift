import Foundation
import Logging

public protocol MainAction: Action<Void> {
    static var platform: Platform.Type? { get }
    static var logLevel: Logger.Level { get }
    init()

    /// Runs before every action run by this action. Any errors thrown will stop the execution of the entire workflow.
    func before() async throws
}

public extension MainAction {
    // Default is nil so that platform detection is the default behavior.
    static var platform: Platform.Type? { nil }

    // Default log level is debug
    static var logLevel: Logger.Level { .debug }
}

extension MainAction {
    public static func main() async {
        guard let platform = self.platform ?? detectPlatform() else {
            print("❌ Failed to detect platform")
            exit(1)
        }

        // Bootstrap the logging system using the platform's log handler.
        LoggingSystem.bootstrap(platform.logHandler(label:))

        // Set the log level to the level specified by the main action.
        logger.logLevel = logLevel

        await ContextValues.withValues {
            $0.platform = platform
        } operation: {
            do {
                logger.info("Running on \(platform.name)")
                logEnvironment()
                try context.fileManager.changeCurrentDirectory(platform.workingDirectory)
                let mainAction = self.init()
                try await mainAction.run(mainAction)
                let table = context.stack.generateTable(finalActionFailed: false)
                await cleanUp(error: nil)
                await uninstallTools()
                platform.endLogGroup()
                print("\(table.textualDescription())")
                exit(0)
            } catch {
                let table = context.stack.generateTable(finalActionFailed: true)
                let trace = context.stack.traceLastFrame()
                logger.error("\n❌ \(errorMessage(from: error))")
                await cleanUp(error: error)
                await uninstallTools()
                platform.endLogGroup()
                print("\(table.textualDescription())")
                if let trace {
                    logger.error("\n❌ An error occurred while running action: \(trace)")
                    if let errorLines = errorPreview(from: error) {
                        logger.error("""
                            ...
                            \(errorLines)
                            ... (See full error in context by expanding the \(trace.frames.last?.action.name ?? "last") action)
                            """
                        )
                    }
                }
                exit(1)
            }
        }
    }

    static func detectPlatform(`default`: (Platform.Type)? = nil) -> Platform.Type? {
        let builtInPlatforms: [any Platform.Type] = [
            LocalPlatform.self,
            GitHubPlatform.self
        ]

        return builtInPlatforms.first(where: { $0.detect() }) ?? `default`
    }

    static func logEnvironment() {
        context.platform.startLogGroup(named: "Environment")
        logger.debug("""
            Environment:
            \(context.environment._dump().indented())
            """
        )
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

        let errorPrefixes = ["❌", "error: "]

        var errorLines = [String]()
        for lineIndex in lines.indices {
            let line = lines[lineIndex]
            // If the line line starts with any of the error prefixes and we don't already have that error captured (in case the
            // localized error description and the interpolated error description are the same.)
            if errorPrefixes.contains(where: { line.trimmingCharacters(in: .whitespaces).hasPrefix($0) }), !errorLines.contains(line) {
                errorLines.append(line)
                // Look ahead two lines for an annotated line
                if let lookAheadIndex = lines.index(lineIndex, offsetBy: 2, limitedBy: lines.endIndex) {
                    let lookAheadLine = lines[lookAheadIndex]
                    if lookAheadLine.contains("^~") {
                        errorLines.append(lines[lineIndex + 1])
                        errorLines.append(lines[lineIndex + 2])
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
        context.platform.startLogGroup(named: "Cleaning up...")
        while let action = context.stack.pop()?.action {
            // Don't clean up after build actions.
            guard !action.isBuilder else {
                continue
            }

            do {
                logger.info("Cleaning up after action: \(action.name)")
                try await action.cleanUp(error: error)
            } catch {
                logger.error("Failed to clean up after action: \(action.name). Error: \(error)")
            }
        }
    }

    static func uninstallTools() async {
        await context.tools.uninstall()
    }
}
