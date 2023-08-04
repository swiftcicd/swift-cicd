import Foundation
import Logging

public enum LocalPlatform: Platform {
    public static let name = "Local"
    public static let isRunningCI = false
    public static let workingDirectory = FileManager.default.currentDirectoryPath

    public static func detect() -> Bool {
        CommandLine.arguments.contains("local")
    }

    public static func startLogGroup(named groupName: String) {
        endLogGroup()
        print("start log group: \(groupName)")
    }

    public static func endLogGroup() {
        print("end log group")
    }

    public static func obfuscate(secret: String) {
        print("obfuscating: \(secret.prefix(4))***")
    }
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
