import Foundation
import OctoKit
import SwiftCICDCore
import SwiftPR

// TODO: Make SwiftPR generic to different platforms.
// TODO: Inject that "generic" behavior into this action.

public struct RunSwiftPRCheck: Action {
    let prCheck: PRCheck.Type

    public var name: String {
        "Run SwiftPR Check: \(prCheck.name)"
    }

    init(_ prCheck: PRCheck.Type) {
        self.prCheck = prCheck
    }

    public struct Output {
        public let status: OctoKit.Status.State
        public let comment: OctoKit.Comment
    }

    public func run() async throws -> Output {
        try await prCheck.main()
        let status = prCheck.statusState
        // If the swift-pr comment is created for the first time it may be slow to appear on the API.
        // It usually appears between 30 and 60 seconds.
        return try await retry(every: 15, times: 5) {
            guard let comment = try await prCheck.getSwiftPRComment() else {
                throw ActionError("SwiftPR comment not found")
            }

            return Output(status: status, comment: comment)
        }
    }
}

public extension SwiftPR {
    @discardableResult
    func runCheck(_ prCheck: PRCheck.Type) async throws -> RunSwiftPRCheck.Output {
        try await run(RunSwiftPRCheck(prCheck))
    }
}
