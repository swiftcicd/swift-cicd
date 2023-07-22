// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-cicd",
    defaultLocalization: "en-uS",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SwiftCICD", targets: ["SwiftCICD"]),
        .library(name: "SwiftCICDCore", targets: ["SwiftCICDCore"]),
        .library(name: "SwiftCICDActions", targets: ["SwiftCICDActions"]),
        .library(name: "SwiftCICDPlatforms", targets: ["SwiftCICDPlatforms"]),
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
            name: "SwiftCICD",
            dependencies: [
                .target(name: "SwiftCICDActions"),
                .target(name: "SwiftCICDCore"),
                .target(name: "SwiftCICDPlatforms")
            ]
       ),
        .target(
            name: "SwiftCICDActions",
            dependencies: [
                .target(name: "SwiftCICDCore"),
                .target(name: "SwiftCICDPlatforms"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "OctoKit", package: "octokit.swift"),
                .product(name: "SwiftPR", package: "swift-pr"),
            ]
        ),
        .target(
            name: "SwiftCICDCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftEnvironment", package: "swift-environment"),
            ]
        ),
        .target(
            name: "SwiftCICDPlatforms",
            dependencies: [
                .target(name: "SwiftCICDCore"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OctoKit", package: "octokit.swift"),
                .product(name: "SwiftEnvironment", package: "swift-environment"),
            ]
        ),
        .testTarget(
            name: "SwiftCICDTests",
            dependencies: ["SwiftCICD"]
        ),
        .executableTarget(
            name: "Demo",
            dependencies: [
                .target(name: "SwiftCICD"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
