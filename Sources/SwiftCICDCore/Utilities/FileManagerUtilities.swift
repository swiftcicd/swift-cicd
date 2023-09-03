import Foundation

public extension FileManager {
    func removeItemIfItExists(atPath path: String) throws {
        guard self.fileExists(atPath: path) else {
            return
        }

        try removeItem(atPath: path)
    }

    func removeItemIfItExists(at url: URL) throws {
        guard self.fileExists(atPath: url.filePath) else {
            return
        }

        try removeItem(at: url)
    }
}
