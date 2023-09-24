import SwiftCICDCore

// https://github.com/XcodesOrg/xcodes

enum Xcodes: Tool, BrewPackage {
    static let name = "xcodes"
    static let formula = "xcodesorg/made/xcodes"

    static func uninstall() async throws {
        // Always sign out before uninstalling.
        try await signout()
        try await uninstallFormula()
    }

    @discardableResult
    private static func xcodes(_ command: ShellCommand, environment: [String: String] = [:]) async throws -> String {
        try await context.shell("xcodes \(command)", environment: environment)
    }

    static func select(_ version: String) async throws {
        try await xcodes("select \(version)")
    }

    static func install(_ version: String, appleID: String, password: Secret, useExperimentalUnxip: Bool = false) async throws {
        try await xcodes("install \(version) \("--experimental-unxip", if: useExperimentalUnxip)", environment: [
            "XCODES_USERNAME": appleID,
            "XCODES_PASSWORD": password.get().string
        ])
    }

    static func uninstall(_ version: String) async throws {
        try await xcodes("uninstall \(version)")
    }

    @discardableResult
    static func listVersions() async throws -> String {
        try await xcodes("list")
    }

    @discardableResult
    static func listInstalledVersions() async throws -> String {
        try await xcodes("installed")
    }

    static func signout() async throws {
        try await xcodes("signout")
    }
}

extension Xcodes {
    static func isVersionListed(_ version: String) async throws -> Bool {
        let output = try await listVersions()
        let versions = output.components(separatedBy: .newlines)
        return versions.contains(where: { $0.hasPrefix(version) })
    }

    static func isVersionInstalled(_ version: String) async throws -> Bool {
        let output = try await listInstalledVersions()
        let versions = output.components(separatedBy: .newlines)
        return versions.contains(where: { $0.hasPrefix(version) })
    }
}

extension Tools {
    var xcodes: Xcodes.Type {
        get async throws {
            try await self[Xcodes.self]
        }
    }
}
