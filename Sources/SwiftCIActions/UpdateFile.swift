import Foundation
import SwiftCICore

public struct UpdateFile: Action {
    @State var previousFileContents: Data?

    let filePath: String
    let update: (inout Data) -> Void

    public init(filePath: String, update: @escaping (inout Data) -> Void) {
        self.filePath = filePath
        self.update = update
    }

    public init(filePath: String, update: @escaping (inout String) -> Void) {
        self.filePath = filePath
        self.update = { data in
            var string = data.string
            update(&string)
            data = string.data
        }
    }

    public func run() async throws {
        guard var contents = context.fileManager.contents(atPath: filePath) else {
            throw ActionError("Failed to read contents of \(filePath)")
        }

        previousFileContents = contents
        update(&contents)

        guard context.fileManager.createFile(atPath: filePath, contents: contents) else {
            throw ActionError("Failed to update file \(filePath)")
        }
    }

    public func cleanUp(error: Error?) async throws {
        guard let previousFileContents,
              context.fileManager.createFile(atPath: filePath, contents: previousFileContents) else {
            throw ActionError("Failed to restore file \(filePath)")
        }
        logger.debug("Restored \(filePath) to its previous state")
        logger.trace("\(previousFileContents.string))")
    }
}

public extension Action {
    func updateFile(_ filePath: String, _ update: @escaping (inout Data) -> Void) async throws {
        try await action(UpdateFile(filePath: filePath, update: update))
    }

    func updateFile(_ filePath: String, _ update: @escaping (inout String) -> Void) async throws {
        try await action(UpdateFile(filePath: filePath, update: update))
    }
}
