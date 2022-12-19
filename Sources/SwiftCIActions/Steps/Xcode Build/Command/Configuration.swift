extension XcodeBuild {
    public enum Configuration: ExpressibleByStringLiteral, Argument {
        case debug
        case release
        case custom(String)

        public var argument: String {
            switch self {
            case .debug:
                return "Debug"
            case .release:
                return "Release"
            case .custom(let value):
                return value
            }
        }

        public init(stringLiteral value: String) {
            self = .custom(value)
        }
    }
}
