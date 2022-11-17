public struct XcodeBuild: ShellCommand {
    let command = "xcodebuild"
    var arguments: [Argument] {
        []
    }

    //   -userdefault=value
    //         Set the user default userdefault to value.

//    var actions: [Action] = [.build]
//    var buildSettings: [XcodeBuildSetting]
//    var target: Target?
//    var scheme: String?
//    var destinations: [Destination]
//    var configuration: Configuration?

    /// Build the project name.xcodeproj.  Required if there are multiple project files in the same directory.
    /// Example: `name.xcodeproj`
    var project: String?

    /// See ``Target``
    var target: Target?

    /// Build the workspace name.xcworkspace.
    /// Example: `name.xcworkspace`
    var workspace: String?

    /// Build the scheme specified by scheme name.  Required if building a workspace.
    var scheme: String?

    /// Use the destination device described by destinationspecifier.
    /// Defaults to a destination that is compatible with the selected scheme.  See ``Destination``.
    var destination: [Destination]?

    /// Use the specified timeout when searching for a destination device. The default is 30 seconds.
    var destinationTimeout: Int?

    /// Use the build configuration specified by configuration name when building each target.
    var configuration: Configuration?

    /// Use the architecture specified by architecture when building each target.
    var arch: Arch?

    /// Build an Xcode project or workspace against the specified SDK, using build tools appropriate for that SDK.
    /// The argument may be an absolute path to an SDK, or the canonical name of an SDK.
    var sdk: String?

    // showsdks
    /// Lists all available SDKs that Xcode knows about, including their canonical names suitable for use with -sdk.
    /// Does not initiate a build.
    var showSDKs: Bool?

    /// Lists the build settings for targets in a project or workspace. Does not initiate a build.
    /// Use with -target or with -scheme. With -scheme, optionally pass a build action (such as build or test) to use targets from the matching scheme action.
    var showBuildSettings: Bool?

    // showdestinations
    /// Lists the valid destinations for a project or workspace and scheme. Does not initiate a build. Use with -project or -workspace and -scheme.
    var showDestinations: Bool?

    /// Display a report of the timings of all the commands invoked during the build.
    var showBuildTimingSummary: Bool?

    /// Lists the test plans (if any) associated with the specified scheme. Does not initiate a build.
    /// Use with -scheme.
    var showTestPlans: Bool?

    /// Lists the targets and configurations in a project, or the schemes in a workspace. Does not initiate a build.
    /// Use with -project or -workspace.
    var list: Bool?

    // [YES | NO]
    /// Turns the address sanitizer on or off. This overrides the setting for the launch action of a scheme in a workspace.
    var enableAddressSanitizer: Bool?

    // [YES | NO]
    /// Turns the thread sanitizer on or off. This overrides the setting for the launch action of a scheme in a workspace.
    var enableThreadSanitizer: Bool?

    // [YES | NO]
    /// Turns the undefined behavior sanitizer on or off. This overrides the setting for the launch action of a scheme in a workspace.
    var enableUndefinedBehaviorSanitizer: Bool?

    // [YES | NO]
    /// Turns code coverage on or off during testing. This overrides the setting for the test action of a scheme in a workspace.
    var enableCodeCoverage: Bool?

    /// Specifies ISO 639-1 language during testing. This overrides the setting for the test action of a scheme in a workspace.
    var testLanguage: String?

    /// Specifies ISO 3166-1 region during testing. This overrides the setting for the test action of a scheme in a workspace.
    var testRegion: String?

    /// Overrides the folder that should be used for derived data when performing an action on a scheme in a workspace.
    var derivedDataPath: String?

    /// Writes a bundle to the specified path with results from performing an action on a scheme in a workspace.
    /// If the path already exists, xcodebuild will exit with an error. Intermediate directories will be created automatically.
    /// The bundle contains build logs, code coverage reports, XML property lists with test results, screenshots and other
    /// attachments collected during testing, and various diagnostic logs.
    var resultBundlePath: String?

    /// Allow xcodebuild to communicate with the Apple Developer website.
    /// For automatically signed targets, xcodebuild will create and update profiles, app IDs, and certificates.
    /// For manually signed targets, xcodebuild will download missing or updated provisioning profiles.
    /// Requires a developer account to have been added in Xcode's Accounts preference pane.
    var allowProvisioningUpdates: Bool?

    /// Allow xcodebuild to register your destination device on the Apple Developer website if necessary.
    /// Requires -allowProvisioningUpdates.
    var allowProvisioningDeviceRegistration: Bool?

    /// See ``Authentication``.
    var authentication: Authentication?

    /// Specifies that an archive should be distributed. Requires -archivePath and -exportOptionsPlist.
    /// For exporting, -exportPath is also required. Cannot be passed along with an action.
    var exportArchive: Bool?

    /// Export an archive that has been notarized by Apple. Requires -archivePath and -exportPath.
    var exportNotarizedApp: Bool?

    /// Specifies the path for the archive produced by the archive action, or specifies the archive that should be exported when -exportArchive or -exportNotarizedApp is passed.
    var archivePath: String?

    /// Specifies the destination for the exported product, including the name of the exported file.
    var exportPath: String?

    /// Specifies options for -exportArchive.  xcodebuild -help can print the full set of available options.
    var exportOptionsPlist: String?

    /// Exports localizations to XLIFF files. Requires -project and -localizationPath. Cannot be passed along with an action.
    var exportLocalizations: Bool?

    /// Imports localizations from an XLIFF file. Requires -project and -localizationPath. Cannot be passed along with an action.
    var importLocalizations: Bool?

    /// Specifies a path to a directory or a single XLIFF localization file.
    var localizationPath: String?

    /// Specifies optional ISO 639-1 languages included in a localization export. May be repeated to specify multiple languages. May be excluded to specify an export includes only development language strings.
    var exportLanguage: String?

    /// Load the build settings defined in filename when building all targets.  These settings will override all other settings, including settings passed individually on the command line.
    var xcconfig: String?

    /// Specifies xctestproducts path.  XCTestProducts are a unified test product format for XCTest. Can only be used with build-for-testing or test-without-building action.  Cannot be used with -workspace or -project.
    /// When used with build-for-testing the path will be used as the destination for where the xctestproducts archive is written to.
    /// Example path: MyProject_MyScheme.xctestproducts When used with test-without-building the path will be used as the source of which xctestproducts archive to use for testing.  test-without-building -testProductsPath
    /// Cannot be used with -workspace or -project.
   var testProductsPath: String?

    /// Specifies test run parameters. Can only be used with the test-without-building action. Cannot be used with -workspace or -project.  See ⟨URL: x-man-page://5/xcodebuild.xctestrun ⟩ for file format details.
   var xctestrun: String?

    /// Specifies which test plan associated with the scheme should be used for testing. Pass the name of the .xctestplan file without its extension.
   var testPlan: String?

    /// Constrain test targets, classes, or methods in test actions.  -only-testing constrains a test action to only testing a specified identifier, and excluding all other identifiers.  -skip-testing constrains a test action to skip testing a specified identifier, but
    /// including all other identifiers. Test identifiers have the form TestTarget[/TestClass[/TestMethod]]. The TestTarget component of an identifier is the name of a unit or UI testing bundle as shown in the Test Navigator.
    ///  An xcodebuild command can combine multiple constraint options, but -only-testing has precedence over -skip-testing.
    ///
    /// -testing test-identifier, -only-testing test-identifier
    var skipTesting: String?
    var onlyTesting: String?

    /// Constrain test configurations in test actions.  -only-test-configuration constrains a test action to only test a specified test configuration within a test plan, and exclude all other test configurations.  -skip-test-configuration constrains a test action to skip a specified
    /// test configuration, but include all other test configurations. Each test configuration name must match the name of a configuration specified in a test plan and is case-sensitive. An xcodebuild command can combine multiple constraint options, but -only-test-configuration has
    /// precedence over -skip-test-configuration.
    var skipTestConfiguration: String?
    var onlyTestConfiguration: String?

    /// Do not run tests on the specified destinations concurrently. The full test suite will run to completion on a given destination before it begins on the next.
   var disableConcurrentDestinationTesting: Bool?

    /// If multiple device destinations are specified (and -disable-concurrent-destination-testing is not passed), only test on number devices at a time. For example, if four iOS devices are specified, but number is 2, the full test suite will run on each device, but only two devices will be testing at a given time.
    var maximumConcurrentTestDeviceDestinations: Int?

    /// If multiple simulator destinations are specified (and -disable-concurrent-destination-testing is not passed), only test on number simulators at a time. For example, if four iOS simulators are specified, but number is 2, the full test suite will run on each
    var maximumConcurrentTestSimulatorDestinations: Int?

    // [YES | NO]
    /// Overrides the per-target setting in the scheme for running tests in parallel.
    var parallelTestingEnabled: Bool?

    /// Spawn exactly number test runners when executing tests in parallel. Overrides -maximum-parallel-testing-workers, if it is specified.
    var parallelTestingWorkerCount: Int?

    /// Limit the number of test runners that will be spawned when running tests in parallel to number.
    var maximumParallelTestingWorkers: Int?

    /// If parallel testing is enabled (either via the -parallel-testing-enabled option, or on an individual test-target basis) and multiple destination specifiers are passed, distribute test classes among the destinations, instead of running the entire test suite on each destination (which is the default behavior when multiple destination specifiers are passed).
    var parallelizeTestsAmongDestinations: [Destination]?

    // [YES | NO]
    /// Enable or disable test timeout behavior. This value takes precedence over the value specified in the test plan.
    var testTimeoutsEnabled: Bool?

    /// The default execution time an individual test is given to execute, if test timeouts are enabled.
    var defaultTestExecutionTimeAllowance: Int?

    /// The maximum execution time an individual test is given to execute, regardless of the test's preferred allowance.
    var maximumTestExecutionTimeAllowance: Int?

    /// If specified, tests will run number times. May be used in conjunction with either -retry-tests-on-failure or -run-tests-until-failure, in which case this will become the maximum number of iterations.
    var testIterations: Int?

    /// If specified, tests will retry on failure. May be used in conjunction with -test-iterations number, in which case number will be the maximum number of iterations. Otherwise, a maximum of 3 is assumed. May not be used with -run-tests-until-failure.
    var retryTestsOnFailure: Bool?

    /// If specified, tests will run until they fail. May be used in conjunction with -test-iterations number, in which case number will be the maximum number of iterations. Otherwise, a maximum of 100 is assumed. May not be used with -retry-tests-on-failure.
    var runTestsUntilFailure: Bool?

    // [YES | NO]
    /// Whether or not each repetition of test should use a new process for its execution.  Must be used in conjunction with -test-iterations, -retry-tests-on-failure, or -run-tests-until-failure.  If not specified, tests will repeat in the same process.
    var testRepitiionRelaunchEnabled: Bool?

    // [on-failure | never]
    /// Whether or not verbose and long-running diagnostics, like sysdiagnoses or log archives, are collected when testing.  If not specified, the value in the test plan will be used.
    var collectTestDiagnostics: Bool?

    // -n
    /// Print the commands that would be executed, but do not execute them.
    var dryRun: Bool?

    /// Skip actions that cannot be performed instead of failing. This option is only honored if -scheme is passed.
    var skipUnavailableActions: Bool?

    // [identifier | name]
    /// Use a given toolchain, specified with either an identifier or name.
   var toolchain: String?

    /// Do not print any output except for warnings and errors.
   var quiet: Bool?

    /// Provide additional status output.
   var verbose: Bool?

    /// Display version information for this install of Xcode. Does not initiate a build. When used in conjunction with -sdk, the version of the specified SDK is displayed, or all SDKs if -sdk is given no argument.  Additionally, a single line of the reported version information may be returned if infoitem is specified.
   var version: Bool?

    /// Show the Xcode and SDK license agreements. Allows for accepting the license agreements without launching Xcode itself, which is useful for headless systems. Must be run as a privileged user.
   var license: Bool?

    /// Check if any First Launch tasks need to be performed.
   var checkFirstLaunchStatus: Bool?

    /// Install packages and agree to the license.
   var runFirstLaunch: Bool?

    /// Download and install all available platforms.
   var downloadAllPlatforms: Bool?

    /// Displays usage information for xcodebuild.
   var usage: Bool?

}


