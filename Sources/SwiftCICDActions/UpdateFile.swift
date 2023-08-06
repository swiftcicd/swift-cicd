import Foundation
import SwiftCICDCore

public struct UpdateFile: Action {
    @Value var previousFileContents: Data?

    let filePath: String
    let createFile: Bool
    let update: (inout Data) -> Void

    public init(_ filePath: String, createFile: Bool = true, update: @escaping (inout Data) -> Void) {
        self.filePath = filePath
        self.createFile = createFile
        self.update = update
    }

    public init(_ filePath: String, createFile: Bool = true, update: @escaping (inout String) -> Void) {
        self.filePath = filePath
        self.createFile = createFile
        self.update = { data in
            var string = data.string
            update(&string)
            data = string.data
        }
    }

    public func run() async throws {
        var contents = Data()

        if let fileContents = context.fileManager.contents(atPath: filePath) {
            contents = fileContents
        } else if createFile {
            context.fileManager.createFile(atPath: filePath, contents: nil)
        } else {
            throw ActionError("Failed to read contents of \(filePath)")
        }

        previousFileContents = contents
        update(&contents)

        guard context.fileManager.createFile(atPath: filePath, contents: contents) else {
            throw ActionError("Failed to update file \(filePath)")
        }
    }

    public func cleanUp(error: Error?) async throws {
        if createFile {
            try context.fileManager.removeItem(atPath: filePath)
            logger.debug("Deleted \(filePath)")
        } else if let previousFileContents {
            context.fileManager.createFile(atPath: filePath, contents: previousFileContents)
            logger.debug("Restored \(filePath) to its previous state")
        }
    }
}

public extension Action {
    func updateFile(_ filePath: String, createFile: Bool = true, update: @escaping (inout Data) -> Void) async throws {
        try await run(UpdateFile(filePath, createFile: createFile, update: update))
    }

    func updateFile(_ filePath: String, createFile: Bool = true, update: @escaping (inout String) -> Void) async throws {
        try await run(UpdateFile(filePath, createFile: createFile, update: update))
    }
}
