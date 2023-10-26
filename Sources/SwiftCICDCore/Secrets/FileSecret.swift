import Foundation

public struct FileSecret: Secret {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    public init(url: URL) {
        self.init(path: url.filePath)
    }

    public func get() async throws -> Data {
        try context.fileManager.contents(at: path)
    }
}

public extension Secret where Self == FileSecret {
    static func file(path: String) -> FileSecret {
        FileSecret(path: path)
    }

    static func file(url: URL) -> FileSecret {
        FileSecret(url: url)
    }
}
