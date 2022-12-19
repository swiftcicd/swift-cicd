//import Foundation
//
//public protocol Step<Output>: StepRunner {
//    associatedtype Output
//    // TODO: Rename this stepName to avoid collision (name is a super common variable name and Step shouldn't steal/squat on it.)
//    // (Same goes for workflow name)
//    var name: String { get }
//    func run() async throws -> Output
//    func cleanUp(error: Error?) async throws
//}
//
//public extension Step {
//    var name: String {
//        "\(Self.self)"
//    }
//
//    func cleanUp(error: Error?) async throws {}
//}
//
//@propertyWrapper
//public struct StepState<T> {
//    private class Storage {
//        var state: T?
//    }
//
//    private let storage = Storage()
//
//    public init(wrappedValue: T? = nil) {
//        self.storage.state = wrappedValue
//    }
//
//    public var wrappedValue: T? {
//        get { storage.state }
//        nonmutating set { storage.state = newValue }
//    }
//}
//
//public struct StepError: LocalizedError, CustomStringConvertible {
//    let step: (any Step)?
//    let message: String
//    let error: Error?
//    let file: StaticString
//    let line: UInt
//
//    public init(
//        _ message: String,
//        step: (any Step)? = nil,
//        error: Error? = nil,
//        file: StaticString = #fileID,
//        line: UInt = #line
//    ) {
//        @Context(\.currentStep) var currentStep
//        self.step = step ?? currentStep
//        self.message = message
//        self.error = error
//        self.file = file
//        self.line = line
//    }
//
//    public var description: String {
//        var description = "Step Error (file: \(file), line: \(line))"
//        if let step {
//            description += "\nStep: \(step)"
//        }
//
//        if let error {
//            description += "\nError: \(error)"
//        }
//
//        description += "\nMessage: \(message)"
//
//        return description
//    }
//
//    public var errorDescription: String? {
//        description
//    }
//}
//
//public extension Step {
//    func StepError(_ message: String, error: Error? = nil, file: StaticString = #fileID, line: UInt = #line) -> StepError {
//        SwiftCI.StepError(message, step: self, error: error, file: file, line: line)
//    }
//}
