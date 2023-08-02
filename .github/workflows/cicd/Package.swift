// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "cicd",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "cicd", targets: ["cicd"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftcicd/swift-cicd", branch: "namespaced-actions")
    ],
    targets: [
        .executableTarget(name: "cicd", dependencies: [.product(name: "SwiftCICD", package: "swift-cicd")], path: ".")
    ]
)
