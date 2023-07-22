// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-ci",
    defaultLocalization: "en-uS",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SwiftCI", targets: ["SwiftCI"]),
        .library(name: "SwiftCICore", targets: ["SwiftCICore"]),
        .library(name: "SwiftCIActions", targets: ["SwiftCIActions"]),
        .library(name: "SwiftCIPlatforms", targets: ["SwiftCIPlatforms"]),
        .executable(name: "Demo", targets: ["Demo"])
    ],
    dependencies: [
        .package(url: "https://github.com/clayellis/swift-environment", branch: "main"),
        .package(url: "https://github.com/clayellis/swift-pr", branch: "main"),
        .package(url: "https://github.com/vapor/jwt-kit", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
        .package(url: "https://github.com/nerdishbynature/octokit.swift", branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftCI",
            dependencies: [
                .target(name: "SwiftCIActions"),
                .target(name: "SwiftCICore"),
                .target(name: "SwiftCIPlatforms")
            ]
       ),
        .target(
            name: "SwiftCIActions",
            dependencies: [
                .target(name: "SwiftCICore"),
                .target(name: "SwiftCIPlatforms"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "OctoKit", package: "octokit.swift"),
                .product(name: "SwiftPR", package: "swift-pr"),
            ]
        ),
        .target(
            name: "SwiftCICore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftEnvironment", package: "swift-environment"),
            ]
        ),
        .target(
            name: "SwiftCIPlatforms",
            dependencies: [
                .target(name: "SwiftCICore"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OctoKit", package: "octokit.swift"),
                .product(name: "SwiftEnvironment", package: "swift-environment"),
            ]
        ),
        .testTarget(
            name: "SwiftCITests",
            dependencies: ["SwiftCI"]
        ),
        .executableTarget(
            name: "Demo",
            dependencies: [
                .target(name: "SwiftCI"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
