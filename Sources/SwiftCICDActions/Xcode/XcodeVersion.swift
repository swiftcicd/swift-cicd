import SwiftCICDCore

// https://github.com/xcpretty/xcode-install

extension Xcode {
    public struct Select: Action {
        public let name = "Select Xcode Version"

        let version: String

        public init(_ version: String) {
            self.version = version
        }

        public func run() async throws {
            do {
                try await shell("xcversion select \(version)")
            } catch {
                try await shell("xcversion installed")
                throw error
            }
        }
    }
}

extension Xcode {
    public func select(_ version: String) async throws {
        try await run(Select(version))
    }
}
