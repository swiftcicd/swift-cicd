import SwiftCICDCore

// https://github.com/xcpretty/xcode-install

extension Xcode {
    public struct Select: Action {
        public let name = "Select Xcode Version"

        private enum Strategy {
            case exact(Version)
            case from(Version)
        }

        private let strategy: Strategy

        public init(_ version: String) throws {
            strategy = try .exact(Version(version))
        }

        public init(from version: String) throws {
            strategy = try .from(Version(version))
        }

        public func run() async throws {
            switch strategy {
            case .exact(let version):
                try await selectExact(version: version)

            case .from(let version):
                try await selectFrom(version: version)
            }
        }

        private func selectExact(version: Version) async throws {
            do {
                try await shell("xcversion select \(version.versionString())")
            } catch {
                logger.info("Installed versions:")
                try await shell("xcversion installed")
                throw error
            }
        }

        private func selectFrom(version: Version) async throws {
            do {
                try await shell("xcversion select \(version.versionString())")
            } catch {
                let installed = try await shell("xcversion installed", log: false)
                let versions = installed
                    .components(separatedBy: "\n")
                    .map { String($0.prefix { !$0.isWhitespace }) }
                    .compactMap { try? Version($0) }
                    .sorted(by: >)

                guard let newerOrSame = versions.first(where: { $0 >= version }) else {
                    throw ActionError("There isn't a version of Xcode installed that satisfies the condition. Installed versions:\n\(installed)")
                }

                try await selectExact(version: newerOrSame)
            }
        }
    }
}

extension Xcode {
    public func select(_ version: String) async throws {
        try await run(Select(version))
    }

    public func select(from version: String) async throws {
        try await run(Select(from: version))
    }
}

public enum XcodeVersionError: Error {
    case invalidVersionString(String)
}

/// A simple, extremely naive semantic version.
private struct Version: Equatable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    enum TrimOptions: Hashable {
        case minor
        case patch
    }

    var fullVersionString: String {
        "\(major).\(minor).\(patch)"
    }

    func versionString(trimmingZeroes options: Set<TrimOptions> = [.patch]) -> String {
        var string = "\(major)"
        
        if minor > 0 || !options.contains(.minor) {
            string.append(".\(minor)")
        }

        if patch > 0 || !options.contains(.patch) {
            string.append(".\(patch)")
        }

        return string
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(_ string: String) throws {
        let components = string.components(separatedBy: ".")
        var ints = components.compactMap(Int.init).filter { $0 >= 0 }

        guard components.count == ints.count else {
            throw XcodeVersionError.invalidVersionString(string)
        }

        switch ints.count {
        case 3:
            major = ints[0]
            minor = ints[1]
            patch = ints[2]

        case 2:
            major = ints[0]
            minor = ints[1]
            patch = 0

        case 1:
            major = ints[0]
            minor = 0
            patch = 0

        default:
            throw XcodeVersionError.invalidVersionString(string)
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major < rhs.major {
            return true
        } else if lhs.minor < rhs.minor {
            return true
        } else {
            return lhs.patch < lhs.patch
        }
    }
}
