import Foundation

public struct SaveFile: Step {
    @StepState var savedFilePath: String?

    let fileName: String
    let contents: Data
    var parentDirectoryPath: String?

    public init(name: String, contents: Data, parentDirectoryPath: String? = nil) {
        self.fileName = name
        self.contents = contents
        self.parentDirectoryPath = parentDirectoryPath
    }

    public init(name: String, contents: String, parentDirectoryPath: String? = nil) {
        self.init(name: name, contents: Data(contents.utf8), parentDirectoryPath: parentDirectoryPath)
    }

    public struct Output {
        public let filePath: String
    }

    public func run() async throws -> Output {
        let filePath = (parentDirectoryPath ?? context.temporaryDirectory)/fileName
        self.savedFilePath = filePath
        guard context.fileManager.createFile(atPath: filePath, contents: contents) else {
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
    func saveFile(name: String, contents: Data, into parentDirectoryPath: String? = nil) async throws -> SaveFile.Output {
        try await step(SaveFile(name: name, contents: contents, parentDirectoryPath: parentDirectoryPath))
    }

    func saveFile(name: String, contents: String, into parentDirectoryPath: String? = nil) async throws -> SaveFile.Output {
        try await step(SaveFile(name: name, contents: contents, parentDirectoryPath: parentDirectoryPath))
    }
}
