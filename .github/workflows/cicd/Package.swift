// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "cicd",
    products: [
        .executable(name: "cicd", targets: ["CICD"])
    ],
    dependencies: [
        .package(url: "https://github.com/clayellis/swift-ci", branch: "main")
    ],
    targets: [
        .executableTarget(name: "CICD", dependencies: [.product(name: "SwiftCI", package: "swift-ci")], path: ".")
    ]
)
