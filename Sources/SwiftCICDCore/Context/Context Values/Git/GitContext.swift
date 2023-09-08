public enum GitContext: ContextAware {}

public extension ContextValues {
    var git: GitContext.Type {
        GitContext.self
    }
}

public extension GitContext {
    static var latestCommitSHA: String? {
        get async throws {
            try await context.shell("git rev-parse HEAD")
        }
    }

    static var headCommit: Commit? {
        get async throws {
            try await getCommit("HEAD")
        }
    }

    static func getCommit(_ sha: String) async throws -> Commit? {
        let output = try await context.shell("git show \(sha) -q")
        return Commit(output)
    }
}

public extension GitContext {
    struct Commit {
        public let sha: String
        public let message: String
        public let author: String

        init(sha: String, message: String, author: String) {
            self.sha = sha
            self.message = message
            self.author = author
        }

        init?(_ output: String) {
            // commit xxxxx (HEAD -> xxx, xxx/xxx)
            // Author: First Last <email>
            // Date: xxx
            //
            //      message

            let lines = output.components(separatedBy: "\n")

            guard lines.count >= 5 else {
                return nil
            }

            let commitLine = lines[0]
            let authorLine = lines[1]
            // let dateLine = lines[2]
            // let blankLine = lines[3]
            let messageLines = lines[4...]

            guard commitLine.hasPrefix("commit ") else { return nil }
            let commitComponents = commitLine.components(separatedBy: " ")
            self.sha = commitComponents[1]

            guard authorLine.hasPrefix("Author: ") else { return nil }
            self.author = String(authorLine.dropFirst(" Author: ".count))

            self.message = messageLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        }
    }
}
