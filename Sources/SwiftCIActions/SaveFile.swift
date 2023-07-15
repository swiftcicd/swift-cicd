import Foundation
import SwiftCICore

public struct SaveFile: Action {
    @State var savedFilePath: String?

    let fileName: String
    let contents: Data
    var attributes: [FileAttributeKey: Any]?
    var parentDirectoryPath: String?

    public init(name: String, contents: Data, attributes: [FileAttributeKey: Any]?, parentDirectoryPath: String? = nil) {
        self.fileName = name
        self.contents = contents
        self.attributes = attributes
        self.parentDirectoryPath = parentDirectoryPath
    }

    public init(name: String, contents: String, attributes: [FileAttributeKey: Any]? = nil, parentDirectoryPath: String? = nil) {
        self.init(name: name, contents: contents.data, attributes: attributes, parentDirectoryPath: parentDirectoryPath)
    }

    public struct Output {
        public let filePath: String
    }

    public func run() async throws -> Output {
        let filePath = (parentDirectoryPath ?? context.fileManager.temporaryDirectory.path)/fileName
        self.savedFilePath = filePath
        guard context.fileManager.createFile(atPath: filePath, contents: contents, attributes: attributes) else {
            throw ActionError("Failed to save temporary file \(filePath)")
        }
        return Output(filePath: filePath)
    }

    public func tearDown(error: Error?) async throws {
        if let savedFilePath {
            try context.fileManager.removeItem(atPath: savedFilePath)
        }
    }
}

public extension Action {
    func saveFile(name: String, contents: Data, attributes: [FileAttributeKey: Any]? = nil, into parentDirectoryPath: String? = nil) async throws -> SaveFile.Output {
        try await action(SaveFile(name: name, contents: contents, attributes: attributes, parentDirectoryPath: parentDirectoryPath))
    }

    func saveFile(name: String, contents: String, attributes: [FileAttributeKey: Any]? = nil, into parentDirectoryPath: String? = nil) async throws -> SaveFile.Output {
        try await action(SaveFile(name: name, contents: contents, attributes: attributes, parentDirectoryPath: parentDirectoryPath))
    }
}
