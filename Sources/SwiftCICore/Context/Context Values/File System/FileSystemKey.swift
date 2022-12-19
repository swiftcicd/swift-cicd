enum FileSystemKey: ContextKey {
    static var defaultValue: FileSystem = LocalFileSystem.shared
}

public extension ContextValues {
    var fileSystem: FileSystem {
        get { self[FileSystemKey.self] }
        set { self[FileSystemKey.self] = newValue }
    }
}

public extension FileSystem {
    func requireCurrentWorkingDirectory(file: StaticString = #fileID, line: UInt = #line) throws -> AbsolutePath {
        guard let currentWorkingDirectory else {
            throw ActionError("FileSystem.currentWorkingDirectory was required, but nil.", file: file, line: line)
        }

        return currentWorkingDirectory
    }
}

//@preconcurrency import Foundation

//protocol FileSystem {
//    func changeCurrentDirectory(to directoryPath: String) throws
//}
//
//extension FileManager: ContextKey {
//    public static let defaultValue = FileManager.default
//}
//
//public extension ContextValues {
//    var fileManager: FileManager {
//        // FIXME: Resolve warnings
//        get { self[FileManager.self] }
//        set { self[FileManager.self] = newValue }
//    }
//}
//
//public extension ContextValues {
//    var temporaryDirectory: String {
//        let directory: String
//
//        if let runnerTemp = environment.github.runnerTemp {
//            directory = runnerTemp
//        } else {
//            directory = fileManager.temporaryDirectory.path
//        }
//
//        if directory.hasSuffix("/") {
//            return directory
//        } else {
//            return directory + "/"
//        }
//    }
//}
//
//public extension String {
//    static func / (lhs: String, rhs: String) -> String {
//        if lhs.hasSuffix("/") {
//            return lhs + rhs
//        } else {
//            return "\(lhs)/\(rhs)"
//        }
//    }
//
//    var pathComponents: [String] {
//        self.components(separatedBy: "/")
//    }
//
//    var removingLastPathComponent: String {
//        pathComponents.dropLast().joined(separator: "/") + "/"
//    }
//
//    var lastPathComponent: String? {
//        pathComponents.last
//    }
//}

//public extension FileManager {
//    func changeCurrentDirectory(to path: String) throws {
//        guard currentDirectoryPath != path else { return }
//        guard changeCurrentDirectoryPath(path) else {
//            throw StepError("Failed to change current directory to \(path)")
//        }
//    }
//}
