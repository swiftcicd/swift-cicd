public struct XcodeBuildStep: Step {
    // TODO: Refactor to make a command enum with cases for build, test, archive, import/exportLocalizations, exportArchive

//    struct Command {
//        enum Command {
//            case clean
//            case build
//            case test(withoutBuilding: Bool)
//            case importLocalizations(localizationPath: String)
//            case exportLocalizations(localizationPath: String)
//            case archive(platform: XcodeBuildStep.Destination.GenericPlatform, archivePath: String)
//            case exportArchive(archivePath: String, exportPath: String?, exportOptionsPath: String)
//        }
//
//        public enum Configuration: ExpressibleByStringLiteral {
//            case debug
//            case release
//            case custom(String)
//
//            var string: String {
//                switch self {
//                case .debug:
//                    return "Debug"
//                case .release:
//                    return "Release"
//                case .custom(let value):
//                    return value
//                }
//            }
//
//            public init(stringLiteral value: String) {
//                self = .custom(value)
//            }
//        }
//
//        public enum CodeSignStyle {
//            case manual(provisioningProfile: String, codeSignIdentity: String)
//            case automatic
//
//            public static func manual(profile: ProvisioningProfile) throws -> CodeSignStyle {
//                let certificate = try profile.openDeveloperCertificate()
//                return .manual(provisioningProfile: profile.uuid, codeSignIdentity: certificate.commonName)
//            }
//        }
//
//        let scheme: String
//        var destination: XcodeBuildStep.Destination?
//        var configuration: Configuration?
//        var commands: [Command]?
//        var codeSignStyle: CodeSignStyle?
//    }

    public let name = "Xcode Build"

    let arguments: [Argument]

    public init(arguments: [Argument]) {
        self.arguments = arguments
    }

    public func run() async throws -> String {
        try context.shell("xcodebuild", arguments)
    }
}

public extension Step where Self == XcodeBuildStep {
    static func xcodebuild(_ arguments: Argument...) -> XcodeBuildStep {
        XcodeBuildStep(arguments: arguments)
    }
}

