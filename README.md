# SwiftCI

SwiftCI is a CI/CD scheme written in Swift that leverages the Swift ecosystem.

A basic SwiftCI setup looks like this:

> CICD.swift
> ```swift
> import SwiftCI
> 
> @main
> struct CICD: Workflow {
>     func run() async throws {
>         let project = "MyProject.xcodeproj"
>         try await buildAndTest(project: project)
>         try await archiveAndUploadToAppStore(project: project)
>     }
> }
> ```


## Getting Started

_// TODO: Package.swift, directory structure, GitHub Action, etc._

## Overview

SwiftCI has two main types: `Workflow` and `Step`. Workflows run steps or other workflows. Steps can run other steps, but not workflows. Steps return `Output`.

_// TODO: `Context`_

## First-Party Steps

_// TODO: Table of steps with a brief description_

## Developing Steps

You can create your own steps by making a type that conforms to the `Step` protocol.

```swift
struct CreateFile: Step {
    let path: String
    let contents: String
    
    func run() async throws {
        try context.fileManager.createFile(atPath: path, contents: Data(contents.utf8))
    }
}
```

If your step makes any changes to the system, it's good practice to implement the `cleanUp` method to revert those changes. SwiftCI will call your step's `cleanUp` method before it exits and after the workflow finishes, either because of a successful run or an error. Steps will be be cleaned up in first-in-last-out order. The `cleanUp` method is optional, but again, it's good practice to clean up after your step if it makes any changes to the system.

```swift
struct CreateFile: Step {
    ...
    
    func cleanUp(error: Error?) async throws {
        // CreateFile created a file, so we should clean up by deleting that file.
        try context.fileManager.removeItem(atPath: path)
    }
}
```

### Making Your Steps Discoverable

There are three main methods to make your custom steps discoverable. It is recommended to support all three when vending steps so that users can discover your step in any context.

**1. Add a `typealias` to the `Steps` namespace:**

```swift
extension Steps {
    public typealias MyStep = MyModule.MyStep
}

public struct MyStep: Step {
    let input: String
    
    public init(input: String) {...} 
}
```

This method enables users to discover your step using autocompletion when choosing a step to run:

```swift
try await step(Steps.MyStep(input: "hello"))
```

**2. Add your step using static member lookup:**

```swift
extension Step where Self == MyStep {
    public static func myStep(input: String) -> MyStep {
        MyStep(input: input)
    }
}
```

This method enables users to discover your step using autocompletion when invoking the `step(_:)` methods:

```swift
func run() async throws {
    try await step(.myStep(input: "hello"))
}
```

**3. Add a method to `StepRunner`:**

```swift
extension StepRunner {
    public func myStep(input: String) async throws -> MyStep.Output {
        try await step(MyStep(input: input))
    }
}
```

This method enables users to run your step directly from either another step or a workflow, without invoking their `step(_:)` methods:

```swift
func run() async throws {
    try await myStep(input: "hello")
}
```
