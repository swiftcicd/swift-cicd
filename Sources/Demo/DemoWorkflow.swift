import SwiftCI

@main
struct CICD: Workflow {
    static let name = "CICD"

    func run() async throws {
        let destination = XcodeBuildStep.Destination(platform: .iOSSimulator, name: "iPhone 14")
        let localizationPath = "Localizations/hx-ios"
        let packageScheme = "hx-ios-Package"
        
        // ssh

        for file in try context.fileManager.contentsOfDirectory(atPath: localizationPath) {
            try await step(.xcodebuild(importLocalizationsFrom: file))
        }

        try await step(.xcodebuild(buildScheme: packageScheme, destination: destination))

        try await step(.xcodebuild(testScheme: packageScheme, destination: destination, withoutBuilding: true))

        try await step(.xcodebuild(buildScheme: "HX App", destination: destination))

        try await step(.xcodebuild(exportLocalizationsTo: localizationPath))

        // commit changes
        try await step(.commitAllChanges(message: "(Automated) Import/export localizations."))

        // run swift-pr
        try await step(.swift(run: "pr", "--verbose"))
    }
}
