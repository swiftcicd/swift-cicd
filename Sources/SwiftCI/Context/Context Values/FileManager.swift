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
        if let runnerTemp = environment.github.runnerTemp {
            return runnerTemp
        } else {
            return fileManager.temporaryDirectory.path
        }
    }
}
