import SwiftCICDCore

/// Namespace for SwiftPR actions.
public struct SwiftPR: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var swiftPR: SwiftPR { SwiftPR(caller: self) }
}
