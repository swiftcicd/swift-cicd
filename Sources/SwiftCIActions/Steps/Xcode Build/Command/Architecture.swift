extension XcodeBuild {
    enum Arch: ExpressibleByStringLiteral, Option {
        case arm64
        case x86_64
        case other(String)

        var name: String { "arch" }
        var argument: Argument {
            switch self {
            case .arm64: return "arm64"
            case .x86_64: return "x86_64"
            case .other(let value): return value
            }
        }

        init(stringLiteral value: String) {
            self = .other(value)
        }
    }
}
