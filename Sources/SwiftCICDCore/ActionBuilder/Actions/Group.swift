/// Marker protocol for Group.
protocol _GroupAction: _BuilderAction {}

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
        if !isRunningInsideGroup {
            context.platform.startLogGroup(named: name)
        }
        try await self.run(wrapped)
    }
}

public extension Action {
    func logGroup(_ name: String) -> some Action {
        Group(name) { self }
    }
}

extension Action {
    var isRunningInsideGroup: Bool {
        var current = context.currentStackFrame?.parent
        while let c = current {
            if c.action.isGroup {
                return true
            } else {
                current = current?.parent
            }
        }
        return false
    }
}
