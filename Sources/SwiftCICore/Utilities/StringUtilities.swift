public extension String {
    static func / (lhs: String, rhs: String) -> String {
        if lhs.hasSuffix("/") {
            return lhs + rhs
        } else {
            return "\(lhs)/\(rhs)"
        }
    }

    func indented(tabs: Int = 1, tab: String = "\t") -> String {
        self.components(separatedBy: "\n")
            .map { Array(repeating: tab, count: tabs).joined() + $0 }
            .joined(separator: "\n")
    }

    var lastPathComponent: String? {
        components(separatedBy: "/").last
    }

    var removingLastPathComponent: String {
        self.components(separatedBy: "/")
            .dropLast()
            .joined(separator: "/")
    }
}
