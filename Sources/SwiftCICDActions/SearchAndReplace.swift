import Foundation
import SwiftCICDCore

public struct SearchAndReplace: Action {
    public struct Output {
        let updatedFiles: [String]
    }

    let searchForAndReplaceWith: [String: String]
    let filePaths: [String]

    init(
        searchForAndReplaceWith: [String: String],
        filePaths: [String]
    ) {
        self.searchForAndReplaceWith = searchForAndReplaceWith
        self.filePaths = filePaths
    }

    public func run() async throws -> Output {
        var updatedFiles = [String]()
        for filePath in filePaths {
            try await updateFile(filePath) { (file: inout String) in
                for (occurrence, replacement) in searchForAndReplaceWith {
                    if file.contains(occurrence) {
                        file = file.replacingOccurrences(of: occurrence, with: replacement)
                        updatedFiles.append(filePath)
                    }
                }
            }
        }
        return Output(updatedFiles: updatedFiles)
    }

    public func cleanUp(error: Error?) async throws {
        // No-op. We're using the updateFile action which will automatically
        // clean up and revert any changes to the files.
    }
}

public extension Action {
    @discardableResult
    func searchForAndReplaceWith(
        _ replaceOccurrenceWith: [String: String],
        in filePaths: [String]
    ) async throws -> SearchAndReplace.Output {
        try await action(SearchAndReplace(
            searchForAndReplaceWith: replaceOccurrenceWith,
            filePaths: filePaths
        ))
    }

    @discardableResult
    func injectSecrets(
        byReplacingOccurrencesWithSecrets occurrencesAndSecrets: [String: Secret],
        in filePaths: [String]
    ) async throws -> SearchAndReplace.Output {
        let searchAndReplace = try await Dictionary(uniqueKeysWithValues: occurrencesAndSecrets.concurrentMap {
            try await ($0.key, $0.value.get().string)
        })

        return try await searchForAndReplaceWith(searchAndReplace, in: filePaths)
    }
}
