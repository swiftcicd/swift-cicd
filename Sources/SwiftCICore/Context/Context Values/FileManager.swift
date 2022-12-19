import Foundation

// From FileManager's documentation: https://developer.apple.com/documentation/foundation/filemanager :
// The methods of the shared FileManager object can be called from multiple threads safely. However, if you use a delegate to receive notifications about the status of move, copy,
// remove, and link operations, you should create a unique instance of the file manager object, assign your delegate to that object, and use that file manager to initiate your operations.
//
// That said — I'm not sure if the properties on FileManager are thread safe. I expect that FileMananger will eventually be made Sendable, or its replacement will.
extension FileManager: @unchecked Sendable {}

extension ContextValues {
    private enum FileManagerKey: ContextKey {
        static let defaultValue = FileManager.default
    }

    public var fileManager: FileManager {
        get { self[FileManagerKey.self] }
        set { self[FileManagerKey.self] = newValue }
    }
}

public struct FileManagerError: LocalizedError {
    let message: String

    public var errorDescription: String? {
        message
    }
}

public extension FileManager {
    func changeCurrentDirectory(_ path: String) throws {
        guard changeCurrentDirectoryPath(path) else {
            throw FileManagerError(message: "Failed to change current directory to \(path)")
        }
    }

    func contents(at path: String) throws -> Data {
        guard let contents = contents(atPath: path) else {
            throw FileManagerError(message: "Failed to read contents at \(path)")
        }
        return contents
    }
}

public extension String {
    static func / (lhs: String, rhs: String) -> String {
        if lhs.hasSuffix("/") {
            return lhs + rhs
        } else {
            return "\(lhs)/\(rhs)"
        }
    }
}
