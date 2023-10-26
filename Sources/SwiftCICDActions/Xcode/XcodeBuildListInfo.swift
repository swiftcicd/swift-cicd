import SwiftCICDCore

public extension XcodeBuild {
    struct Info {
        public let targets: [String]
        public let buildConfigurations: [String]
        public let schemes: [String]

        public init(container: Xcode.Container? = nil) async throws {
            let container = try container ?? ContextValues.current.xcodeContainer
            var command = ShellCommand("xcodebuild")
            try command.append(container?.flag)
            command.append("-list")
            let output = try await ContextValues.current.shell(command, quiet: true)
            try self.init(listOutput: output)
        }

        // Example output
        /*
        Command line invocation:
            /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -list

        User defaults from command line:
            IDEPackageSupportUseBuiltinSCM = YES

        Information about project "Project":
            Targets:
                Project

            Build Configurations:
                Debug
                Release

            If no build configuration is specified and -scheme is not passed then "Release" is used.

            Schemes:
                Scheme

        */
        // Should result in: Info(targets: ["Project"], buildConfigurations: ["Debug", "Release"], schemes: ["Scheme"])

        init(listOutput: String) throws {
            let lines = listOutput
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard let targets = lines.elements(betweenFirstOccurrenceOf: "Targets:", andNextOccurrenceOf: "") else {
                throw ActionError("Failed to parse xcodebuild -list output to find targets.")
            }

            guard let buildConfigurations = lines.elements(betweenFirstOccurrenceOf: "Build Configurations:", andNextOccurrenceOf: "") else {
                throw ActionError("Failed to parse xcodebuild -list output to find build configurations.")
            }

            guard let schemes = lines.elements(betweenFirstOccurrenceOf: "Schemes:", andNextOccurrenceOf: "") else {
                throw ActionError("Failed to parse xcodebuild -list output to find schemes.")
            }

            self.init(targets: targets, buildConfigurations: buildConfigurations, schemes: schemes)
        }

        init(
            targets: [String],
            buildConfigurations: [String],
            schemes: [String]
        ) {
            self.targets = targets
            self.buildConfigurations = buildConfigurations
            self.schemes = schemes
        }
    }
}

extension Array<String> {
    func elements(betweenFirstOccurrenceOf start: String, andNextOccurrenceOf end: String) -> [String]? {
        guard let startIndex = self.firstIndex(of: start)?.advanced(by: 1),
              let endIndex = self[startIndex...].firstIndex(of: end)
        else {
            return nil
        }

        return Array(self[startIndex..<endIndex])
    }
}

public extension XcodeBuild {
    static func getInfo(container: Xcode.Container? = nil) async throws -> XcodeBuild.Info {
        try await XcodeBuild.Info(container: container)
    }
}
