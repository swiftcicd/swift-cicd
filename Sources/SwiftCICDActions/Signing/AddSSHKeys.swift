import Crypto
import Foundation
import SwiftCICDCore

// Reference: https://github.com/webfactory/ssh-agent/blob/209e2d72ff4a448964d26610aceaaf1b3f8764c6/index.js

extension Signing {
    public struct AddSSHKeys: Action {
        var sshPrivateKeys: [Secret]
        var sshAuthSocket: String?
        var shouldLogPublicKey: Bool = true

        @Value var createdFiles = [String]()
        @Value var addedSections = [String]()
        @Value var sshAgentPID: String?
        @Value var sshAgentAuthSocket: String?

        var ssh: String {
            context.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".ssh").path
        }

        var knownHosts: String {
            ssh/"known_hosts"
        }

        var sshConfig: String {
            ssh/"config"
        }

        init(sshPrivateKeys: [Secret], sshAuthSocket: String? = nil, shouldLogPublicKey: Bool = true) {
            self.sshPrivateKeys = sshPrivateKeys
            self.sshAuthSocket = sshAuthSocket
            self.shouldLogPublicKey = shouldLogPublicKey
        }

        public init(_ sshKeys: [Secret]) {
            self.init(sshPrivateKeys: sshKeys)
        }

        public func run() async throws {
            logger.info("Adding \(sshPrivateKeys.count) key(s) to \(ssh)/known_hosts")

            try context.fileManager.createDirectory(atPath: ssh, withIntermediateDirectories: true)

            // TODO: Make this platform-agnostic. A platform should be able to supply its own knownHosts.

            // These are the known hosts for GitHub
            try await updateFile(knownHosts) { $0 += """
                github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
                github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
                github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==

                """
            }

            logger.info("Starting ssh-agent")

            var sshAgent = ShellCommand("ssh-agent")
            sshAgent.append("-a ", ifLet: sshAuthSocket)
            let sshAgentOutput = try await shell(sshAgent)

            for line in sshAgentOutput.components(separatedBy: "\n") {
                let key: String
                let value: String

    //            if #available(macOS 13.0, *) {
    //                guard let match = line.wholeMatch(of: #/^(SSH_AUTH_SOCK|SSH_AGENT_PID)=(.*); export \1/#) else {
    //                    continue
    //                }
    //
    //                key = String(match.output.1)
    //                value = String(match.output.2)
    //            }

                guard
                    let equals = line.firstIndex(of: "="),
                    let semicolon = line.firstIndex(of: ";"),
                    line.contains("; export ")
                else {
                    continue
                }

                key = String(line[line.startIndex..<equals])
                value = String(line[line.index(after: equals)..<semicolon])

                switch key {
                case "SSH_AGENT_PID":
                    sshAgentPID = value
                case "SSH_AUTH_SOCK":
                    sshAgentAuthSocket = value
                default:
                    continue
                }
            }

            logger.info("Adding private key(s) to agent")

            for sshPrivateKey in sshPrivateKeys {
                let key = try await sshPrivateKey.get().string
                try await shell("ssh-add - <<< \(key, escapingWith: .singleQuotes)")
            }

            let keys = try await shell("ssh-add -l", quiet: true)
            logger.info("Key(s) added:\n\(keys)")

            logger.info("Configuring deployment key(s)")

            let publicKeys = try await shell("ssh-add -L", quiet: true).components(separatedBy: "\n")
            for publicKey in publicKeys {

                // TODO: Make this platform-agnostic. A platform should be able to parse and convert an https://, ssh://, or git@ url of a git repository.

                var ownerAndRepo: String?
    //            if #available(macOS 13.0, *) {
    //                let match = publicKey.lowercased().firstMatch(of: #/\bgithub\.com[:/]([_.a-z0-9-]+\/[_.a-z0-9-]+)/#)
    //                ownerAndRepo = match.map { String($0.output.1) }
    //            } else {
                if let github = (publicKey.lowercased().range(of: "github.com/") ?? publicKey.lowercased().range(of: "github.com:")),
                   publicKey.rangeOfCharacter(from: CharacterSet(charactersIn: "/"), range: github.upperBound..<publicKey.endIndex) != nil {
                    ownerAndRepo = String(publicKey[github.upperBound...])
                }
    //            }

                guard var ownerAndRepo else {
                    if shouldLogPublicKey {
                        logger.info("Comment for (public) key \(publicKey) does not match GitHub URL pattern. Not treating it as a GitHub deploy key.")
                    }
                    continue
                }

                ownerAndRepo = ownerAndRepo.replacingOccurrences(of: ".git", with: "")

                // Save public key
                // TODO: We don't actually have to use the sha hash here. It's just for unique file names.
                let sha256 = CryptoKit.SHA256.hash(data: publicKey.data)
                let sha = sha256.sha
                let keyName = "key-\(sha).pub"
                let keyFilePath = ssh/keyName
                let keyFileContents = (publicKey + "\n").data

                guard context.fileManager.createFile(atPath: keyFilePath, contents: keyFileContents, attributes: [.posixPermissions: 420]) else {
                    throw ActionError("Failed to create ssh key file \(keyFilePath)")
                }

                createdFiles.append(keyFilePath)

                // Tell git to use the ssh key to authenticate with the repo by replacing any instances of:
                // https://github.com/ower/repo, git@github.com:owner/repo, ssh://github.com/owner/repo
                // with: git@key-hash.pub.github.com:owner/repo
                let section = "url.\"git@\(keyName).github.com:\(ownerAndRepo)\""
                let sectionInsteadOf = "\(section).insteadOf"
                try await shell("git config --global --replace-all \(sectionInsteadOf) https://github.com/\(ownerAndRepo)")
                try await shell("git config --global --add \(sectionInsteadOf) git@github.com:\(ownerAndRepo)")
                try await shell("git config --global --add \(sectionInsteadOf) ssh://github.com/\(ownerAndRepo)")
                addedSections.append(section)

                try await updateFile(sshConfig) {
                    if !$0.hasSuffix("\n") { $0 += "\n" }

                    // TODO: Make this platform-agnostic. A platform should be able to supply its own host, host name..

                    $0 += """
                    Host \(keyName).github.com
                        HostName github.com
                        IdentityFile \(keyFilePath)
                        IdentitiesOnly yes

                    """
                }

                logger.info("Added deploy-key mapping: Use identity \(keyFilePath) for GitHub repository \(ownerAndRepo)")
            }
        }

        public func cleanUp(error: Error?) async throws {
            for file in createdFiles {
                try context.fileManager.removeItemIfItExists(atPath: file)
            }

            for section in addedSections {
                try await shell("git config --global --remove-section \(section)")
            }

            var command = ShellCommand("env")
            command.append("SSH_AGENT_PID", "=", ifLet: sshAgentPID)
            command.append("SSH_AUTH_SOCK", "=", ifLet: sshAgentAuthSocket)
            command.append("ssh-agent -k")
            try await shell(command)
        }

        func setenv(_ key: String, _ value: String) {
            _ = withUnsafePointer(to: Array(key.utf8CString)) { keyPointer in
                withUnsafePointer(to: Array(value.utf8CString)) { valuePointer in
                    logger.debug("setenv(\(key), \(value))")
                    return Darwin.setenv(keyPointer, valuePointer, 1)
                }
            }
        }
    }
}

extension SHA256Digest {
    var sha: String {
        compactMap { String(format: "%02x", $0) }.joined()
    }
}

public extension Signing {
    func addSSHKeys(_ sshKeys: [Secret]) async throws {
        try await run(AddSSHKeys(sshPrivateKeys: sshKeys))
    }
}
