public struct Xcbeautify: Step {
    private static var binPath: String?
    @StepState var xcbeautifyDirectory: String?

    let command: ShellCommand

    public init(command: ShellCommand) {
        self.command = command
    }

    public func run() async throws -> String {
        if try !isInstalled() {
            try await install()
        }

        let binPath = Self.binPath ?? "xcbeautify"
        let xcbeautify = Command("set -o pipefail && \(command.command)", command.arguments + ["|", binPath])
        return try context.shell(xcbeautify)
    }

    public func cleanUp(error: Error?) async throws {
        try uninstall()
    }

    func isInstalled() throws -> Bool {
        do {
            let output = try context.shell("which", "xcbeautify", quiet: true)
            return !output.contains("not found")
        } catch {
            // 'which' will exit with status 1 (throw an error) when the tool isn't found.
            // Prefer the installed version over the temporary bin path.
            // But if the binPath has been cached from a previous build, treat it as installed.
            return Self.binPath != nil
        }
    }

    func install() async throws {
        let currentDirectory = context.fileManager.currentDirectoryPath
        defer {
            do {
                try context.fileManager.changeCurrentDirectory(to: currentDirectory)
            } catch {
                logger.error("Failed to return to current directory '\(currentDirectory)' after installing xcbeautify")
            }
        }

        let temp = context.fileManager.temporaryDirectory.path
        try context.fileManager.changeCurrentDirectory(to: temp)
        let xcbeautify = temp/"xcbeautify"

        if context.fileManager.fileExists(atPath: xcbeautify) {
            try context.fileManager.removeItem(atPath: xcbeautify)
        }

        try context.shell("git clone https://github.com/tuist/xcbeautify.git")
        xcbeautifyDirectory = xcbeautify

        // 'make install' needs sudo permissions to copy into /usr/local/bin/
        // So instead of running install, we'll build the xcbeautify and then cache its bin path
        let flags = "--configuration release --disable-sandbox"
        try context.fileManager.changeCurrentDirectory(to: xcbeautify)
        try context.shell("swift build \(flags)")
        let binPath = try context.shell("swift build --show-bin-path \(flags)")
        Self.binPath = binPath/"xcbeautify"
    }

    func uninstall() throws {
        if let xcbeautifyDirectory {
            try context.fileManager.removeItem(atPath: xcbeautifyDirectory)
        }
    }
}

public extension StepRunner {
    func xcbeautify(_ command: ShellCommand) async throws -> String {
        try await step(Xcbeautify(command: command))
    }
}
