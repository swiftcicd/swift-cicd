extension XcodeBuild {
    public struct Build: CommandStep {
        public let name = "Xcode Build: Build"

        let scheme: String
        let destination: String

        public var command: Command {
            Command(command: "xcodebuild", arguments: ["--scheme", scheme, "--destination", destination])
        }

        public init(scheme: String, destination: String) {
            self.scheme = scheme
            self.destination = destination
        }
    }
}

public extension Step where Self == XcodeBuild.Build {
    static func xcodebuild(buildScheme scheme: String, destination: XcodeBuild.Destination) -> XcodeBuild.Build {
        .init(scheme: scheme, destination: destination.argument)
    }
}
