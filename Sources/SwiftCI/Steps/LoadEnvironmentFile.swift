import Foundation

public struct LoadEnvironmentFile: Step {
    public struct Output {
        public let contents: Data
        public let filePath: String
    }

    let environmentKey: String
    let loadedFileName: String

    @StepState var loadedFilePath: String?

    public func run() async throws -> Output {
        guard let fileBase64Encoded = context.environment[environmentKey] else {
            throw StepError("Missing environment file: \(environmentKey)")
        }

        // TODO: Cascade over regular data and then normalizedBase64Encoding
        // TODO: Extract this logic to a method on Step: extractAndSaveBase64EncodedEnvironmentFile(_ key: String) throws -> (filePath: String)
//        guard let fileData = Data(base64Encoded: fileBase64Encoded.normalizedBase64Encoding, options: .ignoreUnknownCharacters) else {
        guard let fileData = Data(base64Encoded: fileBase64Encoded, options: .ignoreUnknownCharacters) else {
            throw StepError("Failed to base64 decode file")
        }

        let filePath = context.temporaryDirectory/loadedFileName
        loadedFilePath = filePath
        guard context.fileManager.createFile(atPath: filePath, contents: fileData) else {
            throw StepError("Failed to create file \(filePath)")
        }

        return Output(
            contents: fileData,
            filePath: filePath
        )
    }

    public func cleanUp(error: Error?) async throws {
        if let loadedFilePath {
            try context.fileManager.removeItem(atPath: loadedFilePath)
        }
    }
}

public extension Step where Self == LoadEnvironmentFile {
    static func loadFile(fromEnvironmentKey environmentKey: String, as fileName: String) -> LoadEnvironmentFile {
        LoadEnvironmentFile(environmentKey: environmentKey, loadedFileName: fileName)
    }
}

extension String {
    var normalizedBase64Encoding: String {
        let remainder = self.count % 4
        if remainder > 0 {
            return self.padding(
                toLength: self.count + 4 - remainder,
                withPad: "=",
                startingAt: 0
            )
        } else {
            return self
        }
    }
}
