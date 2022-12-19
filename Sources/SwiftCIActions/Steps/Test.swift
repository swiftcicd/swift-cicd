public struct Test: Step {
    public let name = "Xcode Build: Test"

    var scheme: String?
    var destination: String?
    var withoutBuilding: Bool
    let xcbeautify: Bool

    public init(
        scheme: String? = nil,
        destination: String? = nil,
        withoutBuilding: Bool = false,
        xcbeautify: Bool = false
    ) {
        self.scheme = scheme
        self.destination = destination
        self.withoutBuilding = withoutBuilding
        self.xcbeautify = xcbeautify
    }

    public func run() async throws -> String {
        var xcodebuild = Command(
            "xcodebuild",
            withoutBuilding ? "test-without-building" : "test"
        )
        xcodebuild.add("-scheme", ifLet: scheme)
        xcodebuild.add("-destination", ifLet: destination)

        if xcbeautify {
            return try await xcbeautify(xcodebuild)
        } else {
            return try context.shell(xcodebuild)
        }
    }
}

public extension StepRunner {
    @discardableResult
    func test(
        scheme: String? = nil,
        destination: XcodeBuildStep.Destination? = nil,
        withoutBuilding: Bool = false,
        xcbeautify: Bool = false
    ) async throws -> String {
        try await step {
            Test(
                scheme: scheme,
                destination: destination?.argument,
                withoutBuilding: withoutBuilding,
                xcbeautify: xcbeautify
            )
        }
    }
}
