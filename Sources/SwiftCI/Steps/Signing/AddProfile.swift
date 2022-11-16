import Foundation

public struct AddProfile: Step {
    /// Path to .mobileprovision file.
    let profilePath: String

    public func run() async throws -> ProvisioningProfile {
        // https://stackoverflow.com/a/46095880/4283188

        guard let profileContents = context.fileManager.contents(atPath: profilePath) else {
            throw ProfileError(message: "Failed to get contents at \(profilePath)")
        }
        let profile = try openProfile(contents: profileContents)

        let provisioningProfiles = context.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")

        logger.debug("Creating directory: \(provisioningProfiles.path)")
        try context.fileManager.createDirectory(at: provisioningProfiles, withIntermediateDirectories: true)

        let addedProfilePath = provisioningProfiles
            .appendingPathComponent("\(profile.uuid).mobileprovision")
            .path

        logger.debug("Creating file: \(addedProfilePath)")
        guard context.fileManager.createFile(atPath: addedProfilePath, contents: profileContents) else {
            throw ProfileError(message: "Failed to create \(addedProfilePath)")
        }

        logger.debug("Created: \(addedProfilePath)")
        return profile
    }

    struct ProfileError: Error {
        let message: String
    }

    func openProfile(contents: Data) throws -> ProvisioningProfile {
        let stringContents = String(decoding: contents, as: UTF8.self)

        guard
            let xmlOpen = stringContents.range(of: "<?xml"),
            let plistClose = stringContents.range(of: "</plist>")
        else {
            throw ProfileError(message: "Couldn't find plist in profile")
        }

        let plist = stringContents[xmlOpen.lowerBound...plistClose.upperBound]
        let plistData = Data(plist.utf8)
        let profile = try PropertyListDecoder().decode(ProvisioningProfile.self, from: plistData)

        return profile
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

    public struct CertificateError: Error {
        let message: String
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

        guard let certificate: SecCertificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw CertificateError(message: "Failed to create certificate from data")
        }

        var _commonName: CFString?
        SecCertificateCopyCommonName(certificate, &_commonName)

        guard let commonName = _commonName as? String else {
            throw CertificateError(message: "Certificate missing common name")
        }

        return Certificate(commonName: commonName)
    }

    public struct Certificate {
        public let commonName: String
    }
}

public extension Step where Self == AddProfile {
    static func addProfile(_ pathToProfile: String) -> AddProfile {
        AddProfile(profilePath: pathToProfile)
    }
}
