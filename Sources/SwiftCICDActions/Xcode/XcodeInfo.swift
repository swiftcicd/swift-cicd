import SwiftCICDCore
import RegexBuilder

extension Xcode {
    public struct Info: Action {
        public let name = "Current Xcode Info"

        public struct Output {
            public let version: String
            public let build: String
            public let path: String
        }

        public func run() async throws -> Output {
            let xcodeBuildOutput = try await shell("xcodebuild -version")
            let xcodeSelectOutput = try await shell("xcode-select -p")

            let xcodeBuildLines = xcodeBuildOutput
                .components(separatedBy: .newlines)

            guard let xcodeBuildVersion = xcodeBuildLines
                .first
                .flatMap({ $0.suffix(after: "Xcode ") })
            else {
                throw ActionError("Failed to parse version from xcodebuild -version output: \(xcodeBuildOutput)")
            }

            guard let xcodeBuildBuild = xcodeBuildLines
                .last
                .flatMap({ $0.suffix(after: "Build version ") })
            else {
                throw ActionError("Failed to parse build from xcodebuild -version output: \(xcodeBuildOutput)")
            }

            return Output(
                version: xcodeBuildVersion,
                build: xcodeBuildBuild,
                path: xcodeSelectOutput
            )
        }
    }
}

extension String {
    func suffix(after prefix: String) -> String? {
        guard self.hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}

public extension Xcode {
    @discardableResult
    func outputInfo() async throws -> Info.Output {
        try await run(Info())
    }
}
