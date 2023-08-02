import SwiftCICDCore

/// Namespace for Xcode actions.
public struct Xcode: ActionNamespace {
    public let caller: any Action

    public var project: String? {
        get throws {
            try context.xcodeProject
        }
    }
}

public extension Action {
    var xcode: Xcode { Xcode(caller: self) }
}
