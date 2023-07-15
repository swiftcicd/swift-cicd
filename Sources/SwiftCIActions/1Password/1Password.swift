import Foundation
import SwiftCICore

public struct OnePassword: Action {
    let address: String
    let email: String
    let secretKey: String
    let password: String
    let reference: String

    public init(address: String, email: String, secretKey: String, password: String, reference: String) {
        self.address = address
        self.email = email
        self.secretKey = secretKey
        self.password = password
        self.reference = reference
    }

    let brew = "/opt/homebrew/bin/brew"
    let op = "/usr/local/bin/op"

    var isInstalled: Bool {
        get async {
            do {
                return try await !shell("\(op) --version", log: false, quiet: true).isEmpty
            } catch {
                return false
            }
        }
    }

    func install() async throws {
        try await shell("\(brew) install --cask 1password/tap/1password-cli")
    }

    func uninstall() async throws {
        guard await isInstalled else {
            return
        }

        try await shell("\(brew) uninstall 1password-cli")
    }

    func addAccount() async throws {
        var addAccount = ShellCommand("\(op) account add")
        addAccount.append("--address \(address)")
        addAccount.append("--email \(email)")
        addAccount.append("--secret-key \(secretKey)")
        try await shell(addAccount)
    }

    func signIn() async throws {
        try await shell("eval $(\(op) signin)")
    }

    public func run() async throws -> String {
        if await !isInstalled {
            try await install()
        }

        try await addAccount()
        try await signIn()
        let secret = try await shell("\(op) read \(reference)", quiet: true)
        return secret
    }

    public func tearDown(error: Error?) async throws {
        try await uninstall()
    }
}

public extension Action {
    func get1PasswordSecret(address: String, email: String, secretKey: String, password: String, reference: String) async throws -> String {
        try await action(OnePassword(address: address, email: email, secretKey: secretKey, password: password, reference: reference))
    }
}

public struct OnePasswordSecret: Secret {


    public func get() async throws -> Data {
        // This secret needs to install the 1password-cli in order for it to be accessed. But that means that it also needs to be cleaned up.
        // This secret could be run several times though, so it wouldn't make sense to install and uninstall the cli each time that `get` is run.
        // This means there needs to be some sort of lifecycle for secrets, or for the tools that they access.
        // Ideas:
        // - Make a SecretAction hybrid (since Actions already have a lifecycle)
        // - Make a `Tool` protocol — (static func install, static func uninstall, installed/uninstalled by MainAction, accessed via `context.tools`)
        // -

        return Data()
    }
}
