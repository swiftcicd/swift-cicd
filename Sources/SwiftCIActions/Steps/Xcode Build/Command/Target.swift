extension XcodeBuild {
    enum Target: ExpressibleByStringLiteral {
        /// Build the target specified by target name.
        case target(String)
        
        /// Build all the targets in the specified project.
        case allTargets

        init(stringLiteral value: String) {
            self = .target(value)
        }
    }
}
