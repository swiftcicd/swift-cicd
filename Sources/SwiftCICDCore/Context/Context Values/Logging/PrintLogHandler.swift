import Foundation
import Logging

struct PrintLogHandler: LogHandler {
    var label: String
    var logLevel: Logger.Level
    var metadata: Logger.Metadata
    var metadataProvider: Logger.MetadataProvider?

    init(label: String, logLevel: Logger.Level = .info, metadata: Logger.Metadata = .init(), metadataProvider: Logger.MetadataProvider? = nil) {
        self.label = label
        self.logLevel = logLevel
        self.metadata = metadata
        self.metadataProvider = metadataProvider
    }

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        var output = ""
        output.append("[\(level)]".padding(toLength: 11, withPad: " ", startingAt: 0))

        let timestamp = Date().formatted(Date.FormatStyle()
            .hour(.twoDigits(amPM: .abbreviated))
            .minute(.twoDigits)
            .second(.twoDigits)
            .secondFraction(.fractional(3))
        )

        output.append(timestamp)

        let metadata = mergeAllMetadata(logMetadata: metadata)
        if !metadata.isEmpty {
            output.append(" [\(metadata.map { key, value in "'\(key)': '\(value)'" }.joined(separator: ", "))]")
        }
        output.append(" - \(message)")
        print(output)
    }
}

extension LogHandler {
    /// Merges the metadata for this logger from three sources  (in order of priority):
    ///  1. `self.metadataProvider` any metadata available from this isntance's metadata provider.
    ///  2. `logMetadata` the explicit metadata passed into the log call.
    ///  3. `self.metadata` the metadata set on in this instance.
    /// - Parameter logMetadata: The explicit metadata passed into the log call.
    /// - Returns: The merged metadata from the three sources.
    func mergeAllMetadata(logMetadata: Logger.Metadata?) -> Logger.Metadata {
        self.metadata
            .merging(logMetadata ?? [:], uniquingKeysWith: { _, new in new })
            .merging(metadataProvider?.get() ?? [:], uniquingKeysWith: { _, new in new })
    }
}
