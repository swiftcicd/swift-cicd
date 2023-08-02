// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "cicd",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "cicd", targets: ["cicd"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftcicd/swift-cicd", branch: "main")
    ],
    targets: [
        .executableTarget(name: "cicd", dependencies: [.product(name: "SwiftCICD", package: "swift-cicd")], path: ".")
    ]
)
