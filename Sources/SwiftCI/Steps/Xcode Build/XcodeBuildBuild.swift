extension XcodeBuildStep {
    public struct Build: Step {
        public let name = "Xcode Build: Build"

        public enum Configuration: ExpressibleByStringLiteral {
            case debug
            case release
            case custom(String)

            var string: String {
                switch self {
                case .debug:
                    return "Debug"
                case .release:
                    return "Release"
                case .custom(let value):
                    return value
                }
            }

            public init(stringLiteral value: String) {
                self = .custom(value)
            }
        }

        let scheme: String
        var configuration: Configuration?
        let destination: String
        var archivePath: String?

        public init(scheme: String, configuration: Configuration? = nil, destination: String, archivePath: String? = nil) {
            self.scheme = scheme
            self.configuration = configuration
            self.destination = destination
            self.archivePath = archivePath
        }

        public func run() async throws -> String {
            var arguments = [
                "-scheme", scheme,
                "-destination", destination
            ]

            if let configuration {
                arguments.append(contentsOf: [
                    "-configuration",
                    configuration.string
                ])
            }

            if let archivePath {
                arguments.append(contentsOf: [
                    "archive",
                    "-archivePath", archivePath
                ])
            }

            return try context.shell("xcodebuild", arguments)
        }
    }
}

public extension Step where Self == XcodeBuildStep.Build {
    static func xcodebuild(
        buildScheme scheme: String,
        configuration: XcodeBuildStep.Build.Configuration? = nil,
        destination: XcodeBuildStep.Destination,
        archiveTo archivePath: String? = nil
    ) -> XcodeBuildStep.Build {
        .init(scheme: scheme, configuration: configuration, destination: destination.argument, archivePath: archivePath)
    }
}
