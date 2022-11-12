extension XcodeBuildStep {
    public struct Build: Step {
        public let name = "Xcode Build: Build"

        let scheme: String
        let destination: String

        public init(scheme: String, destination: String) {
            self.scheme = scheme
            self.destination = destination
        }

        public func run() async throws -> String {
            try context.shell("xcodebuild", "--scheme", scheme, "--destination", destination)
        }
    }
}

public extension Step where Self == XcodeBuildStep.Build {
    static func xcodebuild(buildScheme scheme: String, destination: XcodeBuildStep.Destination) -> XcodeBuildStep.Build {
        .init(scheme: scheme, destination: destination.argument)
    }
}
