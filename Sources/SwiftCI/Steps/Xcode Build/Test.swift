extension XcodeBuild {
    public struct Test: CommandStep {
        public let name = "Xcode Build: Test"

        let scheme: String
        let destination: String
        let withoutBuilding: Bool

        public var command: Command {
            Command(command: "xcodebuild", arguments: [withoutBuilding ? "test-without-building" : "test", "--scheme", scheme, "--destination", destination])
        }

        public init(scheme: String, destination: String, withoutBuilding: Bool) {
            self.scheme = scheme
            self.destination = destination
            self.withoutBuilding = withoutBuilding
        }
    }
}

public extension Step where Self == XcodeBuild.Test {
    static func xcodebuild(testScheme scheme: String, destination: XcodeBuild.Destination, withoutBuilding: Bool) -> XcodeBuild.Test {
        .init(scheme: scheme, destination: destination.argument, withoutBuilding: withoutBuilding)
    }
}
