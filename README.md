# SwiftCICD

> Note: This project is in its very early stages. Feel free to use it and submit issues with questions or ideas. Pull requests may or may not be accepted while the basic infrastructure is still under active development. 

SwiftCICD is a CI/CD scheme written in Swift that leverages the Swift ecosystem. It is designed to run on different CICD platforms. The only supported platform currently is GitHub Actions. Support for other platforms will be added in the future.

## Getting Started

### GitHub Actions

> This guide assumes that you are familiar with the basics of GitHub Actions. If you're new to GitHub Actions, you can learn about them [here](https://docs.github.com/actions).

By the end of this guide, you should have a directory structure that looks like this:

```
.github/workflows/
├─ cicd/
│  ├─ Package.swift
│  ├─ CICD.swift
├─ cicd.yml
```   

#### 1. Swift Package

In order to get started with SwiftCICD using GitHub Actions, you'll first need to create your SwiftCICD executable. This is done by creating a new Swift Package which vends an executable target. Create a new directory at `.github/workflows/cicd`. 

> You can name and place your package wherever you want, but if you use `.github/workflows/cicd` you won't have to specify the `package-path` parameter later in your workflow file since that is the default value.

Once you've created your package's directory, create the package with an empty manifest by running:

```
cd .github/workflows/cicd
swift package init --type empty
```

Then paste the following into the package manifest:

> **.github/workflows/cicd/Package.swift**

```swift
// swift-tools-version: 5.7

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
        .executableTarget(
            name: "cicd",
            dependencies: [.product(name: "SwiftCICD", package: "swift-cicd")],
            path: "."
        )
    ]
)
```

This package manifest creates a new pacakge named `cicd` and vends an executable product (also named `cicd`.) The executable target depends on `SwiftCICD` from the `swift-cicd` package. Note that by specifying `"."` as the `path` parameter of the executable target, we are able remove an additional layer of directory structure. In doing so, the sources for the executable can be placed in the same directory as the package manifest itself.

#### 2. Executable CICD File

Next, create a file in `.github/workflows/cicd` named `CICD.swift`. This is the file where you'll define your CICD actions. Let's get started by building and testing an Xcode project.

> **.github/workflows/cicd/CICD.swift**
```swift
import SwiftCICD

@main
struct CICD: MainAction {
    func run() async throws {
        let project = try context.workingDirectory/"GettingStarted.xcodeproj"

        try await xcode.build(
            project: project,
            configuration: .debug,
            destination: .iOSSimulator
        )

        try await xcode.test(
            project: project,
            destination: .iOSSimulator,
            withoutBuilding: true
        )
    }
}
```

In this CICD file we define a main action named `CICD`. When it runs, it will build and then test the "GettingStarted" Xcode project found in the working directory of the workflow. This will be the root directory of your repo. You should provide the path to your own Xcode project.

#### 3. GitHub Action Workflow

Lastly, in order to run SwiftCICD, you'll need to create a workflow. Create a file named `cicd.yml` (you can name your workflow file whatever you want) and place it in the `.github/workflows/` directory. Your workflow triggers will likely vary depending on what actions you want to take and when. But for the sake of simplicity in this guide, we'll trigger the workflow whenever a new commit is pushed to `main`. 


> **.github/workflows/cicd.yml**
```yaml
name: CI/CD

on:
  push:
    branches: main

jobs:
  swift-cicd:
    name: SwiftCICD
    runs-on: macos-13
    steps:
    - uses: actions/checkout@v3
    - uses: swiftcicd/github-action@main
```

This workflow file has two steps that use pre-built actions. The first step checks out the repo. The second step (`- uses: swiftcicd/github-action@main`) runs SwiftCICD. This action has an input parameter `package-path` which is the path to the directory containing your SwiftCICD executable (the directory which contains your `Package.swift`).

With that, whenever a new commit is pushed to `main`, GitHub Actions will run your SwiftCICD action which builds and tests the Xcode project. There's a lot more that you can do with SwiftCICD like importing signing assets and uploading release builds to App Store Connect, and on. Feel free to explore the built-in actions in [`Sources/SwiftCICDActions/`](/Sources/SwiftCICDActions/). 
