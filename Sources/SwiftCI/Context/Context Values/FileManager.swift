import Foundation

extension FileManager: ContextKey {
    public static let defaultValue = FileManager.default
}

public extension ContextValues {
    var fileManager: FileManager {
        get { self[FileManager.self] }
        set { self[FileManager.self] = newValue }
    }
}

public extension ContextValues {
    var temporaryDirectory: String {
        let directory: String

        if let runnerTemp = environment.github.runnerTemp {
            directory = runnerTemp
        } else {
            directory = fileManager.temporaryDirectory.path
        }

        if directory.hasSuffix("/") {
            return directory
        } else {
            return directory + "/"
        }
    }
}

public extension FileManager {
    enum FileManagerError: Error {
        case changeCurrentDirectoryFailed(path: String)
    }

    func changeCurrentDirectory(_ path: String) throws {
        guard changeCurrentDirectoryPath(path) else {
            throw FileManagerError.changeCurrentDirectoryFailed(path: path)
        }
    }
}
