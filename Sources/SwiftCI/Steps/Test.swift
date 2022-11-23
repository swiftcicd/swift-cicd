public struct Test: Step {
    public let name = "Xcode Build: Test"

    var scheme: String?
    var destination: String?
    var withoutBuilding: Bool

    public init(
        scheme: String? = nil,
        destination: String? = nil,
        withoutBuilding: Bool = false
    ) {
        self.scheme = scheme
        self.destination = destination
        self.withoutBuilding = withoutBuilding
    }

    public func run() async throws -> String {
        var xcodebuild = Command(
            "xcodebuild",
            withoutBuilding ? "test-without-building" : "test"
        )
        xcodebuild.add("-scheme", ifLet: scheme)
        xcodebuild.add("-destination", ifLet: destination)
        return try context.shell(xcodebuild)
    }
}

public extension StepRunner {
    @discardableResult
    func test(
        scheme: String? = nil,
        destination: XcodeBuildStep.Destination? = nil,
        withoutBuilding: Bool = false
    ) async throws -> String {
        try await step {
            Test(scheme: scheme, destination: destination?.argument, withoutBuilding: withoutBuilding)
        }
    }
}
