import Foundation

public struct AddProfile: Step {
    /// Path to .mobileprovision file.
    let profilePath: String

    @StepState var addedProfilePath: String?

    public func run() async throws -> ProvisioningProfile {
        // https://stackoverflow.com/a/46095880/4283188

        logger.info("Adding profile \(profilePath) to provisioning profiles")

        guard let profileContents = context.fileManager.contents(atPath: profilePath) else {
            throw StepError("Failed to get contents of profile at \(profilePath)")
        }

        let profile = try ProvisioningProfile(data: profileContents)

        let provisioningProfiles = context.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")

        try context.fileManager.createDirectory(at: provisioningProfiles, withIntermediateDirectories: true)

        let addedProfilePath = provisioningProfiles
            .appendingPathComponent("\(profile.uuid).mobileprovision")
            .path

        self.addedProfilePath = addedProfilePath

        guard context.fileManager.createFile(atPath: addedProfilePath, contents: profileContents) else {
            throw StepError("Failed to create profile at \(addedProfilePath)")
        }

        logger.info("Added profile \(addedProfilePath)")
        return profile
    }

    public func cleanUp(error: Error?) async throws {
        if let addedProfilePath {
            try context.fileManager.removeItem(atPath: addedProfilePath)
        }
    }
}

public extension Step where Self == AddProfile {
    static func addProfile(_ pathToProfile: String) -> AddProfile {
        AddProfile(profilePath: pathToProfile)
    }
}

public struct ProvisioningProfile: Decodable {
    public let name: String
    public let teamIdentifier: [String]
    public let uuid: String
    public let teamName: String
    public let developerCertificates: [Data]

    public var teamID: String { teamIdentifier[0] }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case teamIdentifier = "TeamIdentifier"
        case uuid = "UUID"
        case teamName = "TeamName"
        case developerCertificates = "DeveloperCertificates"
    }

    public func requireTeamIdentifier() throws -> String {
        guard let teamIdentifier = teamIdentifier.first else {
            throw StepError("Provisioning profile missing team identifier")
        }

        return teamIdentifier
    }

    public func openDeveloperCertificate() throws -> Certificate {
        guard let certificateData = developerCertificates.first else {
            throw CertificateError(message: "Missing certificate in array")
        }

        return try Certificate(data: certificateData)
    }

    init(data: Data) throws {
        let stringContents = String(decoding: data, as: UTF8.self)

        guard
            let xmlOpen = stringContents.range(of: "<?xml"),
            let plistClose = stringContents.range(of: "</plist>")
        else {
            throw ProfileError(message: "Couldn't find plist in profile")
        }

        let plist = stringContents[xmlOpen.lowerBound...plistClose.upperBound]
        let plistData = Data(plist.utf8)
        let profile = try PropertyListDecoder().decode(ProvisioningProfile.self, from: plistData)
        self = profile
    }
}

struct ProfileError: Error {
    let message: String
}

public struct Certificate {
    public let commonName: String

    init(data: Data) throws {
        guard let certificate: SecCertificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw CertificateError(message: "Failed to create certificate from data")
        }

        var _commonName: CFString?
        SecCertificateCopyCommonName(certificate, &_commonName)

        guard let commonName = _commonName as? String else {
            throw CertificateError(message: "Certificate missing common name")
        }

        self.commonName = commonName
    }
}

struct CertificateError: Error {
    let message: String
}
