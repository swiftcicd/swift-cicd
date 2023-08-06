/// Marker protocol for Group.
protocol _GroupAction: Action {}

public struct Group<Wrapped: Action>: _GroupAction {
    private var explicitName: String?
    private var wrapped: Wrapped
    public var name: String {
        explicitName ?? "Group"
    }

    public init(_ name: String? = nil, @ActionBuilder _ group: () -> Wrapped) {
        self.explicitName = name
        self.wrapped = group()
    }

    public func run() async throws {
        context.platform.startLogGroup(named: "Action: \(name)")
        try await self.run(wrapped)
    }
}
