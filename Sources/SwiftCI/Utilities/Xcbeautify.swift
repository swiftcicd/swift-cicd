public struct Xcbeautify: Step {
    @StepState var xcbeautifyDirectory: String?

    let command: ShellCommand

    public init(command: ShellCommand) {
        self.command = command
    }

    public func run() async throws -> String {
        if try !isInstalled() {
            try await install()
        }

        let xcbeautify = Command("set -o pipefail && \(command.command)", command.arguments + ["|", "xcbeautify"])
        return try context.shell(xcbeautify)
    }

    public func cleanUp(error: Error?) async throws {
        try uninstall()
    }

    func isInstalled() throws -> Bool {
        let output = try context.shell("which", "xcbeautify")
        return !output.contains("not found")
    }

    func install() async throws {
        let temp = context.fileManager.temporaryDirectory.path
        try context.fileManager.changeCurrentDirectory(to: temp)
        let xcbeautify = temp/"xcbeautify"
        try context.shell("git clone https://github.com/tuist/xcbeautify.git")
        try context.shell("cd xcbeautify")
        try context.shell("make install")
        xcbeautifyDirectory = xcbeautify
    }

    func uninstall() throws {
        guard let xcbeautifyDirectory else {
            return
        }

        try context.fileManager.changeCurrentDirectory(to: xcbeautifyDirectory)
        try context.shell("make uninstall")
        try context.fileManager.removeItem(atPath: xcbeautifyDirectory)
    }
}

public extension StepRunner {
    func xcbeautify(_ command: ShellCommand) async throws -> String {
        try await step(Xcbeautify(command: command))
    }
}
