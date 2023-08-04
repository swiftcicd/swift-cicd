import SwiftCICDCore

// https://github.com/xcpretty/xcode-install

extension Xcode {
    public struct Select: Action {
        let version: String

        public init(_ version: String) {
            self.version = version
        }

        public func run() async throws {
            try await shell("xcversion select \(version)")
        }
    }
}

extension Xcode {
    public func select(_ version: String) async throws {
        try await run(Select(version))
    }
}