// DESTINATIONS

/*

 Some actions (such as building) may be performed without an actual device present.  To build against a platform generically instead of a specific device, the destination specifier may be prefixed with the optional string "generic/", indicating that the platform should be targeted
 generically.  An example of a generic destination is the "Any iOS Device" destination displayed in Xcode's UI when no physical iOS device is present.

Testing on Multiple Destinations
 When more than one destination is specified with the -destination option, xcodebuild tests on those destinations concurrently. In this mode, xcodebuild automatically chooses the number of devices and simulators that are used simultaneously. All enabled tests in the scheme or xctestrun
 file are run on each destination.

Distributing Archives
 The -exportArchive option specifies that xcodebuild should distribute the archive specified by -archivePath using the options specified by -exportOptionsPlist.  xcodebuild -help can print the full set of available inputs to -exportOptionsPlist.  The product can either be uploaded to
 Apple or exported locally. The exported product will be placed at the path specified by -exportPath.

 Archives that have been uploaded to the Apple notary service can be distributed using the -exportNotarizedApp option. This specifies that xcodebuild should export a notarized app from the archive specified by -archivePath and place the exported product at the path specified by
 -exportPath.  If the archive has not completed processing by the notary service, or processing failed, then xcodebuild will exit and emit informational or error messages.

 When uploading an archive using the -exportArchive option, or exporting a notarized archive using the -exportNotarizedApp option, an Apple ID account belonging to the archive's development team is required. Enter the credentials for the Apple ID account using Xcode's Accounts
 preference pane before invoking xcodebuild.

Environment Variables
 The following environment variables affect the execution of xcodebuild:

 XCODE_XCCONFIG_FILE
                     Set to a path to a file, build settings in that file will be loaded and used when building all targets.  These settings will override all other settings, including settings passed individually on the command line, and those in the file passed with the -xcconfig
                     option.

 TEST_RUNNER_<VAR>   Set an environment variable whose name is prefixed with TEST_RUNNER_ to have that variable passed, with its prefix stripped, to all test runner processes launched during a test action. For example, TEST_RUNNER_Foo=Bar xcodebuild test ... sets the environment
                     variable Foo=Bar in the test runner's environment. Existing variables may be modified using the special token __CURRENT_VALUE__ to represent their current value. For example, TEST_RUNNER_Foo=__CURRENT_VALUE__:Bar appends the string :Bar to any existing value of
                     Foo.

Exit Codes
 xcodebuild exits with codes defined by sysexits(3).  It will exit with EX_OK on success.  On failure, it will commonly exit with EX_USAGE if any options appear malformed, EX_NOINPUT if any input files cannot be found, EX_IOERR if any files cannot be read or written, and EX_SOFTWARE if
 the commands given to xcodebuild fail.  It may exit with other codes in less common scenarios.

 */

