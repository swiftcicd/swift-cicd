import Foundation
import SwiftCICDCore

extension Xcode {
    public struct Build: Action {
        public struct Output {
            public struct Product {
                public let url: URL
                public let name: String
            }

            public let product: Product?
        }

        var container: Xcode.Container?
        var scheme: String?
        var configuration: XcodeBuild.Configuration?
        let destination: XcodeBuild.Destination?
        let sdk: XcodeBuild.SDK?
        var cleanBuild: Bool
        var archivePath: String?
        var codeSignStyle: XcodeBuild.CodeSignStyle?
        var projectVersion: String?
        var includeDSYMs: Bool?
        let xcbeautify: Bool

        init(
            container: Xcode.Container? = nil,
            scheme: String? = nil,
            // FIXME: xcodebuild's actual default is RELEASE. Should we mirror that?
            configuration: XcodeBuild.Configuration? = .debug,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            sdk: XcodeBuild.SDK? = nil,
            cleanBuild: Bool = false,
            archivePath: String? = nil,
            codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
            projectVersion: String? = nil,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.container = container
            self.scheme = scheme
            self.configuration = configuration
            self.destination = destination
            self.sdk = sdk ?? destination?.sdk
            self.cleanBuild = cleanBuild
            self.archivePath = archivePath
            self.codeSignStyle = codeSignStyle
            self.projectVersion = projectVersion
            self.includeDSYMs = includeDSYMs
            self.xcbeautify = xcbeautify
        }

