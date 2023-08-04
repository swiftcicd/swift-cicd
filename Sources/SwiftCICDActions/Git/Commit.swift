import Foundation
import SwiftCICDCore

// Reference: https://github.com/stefanzweifel/git-auto-commit-action/blob/master/entrypoint.sh

extension Git {
    public struct Commit: Action {
        let flags: [String]
        let message: String
        var author: String?
        var userName: String?
        var userEmail: String?
        let pushChanges: Bool

        public init(
            flags: [String],
            message: String,
            author: String? = nil,
            userName: String? = nil,
            userEmail: String? = nil,
            pushChanges: Bool = true
        ) {
            self.message = message
            self.flags = flags.filter { $0 != "m" }
            self.author = author
            self.userName = userName
            self.userEmail = userEmail
            self.pushChanges = pushChanges
        }

        public struct Output {
            public var commitSHA: String?

            public var hadChanges: Bool {
                commitSHA != nil
            }
        }

        public func run() async throws -> Output {
            guard try await !shell("git status -s").isEmpty else {
                return Output(commitSHA: nil)
            }

            // FIXME: Get the headRef in a platform-agnostic way
            let branch = try context.environment.github.$headRef.require()
            try await shell("git fetch --depth=1")
            // TODO: If the branch already exists, just check it out, don't create it (-B)
            try await shell("git checkout \(branch)")

            let actor = try context.environment.github.$actor.require()
            let userName = userName ?? "github-actions[bot]"
            // This is the default value is the email address of the GitHub actions bot.
            // Reference: https://github.com/orgs/community/discussions/26560#discussioncomment-3252339
            let userEmail = userEmail ?? "41898282+github-actions[bot]@users.noreply.github.com"
            let author = author ?? "\(actor) <\(actor)@users.noreply.github.com>"

            var commit = ShellCommand("""
                git \
                -c user.name=\(userName, escapingWith: .singleQuotes, alwaysEscape: true) \
                -c user.email=\(userEmail, escapingWith: .singleQuotes, alwaysEscape: true) \
                commit \
                -m \(message, escapingWith: .doubleQuotes) \
                --author=\(author, escapingWith: .singleQuotes, alwaysEscape: true)
                """
            )

            if !flags.isEmpty {
                commit.append("-\(flags.joined())")
            }

            // FIXME: Make platform-agnostic
            commit.append("--dry-run", if: !context.environment.github.isCI)

            try await shell(commit)

            let sha = try await shell("git rev-parse HEAD")

            if pushChanges {
                var push = ShellCommand("git push --set-upstream origin HEAD:\(branch) --atomic")
                push.append("--dry-run", if: !context.environment.github.isCI)
                try await shell(push)
            }

            return Output(commitSHA: sha)
        }
    }

    public struct CommitLocalizedFiles: Action {
        var message: String?

        public init(message: String? = nil) {
            self.message = message
        }

        public func run() async throws -> Commit.Output {
            try await git.commit(message: message ?? "(Automated) Import/export localizations.", filesMatching: { file in
                [".strings", ".xliff", ".xcloc", ".lproj"].contains { file.hasSuffix($0) }
            })
        }
    }
}

extension Git.Commit {
    struct File {
        let path: String
        let status: Set<FileStatus>

        init(path: String, status: Set<FileStatus>) {
            self.path = path
            self.status = status
        }

        init?(line: String) {
            let line = line.trimmingCharacters(in: .whitespaces)
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
            let path = line[delimeter...].trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\"")))
            self.path = path
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

public extension Git {
    @discardableResult
    func commit(flags: [String] = [], message: String) async throws -> Commit.Output {
        try await run(Commit(flags: flags, message: message))
    }

    @discardableResult
    func commitTrackedChanges(message: String, flags: [String] = []) async throws -> Commit.Output {
        try await run(Commit(flags: ["a"] + flags, message: message))
    }

    @discardableResult
    func commitAllChanges(message: String, flags: [String] = []) async throws -> Commit.Output {
        try await context.shell("git add -A")
        return try await commit(flags: flags, message: message)
    }

    @discardableResult
    func commit(files: String..., message: String, flags: [String] = []) async throws -> Commit.Output {
        for file in files {
            try await context.shell("git add \(file)")
        }

        return try await commit(flags: flags, message: message)
    }

    @discardableResult
    func commit(message: String, flags: [String] = [], filesMatching predicate: @escaping (String) -> Bool) async throws -> Commit.Output {
        context.logger.info("Committing files matching predicate.")

        let status = try await context.shell("git status --short")
        let files = status
            .components(separatedBy: "\n")
            .compactMap(Commit.File.init(line:))

        let filesToCommit = files.filter { predicate($0.path) }

        context.logger.debug("Files with changes:\n\(files)")
        context.logger.debug("Files to commit:\n\(filesToCommit)")

        guard !filesToCommit.isEmpty else {
            context.logger.info("No files to commit.")
            return .init(commitSHA: nil)
        }

        for file in filesToCommit {
            if file.status.contains(.deleted) {
                try await context.shell("git rm --cached \(file.path)")
            } else {
                try await context.shell("git add \(file.path)")
            }
        }

        return try await commit(flags: flags, message: message)
    }

    @discardableResult
    func commitLocalizedFiles(message: String? = nil) async throws -> Commit.Output {
        try await run(CommitLocalizedFiles(message: message))
    }
}
