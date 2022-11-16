import Foundation

public struct LoadEnvironmentFile: Step {
    public struct Output {
        public let loadedFile: String
    }

    let environmentKey: String
    let loadedFileName: String

    struct StepError: Error {
        let message: String
    }

    public func run() async throws -> Output {
        guard let fileBase64Encoded = context.environment[environmentKey] else {
            throw StepError(message: "Missing environment file: \(environmentKey)")
        }

//        guard let fileData = Data(base64Encoded: fileBase64Encoded.normalizedBase64Encoding, options: .ignoreUnknownCharacters) else {
        guard let fileData = Data(base64Encoded: fileBase64Encoded, options: .ignoreUnknownCharacters) else {
            throw StepError(message: "Failed to base64 decode file")
        }

        let loadedFile = context.temporaryDirectory + "/\(loadedFileName)"
        guard context.fileManager.createFile(atPath: loadedFile, contents: fileData) else {
            throw StepError(message: "Failed to create file \(loadedFile)")
        }

        return Output(loadedFile: loadedFile)
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
