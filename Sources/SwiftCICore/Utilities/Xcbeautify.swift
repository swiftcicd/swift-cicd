public struct Xcbeautify: Action {
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
            self.isCI = isCI ?? ContextValues.current.environment.github.isCI
            self.disableColoredOutput = disableColoredOutput
            self.report = report
            self.reportPath = reportPath
            self.jUnitReportFileName = jUnitReportFileName
        }
    }

    private static var binPath: String?
    @State var xcbeautifyDirectory: String?

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

        var xcbeautify = ShellCommand("set -o pipefail && \(command) | \(binPath)")
        xcbeautify.append("--quiet", if: options.quiet)
        xcbeautify.append("--quieter", if: options.quieter)
        xcbeautify.append("--preserve-unbeautified", if: options.preserveUnbeautified)
        xcbeautify.append("--is-ci", if: options.isCI)
        xcbeautify.append("--disable-colored-output", if: options.disableColoredOutput)
        xcbeautify.append("--report", ifLet: options.report)
        xcbeautify.append("--report-path", ifLet: options.reportPath)
        xcbeautify.append("--junit-report-filename", ifLet: options.jUnitReportFileName)
        return try context.shell(xcbeautify)
    }

    public func cleanUp(error: Error?) async throws {
        try uninstall()
    }

    func isInstalled() throws -> Bool {
        do {
            let output = try context.shell("which xcbeautify", quiet: true)
            return !output.contains("not found")
        } catch {
            // 'which' will exit with status 1 (throw an error) when the tool isn't found.
            // Prefer the installed version over the temporary bin path.
            // But if the binPath has been cached from a previous build, treat it as installed.
            return Self.binPath != nil
        }
    }

    func install() async throws {
        let currentDirectory = context.files.currentDirectoryPath
        defer {
            do {
                try context.files.changeCurrentDirectory(currentDirectory)
            } catch {
                logger.error("Failed to return to current directory '\(currentDirectory)' after installing xcbeautify")
            }
        }

        let temp = context.files.temporaryDirectory.path
        try context.files.changeCurrentDirectory(temp)
        let xcbeautify = temp/"xcbeautify"

        if context.files.fileExists(atPath: xcbeautify) {
            try context.files.removeItem(atPath: xcbeautify)
        }

//        try context.shell("git clone https://github.com/tuist/xcbeautify.git")
        try context.shell("git clone --branch export-localizations-warnings-support --single-branch https://github.com/clayellis/xcbeautify.git")
        xcbeautifyDirectory = xcbeautify

        // 'make install' needs sudo permissions to copy into /usr/local/bin/
        // So instead of running install, we'll build the xcbeautify and then cache its bin path
        let flags = "--configuration release --disable-sandbox"
        try context.files.changeCurrentDirectory(xcbeautify)
        try context.shell("swift build \(flags)")
        let binPath = try context.shell("swift build --show-bin-path \(flags)")
        Self.binPath = try binPath/"xcbeautify"
    }

    func uninstall() throws {
        if let xcbeautifyDirectory {
            try context.files.removeItem(atPath: xcbeautifyDirectory)
        }
    }
}

public extension Action {
    func xcbeautify(_ command: ShellCommand, options: Xcbeautify.Options = .init()) async throws -> String {
        try await action(Xcbeautify(command: command, options: options))
    }
}
