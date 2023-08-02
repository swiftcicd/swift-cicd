import SwiftCICDCore

/// Namespace for signing actions.
public struct Signing: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var signing: Signing { Signing(caller: self) }
}
