public protocol Step<Output> {
    associatedtype Output
    var name: String { get }
    func run() async throws -> Output
}

extension Step {
    public var context: ContextValues { .shared }
}
