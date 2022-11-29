// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-ci",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SwiftCI", targets: ["SwiftCI"]),
        .executable(name: "Demo", targets: ["Demo"])
    ],
    dependencies: [
        .package(url: "https://github.com/clayellis/swift-arguments", branch: "main"),
        .package(url: "https://github.com/clayellis/swift-environment", branch: "main"),
        .package(url: "https://github.com/clayellis/swift-pr", branch: "main"),
        .package(url: "https://github.com/vapor/jwt-kit", from: "4.0.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
        .package(url: "https://github.com/nerdishbynature/octokit.swift", branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftCI",
            dependencies: [
                .product(name: "Arguments", package: "swift-arguments"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OctoKit", package: "octokit.swift"),
                .product(name: "ShellOut", package: "ShellOut"),
                .product(name: "SwiftEnvironment", package: "swift-environment"),
                .product(name: "SwiftPR", package: "swift-pr"),
            ]
        ),
        .testTarget(
            name: "SwiftCITests",
            dependencies: ["SwiftCI"]
        ),
        .executableTarget(name: "Demo", dependencies: ["SwiftCI"])
    ]
)
