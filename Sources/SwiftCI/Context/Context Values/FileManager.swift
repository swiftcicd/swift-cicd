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

public extension String {
    static func / (lhs: String, rhs: String) -> String {
        if lhs.hasSuffix("/") {
            return lhs + rhs
        } else {
            return "\(lhs)/\(rhs)"
        }
    }

    var pathComponents: [String] {
        self.components(separatedBy: "/")
    }

    var removingLastPathComponent: String {
        pathComponents.dropLast().joined(separator: "/") + "/"
    }

    var lastPathComponent: String? {
        pathComponents.last
    }
}

public extension FileManager {
    enum FileManagerError: Error {
        case changeCurrentDirectoryFailed(path: String)
    }

    func changeCurrentDirectory(_ path: String) throws {
        guard currentDirectoryPath != path else { return }
        guard changeCurrentDirectoryPath(path) else {
            throw FileManagerError.changeCurrentDirectoryFailed(path: path)
        }
    }
}
