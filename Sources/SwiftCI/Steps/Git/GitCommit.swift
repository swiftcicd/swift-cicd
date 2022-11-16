import Foundation

extension GitStep {
    public struct Commit: Step {
        public let name = "Git Commit"

        let message: String
        let flags: [String]

        public init(message: String, flags: [String]) {
            self.message = message
            self.flags = flags.filter { $0 != "m" }
        }

        // TODO: Output should be a list of changes, and a flag "changes detected?"

        public func run() async throws -> String {
            try context.shell("git", "commit", "-\(flags.joined())", "-m", message)
        }
    }
}

public extension Step where Self == GitStep.Commit {
    static func commit(message: String, flags: [String] = []) -> GitStep.Commit {
        GitStep.Commit(message: message, flags: flags)
    }

    static func commitTrackedChanges(message: String, flags: [String] = []) -> GitStep.Commit {
        GitStep.Commit(message: message, flags: ["a"] + flags)
    }

    static func commitAllChanges(message: String, flags: [String] = []) throws -> GitStep.Commit {
        try context.shell("git", "add", "-A")
        return GitStep.Commit(message: message, flags: flags)
    }

    static func commit(files: String..., message: String, flags: [String] = []) throws -> GitStep.Commit {
        for file in files {
            try context.shell("git", "add", file)
        }

        return GitStep.Commit(message: message, flags: flags)
    }

    static func commit(message: String, flags: [String] = [], filesMatching predicate: @escaping (String) -> Bool) throws -> GitStep.Commit {
        let status = try context.shell("git", "status", "--short")
        let files = status
            .components(separatedBy: "\n")
            .compactMap(GitStep.Commit.File.init(line:))
            .filter { predicate($0.path) }

        for file in files {
            if file.status.contains(.deleted) {
                try context.shell("git", "rm", file.path)
            } else {
                try context.shell("git", "add", file.path)
            }
        }

        return GitStep.Commit(message: message, flags: flags)
    }
}

extension GitStep.Commit {
    struct File {
        let path: String
        let status: Set<GitFileStatus>

        init(path: String, status: Set<GitFileStatus>) {
            self.path = path
            self.status = status
        }

        init?(line: String) {
            guard let delimeter = line.firstIndex(of: " ") else {
                return nil
            }

            let prefix = line[..<delimeter]
            var _status = Set<GitFileStatus>()
            for status in GitFileStatus.allCases {
                if prefix.contains(status.prefix) {
                    _status.insert(status)
                }
            }

            guard !_status.isEmpty else {
                return nil
            }
            self.status = _status

            let path = line[delimeter...]
            self.path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }

    enum GitFileStatus: CaseIterable {
        case added
        case deleted
        case modified
        case untracked

        var prefix: String {
            switch self {
            case .added: return "A"
            case .modified: return "M"
            case .deleted: return "D"
            case .untracked: return "??"
            }
        }
    }
}

//#if canImport(RegexBuilder)
//import RegexBuilder
//
//@available(macOS 13.0, *)
//public extension Step where Self == GitStep.Commit {
//    static func commit(filesMatching regex: Regex<Substring>, message: String, flags: [String] = []) -> GitStep.Commit {
//        fatalError("Unimplemented")
//    }
//
//    static func commit(message: String, flags: [String] = [], @RegexComponentBuilder filesMatching regex: () -> some RegexComponent) -> GitStep.Commit {
//        fatalError("Unimplemented")
//    }
//}
//#endif
