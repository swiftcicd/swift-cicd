import Foundation

public struct Commit: Step {
    public let name = "git commit"

    let flags: [String]
    let message: String
    var authorName: String?
    var authorEmail: String?

    public init(flags: [String], message: String, authorName: String? = nil, authorEmail: String? = nil) {
        self.message = message
        self.flags = flags.filter { $0 != "m" }
        self.authorName = authorName
        self.authorEmail = authorEmail
    }

    // TODO: Output should be a list of changes, and a flag "changes detected?"

    public func run() async throws -> String {

        // TODO: Auto-detect user name/email from GITHUB_ACTOR and event contents (sender object)

        if let authorName {
            try context.shell("git", "config", "--local", "user.name", authorName)
        }

        if let authorEmail {
            try context.shell("git", "config", "--local", "user.email", authorEmail)
        }

        var commit = Command("git", "commit", "-m", message)

        if !flags.isEmpty {
            commit.add("-\(flags.joined())")
        }

        return try context.shell(commit)
    }
}

extension Commit {
    struct File {
        let path: String
        let status: Set<FileStatus>

        init(path: String, status: Set<FileStatus>) {
            self.path = path
            self.status = status
        }

        init?(line: String) {
            guard let delimeter = line.firstIndex(of: " ") else {
                return nil
            }

            let prefix = line[..<delimeter]
            var _status = Set<FileStatus>()
            for status in FileStatus.allCases {
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

    enum FileStatus: CaseIterable {
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

public extension StepRunner {
    @discardableResult
    func commit(flags: [String] = [], message: String) async throws -> String {
        try await step(Commit(flags: flags, message: message))
    }

    @discardableResult
    func commitTrackedChanges(message: String, flags: [String] = []) async throws -> String {
        try await step(Commit(flags: ["a"] + flags, message: message))
    }

    @discardableResult
    func commitAllChanges(message: String, flags: [String] = []) async throws -> String {
        try context.shell("git", "add", "-A")
        return try await commit(flags: flags, message: message)
    }

    @discardableResult
    func commit(files: String..., message: String, flags: [String] = []) async throws -> String {
        for file in files {
            try context.shell("git", "add", file)
        }

        return try await commit(flags: flags, message: message)
    }

    @discardableResult
    func commit(message: String, flags: [String] = [], filesMatching predicate: @escaping (String) -> Bool) async throws -> String {
        let status = try context.shell("git", "status", "--short")
        let files = status
            .components(separatedBy: "\n")
            .compactMap(Commit.File.init(line:))
            .filter { predicate($0.path) }

        for file in files {
            if file.status.contains(.deleted) {
                try context.shell("git", "rm", file.path)
            } else {
                try context.shell("git", "add", file.path)
            }
        }

        return try await commit(flags: flags, message: message)
    }

    func commitLocalizedFiles(message: String, pushChanges: Bool) async throws {
        try await commit(message: message, filesMatching: { file in
            [".strings", ".xliff", ".xcloc", ".lproj"].contains { file.hasSuffix($0) }
        })

        if pushChanges {
            try context.shell("git", "push")
        }
    }
}
