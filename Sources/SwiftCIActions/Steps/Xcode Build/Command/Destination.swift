extension XcodeBuild.Destination {
    static func macOS(arch: XcodeBuild.Arch, variant: MacOSVariant? = nil) -> Self {
        Self(arch, variant)
    }

    private static func iOS(_ nameOrID: NameOrID) -> Self {
        Self(nameOrID)
    }

    static func iOS(name: String) -> Self {
        .iOS(.name(name))
    }

    static func iOS(id: String) -> Self {
        .iOS(.id(id))
    }

    private static func iOSSimulator(_ nameOrID: NameOrID, os: OS) -> Self {
        Self(nameOrID, os)
    }

    static func iOSSimulator(name: String, os: OS = .latest) -> Self {
        .iOSSimulator(.name(name), os: os)
    }

    static func iOSSimulator(id: String, os: OS = .latest) -> Self {
        .iOSSimulator(.id(id), os: os)
    }

    // TODO: Add destinations:
    // - watchOS
    // - watchOSSimulator
    // - tvOS
    // - tvOSSimulator
    // - driverKit
}

extension XcodeBuild {
    struct Destination: Option {
        var keyValues = [(String, String)]()

        var name: String { "-destination" }
        var argument: Argument {
            keyValues.map { "\($0)=\($1)" }.joined(separator: ",")
        }

        mutating func append(_ option: Option?) {
            if let option {
                keyValues.append((option.name, option.argument.argument))
            }
        }

        init(_ keyValues: [(String, String)]) {
            self.keyValues = keyValues
        }

        init(_ options: Option?...) {
            self = Destination([])
            for option in options {
                self.append(option)
            }
        }

        enum MacOSVariant: ExpressibleByStringLiteral, Option {
            case catalyst
            case macOS
            case other(String)

            var name: String { "variant" }
            var argument: Argument {
                switch self {
                case .macOS: return "macOS"
                case .catalyst: return "Mac Catalyst"
                case .other(let value): return value
                }
            }

            init(stringLiteral value: String) {
                self = .other(value)
            }
        }

        enum NameOrID: Option {
            case name(String)
            case id(String)

            var name: String {
                switch self {
                case .name: return "name"
                case .id: return "id"
                }
            }

            var argument: Argument {
                switch self {
                case .name(let name): return name
                case .id(let id): return id
                }
            }
        }

        enum OS: Option, ExpressibleByStringLiteral {
            case latest
            case other(String)

            var name: String { "OS" }
            var argument: Argument {
                switch self {
                case .latest: return "latest"
                case .other(let value): return value
                }
            }

            init(stringLiteral value: String) {
                self = .other(value)
            }
        }
    }
}

/*

 Destinations
   The -destination option takes as its argument a destination specifier describing the device (or devices) to use as a destination.  A destination specifier is a single argument consisting of a set of comma-separated key=value pairs.  The -destination option may be specified multiple
   times to cause xcodebuild to perform the specified action on multiple destinations.

   Destination specifiers may include the platform key to specify one of the supported destination platforms.  There are additional keys which should be supplied depending on the platform of the device you are selecting.

   Some devices may take time to look up. The -destination-timeout option can be used to specify the amount of time to wait before a device is considered unavailable.  If unspecified, the default timeout is 30 seconds.

   Currently, xcodebuild supports these platforms:

   macOS              The local Mac, referred to in the Xcode interface as My Mac, and which supports the following keys:

                      arch     The architecture to use, e.g.  arm64 or x86_64.

                      variant  The optional variant to use, e.g.  Mac Catalyst or macOS.

   iOS                An iOS device, which supports the following keys:

                      id    The identifier of the device to use, as shown in the Devices window. A valid destination specifier must provide either id or name, but not both.

                      name  The name of the device to use. A valid destination specifier must provide either id or name, but not both.

   iOS Simulator      A simulated iOS device, which supports the following keys:

                      id    The identifier of the simulated device to use, as shown in the Devices window. A valid destination specifier must provide either id or name, but not both.

                      name  The name of the simulated device to use. A valid destination specifier must provide either id or name, but not both.

                      OS    When specifying the simulated device by name, the iOS version for that simulated device, such as 6.0, or the string latest (the default) to indicate the most recent version of iOS supported by this version of Xcode.

   watchOS            A watchOS app is always built and deployed nested inside of an iOS app. To use a watchOS device as your destination, specify a scheme which is configured to run a WatchKit app, and specify the iOS platform destination that is paired with the watchOS device you want
                      to use.

   watchOS Simulator  A watchOS Simulator app is always built and deployed nested inside of an iOS Simulator app. To use a watchOS Simulator device as your destination, specify a scheme which is configured to run a WatchKit app, and specify the iOS Simulator platform destination that is
                      paired with the watchOS Simulator device you want to use.

   tvOS               A tvOS device, which supports the following keys:

                      id    The identifier of the device to use, as shown in the Devices window. A valid destination specifier must provide either id or name, but not both.

                      name  The name of the device to use. A valid destination specifier must provide either id or name, but not both.

   tvOS Simulator     A simulated tvOS device, which supports the following keys:

                      id    The identifier of the simulated device to use, as shown in the Devices window. A valid destination specifier must provide either id or name, but not both.

                      name  The name of the simulated device to use. A valid destination specifier must provide either id or name, but not both.

                      OS    When specifying the simulated device by name, the tvOS version for that simulated device, such as 9.0, or the string latest (the default) to indicate the most recent version of tvOS supported by this version of Xcode.

   DriverKit          The DriverKit environment, which supports the following key:

                      arch  The architecture to use, e.g.  arm64 or x86_64.

 */
