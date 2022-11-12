extension XcodeBuildStep {
    public struct Test: Step {
        public let name = "Xcode Build: Test"

        let scheme: String
        let destination: String
        let withoutBuilding: Bool

        public init(scheme: String, destination: String, withoutBuilding: Bool) {
            self.scheme = scheme
            self.destination = destination
            self.withoutBuilding = withoutBuilding
        }

        public func run() async throws -> String {
            try context.shell("xcodebuild", withoutBuilding ? "test-without-building" : "test", "--scheme", scheme, "--destination", destination)
        }
    }
}

public extension Step where Self == XcodeBuildStep.Test {
    static func xcodebuild(testScheme scheme: String, destination: XcodeBuildStep.Destination, withoutBuilding: Bool) -> XcodeBuildStep.Test {
        .init(scheme: scheme, destination: destination.argument, withoutBuilding: withoutBuilding)
    }
}
