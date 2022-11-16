public protocol Step<Output> {
    associatedtype Output
    var name: String { get }
    func run() async throws -> Output
    func cleanUp(error: Error?) async throws
}

public extension Step {
    var name: String {
        "\(self)"
    }

    func cleanUp(error: Error?) async throws {}
}

public extension Step {
    static var context: ContextValues { .shared }
    var context: ContextValues { .shared }
}
