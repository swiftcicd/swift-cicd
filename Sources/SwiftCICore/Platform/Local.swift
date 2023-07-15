import Foundation

public enum LocalPlatform: Platform {
    public static let name = "Local"

    public static var isRunningCI: Bool {
        false
    }

    public static var workingDirectory: String {
        FileManager.default.currentDirectoryPath
    }

    public static let supportsLogGroups = false

    public static let supportsNestedLogGroups = false

    public static let supportsSecretObfuscation = false

    public static func startLogGroup(named groupName: String) {}

    public static func endLogGroup() {}

    public static func detect() -> Bool {
        CommandLine.arguments.contains("local")
    }

    public static func obfuscate(secret: String) {}
}

public extension Platform {
    static var isLocal: Bool {
        if let _ = self as? LocalPlatform.Type {
            return true
        } else {
            return false
        }
    }
}
