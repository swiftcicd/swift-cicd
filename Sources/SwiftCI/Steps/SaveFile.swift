import Foundation

public struct SaveFile: Step {
    @StepState var savedFilePath: String?

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
        let filePath = (parentDirectoryPath ?? context.temporaryDirectory)/fileName
        self.savedFilePath = filePath
        guard context.fileManager.createFile(atPath: filePath, contents: contents, attributes: attributes) else {
            throw StepError("Failed to save temporary file \(filePath)")
        }
        return Output(filePath: filePath)
    }

    public func cleanUp(error: Error?) async throws {
        if let savedFilePath {
            try context.fileManager.removeItem(atPath: savedFilePath)
        }
    }
}

public extension StepRunner {
    func saveFile(name: String, contents: Data, attributes: [FileAttributeKey: Any]? = nil, into parentDirectoryPath: String? = nil) async throws -> SaveFile.Output {
        try await step(SaveFile(name: name, contents: contents, attributes: attributes, parentDirectoryPath: parentDirectoryPath))
    }

    func saveFile(name: String, contents: String, attributes: [FileAttributeKey: Any]? = nil, into parentDirectoryPath: String? = nil) async throws -> SaveFile.Output {
        try await step(SaveFile(name: name, contents: contents, attributes: attributes, parentDirectoryPath: parentDirectoryPath))
    }
}
