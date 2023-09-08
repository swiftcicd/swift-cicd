import SwiftCICDCore

/// Namespace for Git actions.
public struct Git: ActionNamespace {
    public let caller: any Action
}

public extension Action {
    var git: Git { Git(caller: self) }
}

public extension Git {
    var latestCommitSHA: String? {
        get async throws {
            try await context.shell("git rev-parse HEAD")
        }
    }

    struct CommitObject {
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

            var commitLine = lines[0]
            var authorLine = lines[1]
//            var dateLine = lines[2]
//            var blankLine = lines[3]
            var messageLines = lines[4...]

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

    var headCommit: CommitObject? {
        get async throws {
            try await getCommit("HEAD")
        }
    }

    func getCommit(_ sha: String) async throws -> CommitObject? {
        let output = try await context.shell("git show \(sha) -q")
        return CommitObject(output)
    }
}
