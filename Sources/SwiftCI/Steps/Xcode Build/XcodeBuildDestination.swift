extension XcodeBuildStep {
    public enum Destination: Argument {
        public enum Platform: String {
            case iOSSimulator = "iOS Simulator"
            case macOS = "OS X"
        }

        public enum GenericPlatform: String {
            case iOS
            case macOS = "OS X"
        }

        case platform(String, os: String, name: String)
        case generic(platform: String)

        public static func platform(_ platform: Platform, os: String = "latest", name: String) -> Destination {
            .platform(platform.rawValue, os: os, name: name)
        }

        public static func generic(platform: GenericPlatform) -> Destination {
            .generic(platform: platform.rawValue)
        }

        public var argument: String {
            switch self {
            case let .platform(platform, os, name):
                return "platform=\(platform),OS=\(os),name=\(name)"
            case .generic(let platform):
                return "generic/platform=\(platform)"
            }
        }
    }
}