/*

 EXAMPLES
      xcodebuild clean install

               Cleans the build directory; then builds and installs the first target in the Xcode project in the directory from which xcodebuild was started.

      xcodebuild -project MyProject.xcodeproj -target Target1 -target Target2 -configuration Debug

               Builds the targets Target1 and Target2 in the project MyProject.xcodeproj using the Debug configuration.

      xcodebuild -target MyTarget OBJROOT=/Build/MyProj/Obj.root SYMROOT=/Build/MyProj/Sym.root

               Builds the target MyTarget in the Xcode project in the directory from which xcodebuild was started, putting intermediate files in the directory /Build/MyProj/Obj.root and the products of the build in the directory /Build/MyProj/Sym.root.

      xcodebuild -sdk macosx10.6

               Builds the Xcode project in the directory from which xcodebuild was started against the macOS 10.6 SDK.  The canonical names of all available SDKs can be viewed using the -showsdks option.

      xcodebuild -workspace MyWorkspace.xcworkspace -scheme MyScheme

               Builds the scheme MyScheme in the Xcode workspace MyWorkspace.xcworkspace.

      xcodebuild archive -workspace MyWorkspace.xcworkspace -scheme MyScheme

               Archives the scheme MyScheme in the Xcode workspace MyWorkspace.xcworkspace.

      xcodebuild build-for-testing -workspace MyWorkspace.xcworkspace -scheme MyScheme -destination generic/platform=iOS

               Build tests and associated targets in the scheme MyScheme in the Xcode workspace MyWorkspace.xcworkspace using the generic iOS device destination. The command also writes test parameters from the scheme to an xctestrun file in the built products directory.

      xcodebuild test-without-building -workspace MyWorkspace.xcworkspace -scheme MyScheme -destination 'platform=iOS Simulator,name=iPhone 5s' -destination 'platform=iOS,name=My iPad'

               Tests the scheme MyScheme in the Xcode workspace MyWorkspace.xcworkspace using both the iOS Simulator and the device named iPhone 5s for the latest version of iOS. The command assumes the test bundles are in the build root (SYMROOT).  (Note that the shell requires arguments
               to be quoted or otherwise escaped if they contain spaces.)

      xcodebuild test-without-building -xctestrun MyTestRun.xctestrun -destination 'platform=iOS Simulator,name=iPhone 5s' -destination 'platform=iOS,name=My iPad'

               Tests using both the iOS Simulator and the device named iPhone 5s.  Test bundle paths and other test parameters are specified in MyTestRun.xctestrun.  The command requires project binaries and does not require project source code.

      xcodebuild test -workspace MyWorkspace.xcworkspace -scheme MyScheme -destination 'platform=macOS,arch=x86_64'

               Tests the scheme MyScheme in the Xcode workspace MyWorkspace.xcworkspace using the destination described as My Mac 64-bit in Xcode.

      xcodebuild test -workspace MyWorkspace.xcworkspace -scheme MyScheme -destination 'platform=macOS,arch=x86_64' -only-testing MyTests/FooTests/testFooWithBar

               Tests the scheme MyScheme in the Xcode workspace MyWorkspace.xcworkspace using the destination described as My Mac 64-bit in Xcode. Only the test testFooWithBar of the test suite FooTests, part of the MyTests testing bundle target, will be run.

      xcodebuild -exportArchive -archivePath MyMobileApp.xcarchive -exportPath ExportDestination -exportOptionsPlist 'export.plist'

               Exports the archive MyMobileApp.xcarchive to the path ExportDestination using the options specified in export.plist.

      xcodebuild -exportLocalizations -project MyProject.xcodeproj -localizationPath MyDirectory -exportLanguage zh-hans -exportLanguage es-MX

               Exports two XLIFF files to MyDirectory from MyProject.xcodeproj containing development language strings and translations for Simplified Chinese and Mexican Spanish.

      xcodebuild -exportLocalizations -project MyProject.xcodeproj -localizationPath MyDirectory

               Export a single XLIFF file to MyDirectory from MyProject.xcodeproj containing only development language strings. (In this case, the -exportLanguage parameter has been excluded.)

      xcodebuild -importLocalizations -project MyProject.xcodeproj -localizationPath MyLocalizations.xliff

               Imports localizations from MyLocalizations.xliff into MyProject.xcodeproj.  Translations with issues will be reported but not imported.

 */
