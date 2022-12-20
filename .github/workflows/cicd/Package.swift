// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "cicd",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "cicd", targets: ["cicd"])
    ],
    dependencies: [
        .package(url: "https://github.com/clayellis/swift-ci", branch: "action")
    ],
    targets: [
        .executableTarget(name: "cicd", dependencies: [.product(name: "SwiftCI", package: "swift-ci")], path: ".")
    ]
)
