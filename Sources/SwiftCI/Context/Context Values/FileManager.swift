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
