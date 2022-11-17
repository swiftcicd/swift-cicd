extension XcodeBuild {
    enum Action: String {
        /// Build the target in the build root (SYMROOT).  This is the default action, and is used if no action is given.
        case build

        /// Build the target and associated tests in the build root (SYMROOT).
        /// This will also produce an xctestrun file in the build root. This requires specifying a scheme.
        case buildForTesting = "build-for-testing"

        /// Build and analyze a target or scheme from the build root (SYMROOT).  This requires specifying a scheme.
        case analyze

        /// Archive a scheme from the build root (SYMROOT).  This requires specifying a scheme.
        case archive

        /// Test a scheme from the build root (SYMROOT).  This requires specifying a scheme and optionally a destination.
        case test

        /// Test compiled bundles. If a scheme is provided with -scheme then the command finds bundles in the build root (SRCROOT).
        /// If an xctestrun file is provided with -xctestrun then the command finds bundles at paths specified in the xctestrun file.
        case testWithoutBuilding = "test-without-building"

        /// Build the target and associated documentation in the build root (SRCROOT).
        case docbuild

        /// Copy the source of the project to the source root (SRCROOT).
        case installsrc

        /// Build the target and install it into the target's installation directory in the distribution root (DSTROOT).
        case install

        /// Remove build products and intermediate files from the build root (SYMROOT).
        case clean
    }
}
