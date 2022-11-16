import Foundation

public struct AddProfile: Step {
    /// Path to .mobileprovision file.
    let profilePath: String

    public func run() async throws -> Profile {
        // https://stackoverflow.com/a/46095880/4283188

        guard let profileContents = context.fileManager.contents(atPath: profilePath) else {
            throw ProfileError(message: "Failed to get contents at \(profilePath)")
        }
        let profile = try openProfile(contents: profileContents)

        let provisioningProfiles = context.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")

        try context.fileManager.createDirectory(at: provisioningProfiles, withIntermediateDirectories: true)

        let addedProfilePath = provisioningProfiles
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles/\(profile.uuid).mobileprovision")
            .path

        guard context.fileManager.createFile(atPath: addedProfilePath, contents: profileContents) else {
            throw ProfileError(message: "Failed to create \(addedProfilePath)")
        }
        return profile
    }

    struct ProfileError: Error {
        let message: String
    }

    func openProfile(contents: Data) throws -> Profile {
        let stringContents = String(decoding: contents, as: UTF8.self)

        guard
            let xmlOpen = stringContents.range(of: "<?xml"),
            let plistClose = stringContents.range(of: "</plist>")
        else {
            throw ProfileError(message: "Couldn't find plist in profile")
        }

        let plist = stringContents[xmlOpen.lowerBound...plistClose.upperBound]
        let plistData = Data(plist.utf8)
        let profile = try PropertyListDecoder().decode(Profile.self, from: plistData)
        return profile
    }

    public struct Profile: Decodable {
        public let name: String
        public let teamIdentifier: [String]
        public let uuid: String
        public let teamName: String

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case teamIdentifier = "TeamIdentifier"
            case uuid = "UUID"
            case teamName = "TeamName"
        }
    }
}

public extension Step where Self == AddProfile {
    static func addProfile(_ pathToProfile: String) -> AddProfile {
        AddProfile(profilePath: pathToProfile)
    }
}
