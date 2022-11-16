import Foundation

public struct AddProfile: Step {
    /// Path to .mobileprovision file.
    let profile: String

    public func run() async throws -> Profile {
        // https://stackoverflow.com/a/46095880/4283188
        let profile = try openProfile()
        try context.shell("cp", "-R", self.profile, "~/Library/MobileDevices/Provisioning Profiles/\(profile.uuid).mobileprovision")
        return profile
    }

    struct ProfileError: Error {
        let message: String
    }

    func openProfile() throws -> Profile {
        guard let contents = context.fileManager.contents(atPath: profile) else {
            throw ProfileError(message: "Failed to get contents at \(profile)")
        }

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
        AddProfile(profile: pathToProfile)
    }
}
