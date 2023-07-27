# SwiftCICD

> Note: This project is in its very early stages. Feel free to use it and submit issues with questions or ideas. Pull requests may or may not be accepted while the basic infrastructure is still under active development. 

SwiftCICD is a CI/CD scheme written in Swift that leverages the Swift ecosystem.

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

In order to get started with SwiftCICD using GitHub Actions, you'll first need to create your SwiftCICD executable. This is done by creating a new Swift Package which vends an executable target. Create a new directory at `.github/workflows/cicd`. 

> You can name and place your package wherever you want, but if you use `.github/workflows/cicd` you won't have to specify the `package-path` parameter later in your workflow file since that is the default value.

Once you've created your package's directory, create a package manifest:

> **.github/workflows/cicd/Package.swift**

```swift
// swift-tools-version: 5.9

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

Next, create a file in `.github/workflows/cicd` named `CICD.swift`. This is the file where you'll define your CICD actions. Let's get started by building and testing an Xcode project.

> **.github/workflows/cicd/CICD.swift**
```swift
import SwiftCICD

@main
struct CICD: MainAction {
    func run() async throws {
        let project = try context.workingDirectory/"GettingStarted.xcodeproj"

        try await buildXcodeProject(
            project,
            configuration: .debug,
            destination: .iOSSimulator
        )

        try await testXcodeProject(
            project,
            destination: .iOSSimulator,
            withoutBuilding: true
        )
    }
}
```

In this CICD file we define a main action named `CICD`. When it runs, it will build and then test the "GettingStarted" Xcode project found in the working directory of the workflow. This will be the root directory of your repo. You should provide the path to your own Xcode project.

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

## Overview

SwiftCICD is composed of `Action`s, where actions have an `Output`. A specialized action, `MainAction`, acts as the entry-point to your CICD workflow. It can and should be decorated with the `@main` attribute.

_// TODO: `Context`_

## First-Party Actions

_// TODO: Table of actions with a brief description_

## Developing Actions

You can create your own actions by making a type that conforms to the `Action` protocol.

```swift
struct CreateFile: Action {
    let path: String
    let contents: String
    
    func run() async throws {
        try context.fileManager.createFile(atPath: path, contents: Data(contents.utf8))
    }
}
```

If your action makes any changes to the system, it's good practice to implement the `cleanUp` method to revert those changes. SwiftCICD will call your action's `cleanUp` method before it exits and after the main action finishes, either because of a successful run or an error. Actions will be be cleaned up in first-in-last-out order. The `cleanUp` method is optional, but again, it's good practice to clean up after your action if it makes any changes to the system.

```swift
struct CreateFile: Action {
    ...
    
    func cleanUp(error: Error?) async throws {
        // CreateFile created a file, so we should clean up by deleting that file.
        try context.fileManager.removeItem(atPath: path)
    }
}
```

### Making Your Actions Ergonomic

Actions can run other actions by invoking the `action(_:)` method. You can make your actions more ergonomic by extending `Action` and adding a method that takes the same parameters and returns the same output as your action, which invokes your action, like so:

> Note: This action doesn't have any output (its `Output` is `Void`)

```swift
extension Action {
    func createFile(path: String, contents: String) async throws {
        try await action(CreateFile(path: path, contents: contents))
    }
}
```
