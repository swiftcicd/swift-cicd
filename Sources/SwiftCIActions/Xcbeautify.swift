import SwiftCICore

public struct Xcbeautify: Tool {
    public struct Options {
        /// Only print tasks that have warnings or errors.
        public var quiet: Bool
        /// Only print tasks that have errors.
        public var quieter: Bool
        /// Preserves unbeautified output lines.
        public var preserveUnbeautified: Bool
        /// Print test result too under quiet/quieter flag.
        public var isCI: Bool
        /// Disable the colored output.
        public var disableColoredOutput: Bool
        /// Generate the specified reports.
        public var report: String?
        /// The path to use when generating reports (default: build/reports)
        public var reportPath: String?
        /// The name of JUnit report file name (default: junit.xml)
        public var jUnitReportFileName: String?

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

    public static let name = "xcbeautify"

    public static var isInstalled: Bool {
        get async {
            do {
                let output = try await context.shell("which xcbeautify", quiet: true)
                return !output.contains("not found")
            } catch {
                return false
            }
        }
    }

    public static func install() async throws {
        try await context.shell("brew install xcbeautify")
//        try await context.shell("/opt/homebrew/bin/brew install xcbeautify")
    }

    public static func uninstall() async throws {
//        try await context.shell("/opt/homebrew/bin/brew uninstall xcbeautify")
        try await context.shell("brew uninstall xcbeautify")
    }

    public static func beautify(_ command: ShellCommand, options: Options = .init()) async throws -> String {
        var xcbeautify = ShellCommand("set -o pipefail && \(command) | xcbeautify")
        xcbeautify.append("--quiet", if: options.quiet)
        xcbeautify.append("--quieter", if: options.quieter)
        xcbeautify.append("--preserve-unbeautified", if: options.preserveUnbeautified)
        xcbeautify.append("--is-ci", if: options.isCI)
        xcbeautify.append("--disable-colored-output", if: options.disableColoredOutput)
        xcbeautify.append("--report", ifLet: options.report)
        xcbeautify.append("--report-path", ifLet: options.reportPath)
        xcbeautify.append("--junit-report-filename", ifLet: options.jUnitReportFileName)
        return try await context.shell(xcbeautify)
    }
}

public extension Tools {
    var xcbeautify: Xcbeautify.Type {
        get async throws {
            try await self[Xcbeautify.self]
        }
    }
}

public extension Action {
    @discardableResult
    func xcbeautify(_ command: ShellCommand, options: Xcbeautify.Options = .init()) async throws -> String {
        let xcbeautify = try await context.tools.xcbeautify
        return try await xcbeautify.beautify(command, options: options)
    }
}
