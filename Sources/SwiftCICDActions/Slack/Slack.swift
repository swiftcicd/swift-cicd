import SwiftCICDCore

/// Namespace for Slack actions.
public struct Slack: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var slack: Slack { Slack(caller: self) }
}
