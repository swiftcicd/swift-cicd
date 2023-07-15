import Logging
import SwiftCI

@main
struct Demo: MainAction {
    static let logLevel = Logger.Level.debug

//    func before() async throws {
//        logger.info("Running before")
////        struct Cancel: Error {}
////        throw Cancel()
//    }

    func run() async throws {
//        logger.debug("Hello!")
//        logger.info("Wow!")
//        try await action(First())
//        try await action(Second())
//
//        let name = "Clay Ellis"
//        let greeting = "Hello there!"
//        var command: ShellCommand = "echo \(greeting)"
//        command.append("\(name, escapingWith: .doubleQuotes)")
//        let output = try context.shell(command)
//        logger.info("Output: \(output)")

        let secret = try await get1PasswordSecret(
            address: "https://lumiohx.1password.com/",
            email: "clay.ellis@lumio.com",
            secretKey: "A3-ANTD54-3Q5P7N-3K7F3-A6HTB-SX534-X5Z7T",
            password: "rememberdeath",
            reference: "op://Mobile - iOS/Cognito Client Secret/rot3xbt5m3ttlp5rrlcgyf6e6e"
        )

        logger.info("Got 1Password secret:\n\(secret)")
    }
}

struct First: Action {
    func run() async throws {

    }
}

struct Second: Action {
    func run() async throws {
        try await action(Nested())
    }
}

struct Nested: Action {
    func run() async throws {
//        throw ActionError("throwing from second")
    }
}
