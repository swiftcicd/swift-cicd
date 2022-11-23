import Foundation

public struct Commit: Step {
    public let name = "git commit"

    let flags: [String]
    let message: String
    var author: String?
    var userName: String?
    var userEmail: String?
    let pushChanges: Bool

    public init(flags: [String], message: String, author: String? = nil, userName: String? = nil, userEmail: String? = nil, pushChanges: Bool = true) {
        self.message = message
        self.flags = flags.filter { $0 != "m" }
        self.author = author
        self.userName = userName
        self.userEmail = userEmail
        self.pushChanges = pushChanges
    }

    // TODO: Output should be a list of changes, and a flag "changes detected?"

    public func run() async throws {
        let actor = try context.environment.github.$actor.require()
        let userName = userName ?? "github-actions[bot]"
        // The default value is the email address of the GitHub actions bot: https://github.com/orgs/community/discussions/26560#discussioncomment-3252339
        let userEmail = userEmail ?? "41898282+github-actions[bot]@users.noreply.github.com"
        let author = author ?? "\(actor) <\(actor)@users.noreply.github.com>"
        try context.shell("git", "config", "--local", "user.name", userName)
        try context.shell("git", "config", "--local", "user.email", userEmail)

        var commit = Command("git", "commit", "-m", message, "--author=\(author)")

        if !flags.isEmpty {
            commit.add("-\(flags.joined())")
        }

        try context.shell(commit)

        if pushChanges {
            let branch = try context.shell("git", "branch", "--show-current")
            try context.shell("git", "push", "--set-upstream", "origin", "HEAD:\(branch)")
        }
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
    func commit(flags: [String] = [], message: String) async throws {
        try await step(Commit(flags: flags, message: message))
    }

    func commitTrackedChanges(message: String, flags: [String] = []) async throws {
        try await step(Commit(flags: ["a"] + flags, message: message))
    }

    func commitAllChanges(message: String, flags: [String] = []) async throws {
        try context.shell("git", "add", "-A")
        return try await commit(flags: flags, message: message)
    }

    func commit(files: String..., message: String, flags: [String] = []) async throws {
        for file in files {
            try context.shell("git", "add", file)
        }

        try await commit(flags: flags, message: message)
    }

    func commit(message: String, flags: [String] = [], filesMatching predicate: @escaping (String) -> Bool) async throws {
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

        try await commit(flags: flags, message: message)
    }

    func commitLocalizedFiles(message: String) async throws {
        try await commit(message: message, filesMatching: { file in
            [".strings", ".xliff", ".xcloc", ".lproj"].contains { file.hasSuffix($0) }
        })
    }
}
