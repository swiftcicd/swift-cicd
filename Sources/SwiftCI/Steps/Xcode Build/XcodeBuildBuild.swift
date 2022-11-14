extension XcodeBuildStep {
    public struct Build: Step {
        public let name = "Xcode Build: Build"

        let scheme: String
        let destination: String
        let archive: Bool

        public init(scheme: String, destination: String, archive: Bool) {
            self.scheme = scheme
            self.destination = destination
            self.archive = archive
        }

        public func run() async throws -> String {
            var arguments = [
                "--scheme", scheme,
                "--destination", destination
            ]

            if archive {
                arguments.append("archive")
            }

            return try context.shell("xcodebuild", arguments)
        }
    }
}

public extension Step where Self == XcodeBuildStep.Build {
    static func xcodebuild(buildScheme scheme: String, destination: XcodeBuildStep.Destination, archive: Bool = false) -> XcodeBuildStep.Build {
        .init(scheme: scheme, destination: destination.argument, archive: archive)
    }
}
