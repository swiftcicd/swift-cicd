# SwiftCICD

> Note: This project is in its very early stages. Feel free to use it and submit issues with questions or ideas. Pull requests may or may not be accepted while the basic infrastructure is still under active development. 

SwiftCI is a CI/CD scheme written in Swift that leverages the Swift ecosystem.

A basic SwiftCI setup looks like this:

> CICD.swift
> ```swift
> import SwiftCICD
> 
> @main
> struct CICD: MainAction {
>     func run() async throws {
>         let project = "MyProject.xcodeproj"
>         try await buildXcodeProject(project)
>         try await testXcodeProject(project, withoutBuilding: true)
>         let signingAssets = try await importSigningAssets(
>             appStoreConnectKeySecret: .init(keyID: "...", keyIssuerID: "...")
>         )
>         let upload = try await archiveExportUpload(
>             xcodeProject: project, 
>             profile: signingAssets.profile, 
>             appStoreConnectKey: signingAssets.appStoreConnectKey
>         )
>         logger.info("Uploaded build: \(upload.uploadedBuildNumber)")
>     }
> }
> ```

## Getting Started

_// TODO: Package.swift, directory structure, GitHub Action, etc._

## Overview

SwiftCI is composed of `Action`s, where actions have an `Output`. A specialized action, `MainAction`, acts as the entry-point to your CICD workflow. It can and should be decorated with the `@main` attribute.

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

If your action makes any changes to the system, it's good practice to implement the `cleanUp` method to revert those changes. SwiftCI will call your action's `cleanUp` method before it exits and after the main action finishes, either because of a successful run or an error. Actions will be be cleaned up in first-in-last-out order. The `cleanUp` method is optional, but again, it's good practice to clean up after your action if it makes any changes to the system.

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
