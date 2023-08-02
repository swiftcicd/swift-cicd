import Foundation

public extension URL {
    init(filePathCompat filePath: String, relativeTo url: URL? = nil) {
        if #available(macOS 13.0, *) {
            self.init(filePath: filePath, relativeTo: url)
        } else {
            self.init(fileURLWithPath: filePath, relativeTo: url)
        }
    }

    mutating func appendCompat(_ path: String) {
        if #available(macOS 13.0, *) {
            self.append(path: path)
        } else {
            self.appendPathComponent(path)
        }
    }

    func appendingCompat(_ path: String) -> URL {
        var copy = self
        copy.appendCompat(path)
        return copy
    }

    static func / (lhs: URL, rhs: String) -> URL {
        lhs.appendingCompat(rhs)
    }

    mutating func appendQueryItems(_ items: [URLQueryItem]) {
        if #available(macOS 13.0, *) {
            self.append(queryItems: items)
        } else {
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
            var queryItems = components.queryItems ?? []
            queryItems.append(contentsOf: items)
            self = components.url!
        }
    }

    func appendingQueryItemsCompat(_ items: [URLQueryItem]) -> URL {
        var copy = self
        copy.appendQueryItems(items)
        return copy
    }

    var fileURL: URL {
        guard !isFileURL else {
            return self
        }

        return URL(filePathCompat: filePath)
    }

    var filePath: String {
        if #available(macOS 13.0, *) {
            return self.path()
        } else {
            return self.path
        }
    }
}
