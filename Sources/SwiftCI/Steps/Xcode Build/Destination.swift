extension XcodeBuild {
    public enum Destination: CommandArgument {
        public enum Platform: String {
            case iOSSimulator = "iOS Simulator"
            case macOS = "OS X"
        }

        case platformOSName(platform: String, os: String, name: String)

        public init(platform: String, os: String = "latest", name: String) {
            self = .platformOSName(platform: platform, os: os, name: name)
        }

        public init(platform: Platform, os: String = "latest", name: String) {
            self.init(platform: platform.rawValue, os: os, name: name)
        }

        public var argument: String {
            switch self {
            case let .platformOSName(platform, os, name):
                return "'platform=\(platform),OS=\(os),name=\(name)'"
            }
        }
    }
}