/*

 Usage: xcodebuild [-project <projectname>] [[-target <targetname>]...|-alltargets] [-configuration <configurationname>] [-arch <architecture>]... [-sdk [<sdkname>|<sdkpath>]] [-showBuildSettings [-json]] [<buildsetting>=<value>]... [<buildaction>]...
        xcodebuild [-project <projectname>] -scheme <schemeName> [-destination <destinationspecifier>]... [-configuration <configurationname>] [-arch <architecture>]... [-sdk [<sdkname>|<sdkpath>]] [-showBuildSettings [-json]] [-showdestinations] [<buildsetting>=<value>]... [<buildaction>]...
        xcodebuild -workspace <workspacename> -scheme <schemeName> [-destination <destinationspecifier>]... [-configuration <configurationname>] [-arch <architecture>]... [-sdk [<sdkname>|<sdkpath>]] [-showBuildSettings] [-showdestinations] [<buildsetting>=<value>]... [<buildaction>]...
        xcodebuild -version [-sdk [<sdkfullpath>|<sdkname>] [-json] [<infoitem>] ]
        xcodebuild -list [[-project <projectname>]|[-workspace <workspacename>]] [-json]
        xcodebuild -showsdks [-json]
        xcodebuild -exportArchive -archivePath <xcarchivepath> [-exportPath <destinationpath>] -exportOptionsPlist <plistpath>
        xcodebuild -exportNotarizedApp -archivePath <xcarchivepath> -exportPath <destinationpath>
        xcodebuild -exportLocalizations -localizationPath <path> -project <projectname> [-exportLanguage <targetlanguage>...[-includeScreenshots]]
        xcodebuild -importLocalizations -localizationPath <path> -project <projectname> [-mergeImport]
        xcodebuild -resolvePackageDependencies [-project <projectname>|-workspace <workspacename>] -clonedSourcePackagesDirPath <path>
        xcodebuild -create-xcframework [-help] [-framework <path>] [-library <path> [-headers <path>]] -output <path>

 Options:
     -usage                                                   print brief usage
     -help                                                    print complete usage
     -verbose                                                 provide additional status output
     -license                                                 show the Xcode and SDK license agreements
     -checkFirstLaunchStatus                                  Check if any First Launch tasks need to be performed
     -runFirstLaunch                                          install packages and agree to the license
     -downloadAllPlatforms                                    download all platforms
     -downloadPlatform NAME                                   download the platform NAME
     -downloadAllPreviouslySelectedPlatforms                  download all previously selected platforms
     -project NAME                                            build the project NAME
     -target NAME                                             build the target NAME
     -alltargets                                              build all targets
     -workspace NAME                                          build the workspace NAME
     -scheme NAME                                             build the scheme NAME
     -configuration NAME                                      use the build configuration NAME for building each target
     -xcconfig PATH                                           apply the build settings defined in the file at PATH as overrides
     -arch ARCH                                               build each target for the architecture ARCH; this will override architectures defined in the project
     -sdk SDK                                                 use SDK as the name or path of the base SDK when building the project
     -toolchain NAME                                          use the toolchain with identifier or name NAME
     -destination DESTINATIONSPECIFIER                        use the destination described by DESTINATIONSPECIFIER (a comma-separated set of key=value pairs describing the destination to use)
     -destination-timeout TIMEOUT                             wait for TIMEOUT seconds while searching for the destination device
     -parallelizeTargets                                      build independent targets in parallel
     -jobs NUMBER                                             specify the maximum number of concurrent build operations
     -maximum-concurrent-test-device-destinations NUMBER      the maximum number of device destinations to test on concurrently
     -maximum-concurrent-test-simulator-destinations NUMBER   the maximum number of simulator destinations to test on concurrently
     -parallel-testing-enabled YES|NO                         overrides the per-target setting in the scheme
     -parallel-testing-worker-count NUMBER                    the exact number of test runners that will be spawned during parallel testing
     -maximum-parallel-testing-workers NUMBER                 the maximum number of test runners that will be spawned during parallel testing
     -dry-run                                                 do everything except actually running the commands
     -quiet                                                   do not print any output except for warnings and errors
     -hideShellScriptEnvironment                              don't show shell script environment variables in build log
     -showsdks                                                display a compact list of the installed SDKs
     -showdestinations                                        display a list of destinations
     -showTestPlans                                           display a list of test plans
     -showBuildSettings                                       display a list of build settings and values
     -showBuildSettingsForIndex                               display build settings for the index service
     -list                                                    lists the targets and configurations in a project, or the schemes in a workspace
     -find-executable NAME                                    display the full path to executable NAME in the provided SDK and toolchain
     -find-library NAME                                       display the full path to library NAME in the provided SDK and toolchain
     -version                                                 display the version of Xcode; with -sdk will display info about one or all installed SDKs
     -enableAddressSanitizer YES|NO                           turn the address sanitizer on or off
     -enableThreadSanitizer YES|NO                            turn the thread sanitizer on or off
     -enableUndefinedBehaviorSanitizer YES|NO                 turn the undefined behavior sanitizer on or off
     -resultBundlePath PATH                                   specifies the directory where a result bundle describing what occurred will be placed
     -resultStreamPath PATH                                   specifies the file where a result stream will be written to (the file must already exist)
     -resultBundleVersion 3 [default]                         specifies which result bundle version should be used
     -clonedSourcePackagesDirPath PATH                        specifies the directory to which remote source packages are fetch or expected to be found
     -derivedDataPath PATH                                    specifies the directory where build products and other derived data will go
     -archivePath PATH                                        specifies the directory where any created archives will be placed, or the archive that should be exported
     -exportArchive                                           specifies that an archive should be exported
     -exportNotarizedApp                                      export an archive that has been notarized by Apple
     -exportOptionsPlist PATH                                 specifies a path to a plist file that configures archive exporting
     -enableCodeCoverage YES|NO                               turn code coverage on or off when testing
     -exportPath PATH                                         specifies the destination for the product exported from an archive
     -skipUnavailableActions                                  specifies that scheme actions that cannot be performed should be skipped instead of causing a failure
     -exportLocalizations                                     exports completed and outstanding project localizations
     -importLocalizations                                     imports localizations for a project, assuming any necessary localized resources have been created in Xcode
     -localizationPath                                        specifies a path to XLIFF localization files
     -exportLanguage                                          specifies multiple optional ISO 639-1 languages included in a localization export
     -xctestrun                                               specifies a path to a test run specification
     -testProductsPath                                        specifies a path for the test products
     -enablePerformanceTestsDiagnostics YES|NO                enables performance trace and memgraph collection for performance XCTests
     -testPlan                                                specifies the name of the test plan associated with the scheme to use for testing
     -only-testing                                            constrains testing by specifying tests to include, and excluding other tests
     -only-testing:TEST-IDENTIFIER                            constrains testing by specifying tests to include, and excluding other tests
     -skip-testing                                            constrains testing by specifying tests to exclude, but including other tests
     -skip-testing:TEST-IDENTIFIER                            constrains testing by specifying tests to exclude, but including other tests
     -test-timeouts-enabled YES|NO                            enable or disable test timeout behavior
     -default-test-execution-time-allowance SECONDS           the default execution time an individual test is given to execute, if test timeouts are enabled
     -maximum-test-execution-time-allowance SECONDS           the maximum execution time an individual test is given to execute, regardless of the test's preferred allowance
     -test-iterations <number>                                If specified, tests will run <number> times. May be used in conjunction with either -retry-tests-on-failure or -run-tests-until-failure, in which case this will become the maximum number of iterations.
     -retry-tests-on-failure                                  If specified, tests will retry on failure. May be used in conjunction with -test-iterations <number>, in which case <number> will be the maximum number of iterations. Otherwise, a maximum of 3 is assumed. May not be used with -run-tests-until-failure.
     -run-tests-until-failure                                 If specified, tests will run until they fail. May be used in conjunction with -test-iterations <number>, in which case <number> will be the maximum number of iterations. Otherwise, a maximum of 100 is assumed. May not be used with -retry-tests-on-failure.
     -test-repetition-relaunch-enabled YES|NO                 Enable or disable, tests repeating in a new process for each repetition.  Must be used in conjunction with -test-iterations, -retry-tests-on-failure, or -run-tests-until-failure. If not specified, tests will repeat in the same process.
     -only-test-configuration                                 constrains testing by specifying test configurations to include, and excluding other test configurations
     -skip-test-configuration                                 constrains testing by specifying test configurations to exclude, but including other test configurations
     -testLanguage                                            constrains testing by specifying ISO 639-1 language in which to run the tests
     -testRegion                                              constrains testing by specifying ISO 3166-1 region in which to run the tests
     -resolvePackageDependencies                              resolves any Swift package dependencies referenced by the project or workspace
     -disableAutomaticPackageResolution                       prevents packages from automatically being resolved to versions other than those recorded in the `Package.resolved` file
     -onlyUsePackageVersionsFromResolvedFile                  prevents packages from automatically being resolved to versions other than those recorded in the `Package.resolved` file
     -skipPackageUpdates                                      Skip updating package dependencies from their remote
     -disablePackageRepositoryCache                           disable use of a local cache of remote package repositories
     -skipPackagePluginValidation                             Skip validation of package plugins (this can be a security risk if they are not from trusted sources)
     -packageCachePath                                        path of caches used for package support
     -json                                                    output as JSON (note: -json implies -quiet)
     -allowProvisioningUpdates                                Allow xcodebuild to communicate with the Apple Developer website. For automatically signed targets, xcodebuild will create and update profiles, app IDs, and certificates. For manually signed targets, xcodebuild will download missing or updated provisioning profiles. Requires a developer account to have been added in Xcode's Accounts preference pane or an App Store Connect authentication key to be specified via the -authenticationKeyPath, -authenticationKeyID, and -authenticationKeyIssuerID parameters.
     -allowProvisioningDeviceRegistration                     Allow xcodebuild to register your destination device on the developer portal if necessary. This flag only takes effect if -allowProvisioningUpdates is also passed.
     -authenticationKeyPath                                   specifies the path to an authentication key issued by App Store Connect. If specified, xcodebuild will authenticate with the Apple Developer website using this credential. The -authenticationKeyID and -authenticationKeyIssuerID parameters are required.
     -authenticationKeyID                                     specifies the key identifier associated with the App Store Conect authentication key at -authenticationKeyPath. This string can be located in the users and access details for your provider at "https://appstoreconnect.apple.com".
     -authenticationKeyIssuerID                               specifies the App Store Connect issuer identifier associated with the authentication key at -authenticationKeyPath. This string can be located in the users and access details for your provider at "https://appstoreconnect.apple.com".
     -scmProvider                                             which implementation to use for Git operations (system/xcode)
     -showBuildTimingSummary                                  display a report of the timings of all the commands invoked during the build
     -create-xcframework                                      create an xcframework from prebuilt libraries; -help for more information.

 Available keys for -exportOptionsPlist:

     compileBitcode : Bool

         For non-App Store exports, should Xcode re-compile the app from bitcode? Defaults to YES.

     destination : String

         Determines whether the app is exported locally or uploaded to Apple. Options are export or upload. The available options vary based on the selected distribution method. Defaults to export.

     distributionBundleIdentifier : String

         Reformat archive to focus on eligible target bundle identifier.

     embedOnDemandResourcesAssetPacksInBundle : Bool

         For non-App Store exports, if the app uses On Demand Resources and this is YES, asset packs are embedded in the app bundle so that the app can be tested without a server to host asset packs. Defaults to YES unless onDemandResourcesAssetPacksBaseURL is specified.

     generateAppStoreInformation : Bool

         For App Store exports, should Xcode generate App Store Information for uploading with iTMSTransporter? Defaults to NO.

     iCloudContainerEnvironment : String

         If the app is using CloudKit, this configures the "com.apple.developer.icloud-container-environment" entitlement. Available options vary depending on the type of provisioning profile used, but may include: Development and Production.

     installerSigningCertificate : String

         For manual signing only. Provide a certificate name, SHA-1 hash, or automatic selector to use for signing. Automatic selectors allow Xcode to pick the newest installed certificate of a particular type. The available automatic selectors are "Developer ID Installer" and "Mac Installer Distribution". Defaults to an automatic certificate selector matching the current distribution method.

     manageAppVersionAndBuildNumber

         Should Xcode manage the app's build number when uploading to App Store Connect? Defaults to YES.

     manifest : Dictionary

         For non-App Store exports, users can download your app over the web by opening your distribution manifest file in a web browser. To generate a distribution manifest, the value of this key should be a dictionary with three sub-keys: appURL, displayImageURL, fullSizeImageURL. The additional sub-key assetPackManifestURL is required when using on-demand resources.

     method : String

         Describes how Xcode should export the archive. Available options: app-store, validation, ad-hoc, package, enterprise, development, developer-id, and mac-application. The list of options varies based on the type of archive. Defaults to development.

     onDemandResourcesAssetPacksBaseURL : String

         For non-App Store exports, if the app uses On Demand Resources and embedOnDemandResourcesAssetPacksInBundle isn't YES, this should be a base URL specifying where asset packs are going to be hosted. This configures the app to download asset packs from the specified URL.

     provisioningProfiles : Dictionary

         For manual signing only. Specify the provisioning profile to use for each executable in your app. Keys in this dictionary are the bundle identifiers of executables; values are the provisioning profile name or UUID to use.

     signingCertificate : String

         For manual signing only. Provide a certificate name, SHA-1 hash, or automatic selector to use for signing. Automatic selectors allow Xcode to pick the newest installed certificate of a particular type. The available automatic selectors are "Mac App Distribution", "iOS Distribution", "iOS Developer", "Developer ID Application", "Apple Distribution", "Mac Developer", and "Apple Development". Defaults to an automatic certificate selector matching the current distribution method.

     signingStyle : String

         The signing style to use when re-signing the app for distribution. Options are manual or automatic. Apps that were automatically signed when archived can be signed manually or automatically during distribution, and default to automatic. Apps that were manually signed when archived must be manually signed during distribtion, so the value of signingStyle is ignored.

     stripSwiftSymbols : Bool

         Should symbols be stripped from Swift libraries in your IPA? Defaults to YES.

     teamID : String

         The Developer Portal team to use for this export. Defaults to the team used to build the archive.

     thinning : String

         For non-App Store exports, should Xcode thin the package for one or more device variants? Available options: <none> (Xcode produces a non-thinned universal app), <thin-for-all-variants> (Xcode produces a universal app and all available thinned variants), or a model identifier for a specific device (e.g. "iPhone7,1"). Defaults to <none>.

     uploadSymbols : Bool

         For App Store exports, should the package include symbols? Defaults to YES.
 */
