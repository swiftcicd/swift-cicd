// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "cicd",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "cicd", targets: ["cicd"])
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .executableTarget(name: "cicd", dependencies: [.product(name: "SwiftCI", package: "swift-ci")], path: ".")
    ]
)