        public init(
            project: String? = nil,
            scheme: String? = nil,
            // FIXME: xcodebuild's actual default is RELEASE. Should we mirror that?
            configuration: XcodeBuild.Configuration? = .debug,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            sdk: XcodeBuild.SDK? = nil,
            cleanBuild: Bool = false,
            archivePath: String? = nil,
            codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
            projectVersion: String? = nil,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.init(
                container: project.map { .project($0) },
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        }

        @_disfavoredOverload
        public init(
            workspace: String? = nil,
            scheme: String? = nil,
            // FIXME: xcodebuild's actual default is RELEASE. Should we mirror that?
            configuration: XcodeBuild.Configuration? = .debug,
            destination: XcodeBuild.Destination? = .iOSSimulator,
            sdk: XcodeBuild.SDK? = nil,
            cleanBuild: Bool = false,
            archivePath: String? = nil,
            codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
            projectVersion: String? = nil,
            includeDSYMs: Bool? = nil,
            xcbeautify: Bool = Xcbeautify.default
        ) {
            self.init(
                container: workspace.map { .workspace($0) },
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        }

        public func run() async throws -> Output {
            var xcodebuild = ShellCommand("xcodebuild")
            let container = try self.container ?? context.xcodeContainer
            let scheme = self.scheme ?? context.xcodeScheme
            // TODO: Support -workspace as well. Use XcodeBuild.XcodeContainer.
            try xcodebuild.append(container?.flag)
            xcodebuild.append("-scheme", ifLet: scheme)
            xcodebuild.append("-destination", ifLet: destination?.value)
            xcodebuild.append("-configuration", ifLet: configuration?.name)
            xcodebuild.append("-sdk", ifLet: sdk?.value)
            // Control the derived data path so that we can look for built products there
//            xcodebuild.append("-derivedDataPath \(XcodeBuild.derivedData.filePath)")
            xcodebuild.append("clean", if: cleanBuild)

            if let archivePath {
                xcodebuild.append("archive -archivePath \(archivePath)")
            } else {
                xcodebuild.append("build")
            }

            xcodebuild.append("CURRENT_PROJECT_VERSION", "=", ifLet: projectVersion)

            // Only override the debug information format if the flag was explicitly passed.
            if let includeDSYMs {
                xcodebuild.append("DEBUG_INFORMATION_FORMAT=\(includeDSYMs ? "dwarf-with-dsym" : "dwarf")")
            }

            if case let .manual(codeSignIdentity, developmentTeam, provisioningProfile) = codeSignStyle {
                // It seems like this happens when you have a swift package that has a target that has resources.
                // Adding CODE_SIGNING_REQUIRED=Yes and CODE_SIGNING_ALLOWED=No because of this answer:
                // https://forums.swift.org/t/xcode-14-beta-code-signing-issues-when-spm-targets-include-resources/59685/17

                // need either code sign identity or development team, but not both (both can be used, just not required) according to testing
                // there's a note on this thread (https://developer.apple.com/forums/thread/48762) that says apple says not to use code_sign_identity when doing manual signing

                // But there's a slide from that presentation (https://devstreaming-cdn.apple.com/videos/wwdc/2017/403yv29uwyamwsi222/403/403_whats_new_in_signing_for_xcode_and_xcode_server.pdf)
                // that has this on it:
                /*
                 Manual Signing
                 Build settings
                 DEVELOPMENT_TEAM to set your team identifier
                 PROVISIONING_PROFILE_SPECIFIER to set your profile name
                 CODE_SIGN_IDENTITY to set your certificate
                 */
                // So maybe those notes are wrong?

                // Also provisioning_profile is supposedly deprecated (or at the xcodebuild argument was)
                // Does that mean we shouldn't use the build setting? Maybe just the specifier?
                // Only using the specifier setting seems to work.

                xcodebuild.append("""
                CODE_SIGNING_REQUIRED=Yes \
                CODE_SIGNING_ALLOWED=No \
                CODE_SIGN_STYLE=Manual \
                CODE_SIGN_IDENTITY=\(codeSignIdentity) \
                DEVELOPMENT_TEAM=\(developmentTeam) \
                PROVISIONING_PROFILE=\(provisioningProfile)
                PROVISIONING_PROFILE_SPECIFIER=\(provisioningProfile)
                """
                )
            }

            try await xcbeautify(xcodebuild, if: xcbeautify)

            let settings = try await xcode.getBuildSettings(
                container: container,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk
//                derivedDataPath: derivedData.filePath
            )

            var product: Output.Product?

            if let buildDirectory = settings[.configurationBuildDirectory], let fullProductName = settings[.fullProductName] {
                let productPath = "\(buildDirectory)/\(fullProductName)"
                let productURL = URL(filePathCompat: productPath)
                if context.fileManager.fileExists(atPath: productPath) {
                    product = Output.Product(url: productURL, name: fullProductName)
                }
            }
//            else if let configuration {
//                // TODO: When building a Swift package, how do we determine the name of the product?
//                let name = "???"
//                let productPath = derivedData/"Build/Products/\(configuration.name)/\(name)"
//                if context.fileManager.fileExists(atPath: productPath.filePath) {
//                    product = Output.Product(url: productPath, name: name)
//                }
//            }

            let output = Output(product: product)
            context.outputs.latestXcodeBuildProduct = output
            return output
        }

        public func cleanUp(error: Error?) async throws {
            if let archivePath {
                try context.fileManager.removeItemIfItExists(atPath: archivePath)
            }
        }
    }
}

public extension Xcode {
    @discardableResult
    func build(
        project: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = .debug,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        sdk: XcodeBuild.SDK? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> Build.Output {
        try await run(
            Build(
                project: project,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @_disfavoredOverload
    @discardableResult
    func build(
        workspace: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = .debug,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        sdk: XcodeBuild.SDK? = nil,
        cleanBuild: Bool = false,
        archivePath: String? = nil,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> Build.Output {
        try await run(
            Build(
                workspace: workspace,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @discardableResult
    func archive(
        project: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = .debug,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        sdk: XcodeBuild.SDK? = nil,
        cleanBuild: Bool = false,
        archivePath: String,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> Build.Output {
        try await run(
            Build(
                project: project,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @_disfavoredOverload
    @discardableResult
    func archive(
        workspace: String? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = .debug,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        sdk: XcodeBuild.SDK? = nil,
        cleanBuild: Bool = false,
        archivePath: String,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> Build.Output {
        try await run(
            Build(
                workspace: workspace,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }

    @discardableResult
    internal func archive(
        container: Xcode.Container? = nil,
        scheme: String? = nil,
        configuration: XcodeBuild.Configuration? = .debug,
        destination: XcodeBuild.Destination? = .iOSSimulator,
        sdk: XcodeBuild.SDK? = nil,
        cleanBuild: Bool = false,
        archivePath: String,
        codeSignStyle: XcodeBuild.CodeSignStyle? = nil,
        projectVersion: String? = nil,
        includeDSYMs: Bool? = nil,
        xcbeautify: Bool = Xcbeautify.default
    ) async throws -> Build.Output {
        try await run(
            Build(
                container: container,
                scheme: scheme,
                configuration: configuration,
                destination: destination,
                sdk: sdk,
                cleanBuild: cleanBuild,
                archivePath: archivePath,
                codeSignStyle: codeSignStyle,
                projectVersion: projectVersion,
                includeDSYMs: includeDSYMs,
                xcbeautify: xcbeautify
            )
        )
    }
}

public extension OutputValues {
    private enum Key: OutputKey {
        static var defaultValue: Xcode.Build.Output?
    }

    var latestXcodeBuildProduct: Xcode.Build.Output? {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}
