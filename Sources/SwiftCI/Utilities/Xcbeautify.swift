public struct Xcbeautify: Step {
    public struct Options {
        /// Only print tasks that have warnings or errors.
        let quiet: Bool
        /// Only print tasks that have errors.
        let quieter: Bool
        /// Preserves unbeautified output lines.
        let preserveUnbeautified: Bool
        /// Print test result too under quiet/quieter flag.
        let isCI: Bool
        /// Disable the colored output.
        let disableColoredOutput: Bool
        /// Generate the specified reports.
        let report: String?
        /// The path to use when generating reports (default: build/reports)
        let reportPath: String?
        /// The name of JUnit report file name (default: junit.xml)
        let jUnitReportFileName: String?

        public init(
            quiet: Bool = false,
            quieter: Bool = false,
            preserveUnbeautified: Bool = false,
            isCI: Bool? = nil,
            disableColoredOutput: Bool = false,
            report: String? = nil,
            reportPath: String? = nil,
            jUnitReportFileName: String? = nil
        ) {
            self.quiet = quiet
            self.quieter = quieter
            self.preserveUnbeautified = preserveUnbeautified
            self.isCI = isCI ?? ContextValues.shared.environment.github.isCI
            self.disableColoredOutput = disableColoredOutput
            self.report = report
            self.reportPath = reportPath
            self.jUnitReportFileName = jUnitReportFileName
        }
    }

    private static var binPath: String?
    @StepState var xcbeautifyDirectory: String?

    let command: ShellCommand
    let options: Options

    public init(command: ShellCommand, options: Options = .init()) {
        self.command = command
        self.options = options
    }

    public func run() async throws -> String {
        if try !isInstalled() {
            try await install()
        }

        let binPath = Self.binPath ?? "xcbeautify"
        var xcbeautify = Command("set -o pipefail && \(command.command)", command.arguments + ["|", binPath])
        xcbeautify.add("--quiet", if: options.quiet)
        xcbeautify.add("--quieter", if: options.quieter)
        xcbeautify.add("--preserve-unbeautified", if: options.preserveUnbeautified)
        xcbeautify.add("--is-ci", if: options.isCI)
        xcbeautify.add("--disable-colored-output", if: options.disableColoredOutput)
        xcbeautify.add("--report", ifLet: options.report)
        xcbeautify.add("--report-path", ifLet: options.reportPath)
        xcbeautify.add("--junit-report-filename", ifLet: options.jUnitReportFileName)
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

//        try context.shell("git clone https://github.com/tuist/xcbeautify.git")
        try context.shell("git clone --branch export-localizations-warnings-support --single-branch https://github.com/clayellis/xcbeautify.git")
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
    func xcbeautify(_ command: ShellCommand, options: Xcbeautify.Options = .init()) async throws -> String {
        try await step(Xcbeautify(command: command, options: options))
    }
}
