import Foundation
import SwiftCICDCore
import SwiftCICDPlatforms

public struct UploadGitHubActionArtifact: Action {
    let artifactURL: URL
    let artifactName: String
    let itemPath: String
    @State var zippedArtifactURL: URL?

    private var artifactsBaseURL: URL {
        get throws {
            let url = try context.environment.github.$runtimeURL.require()
            let runID = try context.environment.github.$runID.require()
            return url.appendingCompat("_apis/pipelines/workflows/\(runID)/artifacts?api-version=6.0-preview")
        }
    }

    init(artifact: URL, name: String? = nil) throws {
        self.artifactURL = artifact
        self.artifactName = name ?? artifact.lastPathComponent
        self.itemPath = "\(self.artifactName)/\(artifact.lastPathComponent)"
    }

    // TODO: Determine what useful output would be. The returned url isn't suitable for downloads (access permission is denied.)

    public struct Output {
        public let containerID: Int
        public let name: String
        public let url: URL
    }

    private struct Chunk {
        let data: Data
        let byteRange: Range<Int>
        let totalBytes: Int

        var contentRange: String {
            // https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/utils.ts#L118
            "bytes \(byteRange.lowerBound)-\(byteRange.upperBound - 1)/\(totalBytes)"
        }
    }

    public func run() async throws -> Output {
        logger.info("Preparing to upload \(artifactURL.filePath) as GitHub artifact named \(artifactName)")

        var artifactURL = self.artifactURL
        var itemPath = self.itemPath

        var isZipped = false
        var isDirectory = ObjCBool(false)
        if context.fileManager.fileExists(atPath: artifactURL.filePath, isDirectory: &isDirectory), isDirectory.boolValue {
            logger.info("Artifact is a directory. Zipping...")
            artifactURL = try context.fileManager.zip(artifactURL)
            zippedArtifactURL = artifactURL
            itemPath = itemPath + ".zip"
            isZipped = true
        }

        logger.info("Artifact will be placed at \(itemPath)")
        guard let totalBytes = try context.fileManager.attributesOfItem(atPath: artifactURL.filePath)[.size] as? Int else {
            throw ActionError("Couldn't determine the size of the artifact at: \(artifactURL.filePath)")
        }

        // TODO: Mimic the logic outlined in this diagram:
        // https://github.com/actions/toolkit/blob/main/packages/artifact/docs/implementation-details.md#uploadcompression-flow

        logger.info("Artifact size is \(totalBytes) bytes")

        guard let stream = InputStream(url: artifactURL) else {
            throw ActionError("Failed to open InputStream to artifact at: \(artifactURL.filePath)")
        }

        // Step 1: Create the artifact container
        logger.info("Creating artifact container")
        let fileContainerResourceURL = try await createArtifactContainer(named: artifactName)

        // Step 2: Chunk up the artifact into 4MB pieces and upload them
        logger.info("Chunking artifact")
        // The GitHub @actions/upload-artifact action uploads in chunks of 4MB
        // https://github.com/actions/toolkit/blob/main/packages/artifact/docs/implementation-details.md#uploadcompression-flow
        let chunkSizeInBytes = Int(Measurement(value: 4, unit: UnitInformationStorage.megabytes).converted(to: .bytes).value)
        var buffer = [UInt8](repeating: 0, count: chunkSizeInBytes)
        var offset = 0
        stream.open()
        streamLoop: while true {
            logger.info("Reading next chunk")
            let amount = stream.read(&buffer, maxLength: chunkSizeInBytes)
            switch amount {
            case 0:
                // End of stream
                logger.info("Read to end of artifact stream")
                break streamLoop
            case -1:
                // An error occurred
                logger.error("An error occurred while reading artifact stream")
                throw ActionError("An error occurred while reading the artifact at: \(artifactURL)", error: stream.streamError)
            default:
                // Read bytes
                logger.info("Read chunk: \(amount) bytes")
                let chunk = Chunk(data: Data(buffer[..<amount]), byteRange: offset..<offset+amount, totalBytes: totalBytes)
                offset += amount
                logger.info("Uploading chunk: \(chunk.contentRange)")
                try await uploadChunk(chunk, isZipped: isZipped, toArtifactContainer: fileContainerResourceURL, itemPath: itemPath)
            }
        }
        stream.close()

        // Step 3: Finalize the artifact upload
        logger.info("Finalizing artifact upload")
        let upload = try await finalizeArtifactUpload(named: artifactName, totalBytes: totalBytes)

        let output = Output(
            containerID: upload.containerId,
            name: upload.name,
            url: upload.url
        )

        logger.info("Successfully uploaded artifact (id: \(upload.containerId)). It can be found at: \(output.url)")
        return output
    }

    private func request(method: String, url: URL, contentType: String, bodyData: Data?) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json;api-version=6.0-preview", forHTTPHeaderField: "Accept")
        let token = try context.environment.github.$runtimeToken.require()
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        return request
    }

    private func request(method: String, url: URL, contentType: String, body: (any Encodable)?) throws -> URLRequest {
        let data = try body.map { try JSONEncoder().encode($0) }
        return try request(method: method, url: url, contentType: contentType, bodyData: data)
    }

    /// Reference: https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-http-client.ts#L101
    private func createArtifactContainer(named name: String) async throws -> URL {
        struct Body: Encodable {
            let type = "actions_storage"
            let name: String
        }

        struct Response: Decodable {
            let fileContainerResourceUrl: URL
        }

        let body = Body(name: name)
        let request = try request(method: "POST", url: artifactsBaseURL, contentType: "application/json", body: body)
        let data = try await validate(URLSession.shared.data(for: request))
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.fileContainerResourceUrl
    }

    /// Reference: https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-http-client.ts#L421
    private func uploadChunk(_ chunk: Chunk, isZipped: Bool, toArtifactContainer url: URL, itemPath: String) async throws {
        let url = url.appendingQueryItemsCompat([URLQueryItem(name: "itemPath", value: itemPath)])
        var request = try request(method: "PUT", url: url, contentType: "application/octet-stream", bodyData: nil)
        request.addValue(chunk.contentRange, forHTTPHeaderField: "Content-Range")
        if isZipped {
            request.addValue("zip", forHTTPHeaderField: "Content-Encoding")
//            // TODO: Do we need to add this header?
//            requestOptions['x-tfs-filelength'] = uncompressedLength
        }
        try await validate(URLSession.shared.upload(for: request, from: chunk.data))
    }

    private struct FinalizeArtifactUploadResponse: Decodable {
        let containerId: Int
        let name: String
        let url: URL
    }

    /// Reference: https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-http-client.ts#L542
    private func finalizeArtifactUpload(named artifactName: String, totalBytes: Int) async throws -> FinalizeArtifactUploadResponse {
        struct Body: Encodable {
            let size: Int
        }

        let url = try artifactsBaseURL.appendingQueryItemsCompat([URLQueryItem(name: "artifactName", value: artifactName)])
        let body = Body(size: totalBytes)
        let request = try request(method: "PATCH", url: url, contentType: "application/json", body: body)
        let data = try await validate(URLSession.shared.data(for: request))
        let response = try JSONDecoder().decode(FinalizeArtifactUploadResponse.self, from: data)
        return response
    }

    private struct InvalidStatusCode: Error {
        let statusCode: Int
        let expectedRange: ClosedRange<Int>
    }

    private func validate(data: Data, response: URLResponse, statusCodeIn validRange: ClosedRange<Int> = 200...299) throws -> Data {
        let httpResponse = response as! HTTPURLResponse
        guard validRange.contains(httpResponse.statusCode) else {
            logger.error("Invalid status code \(httpResponse.statusCode), expected \(validRange.lowerBound)...\(validRange.upperBound).")
            logger.error("Response body:\n\(data.string)")
            throw InvalidStatusCode(statusCode: httpResponse.statusCode, expectedRange: validRange)
        }
        return data
    }

    @discardableResult
    private func validate(_ tuple: (data: Data, response: URLResponse)) throws -> Data {
        try validate(data: tuple.data, response: tuple.response, statusCodeIn: 200...299)
    }

    public func cleanUp(error: Error?) async throws {
        guard let zippedArtifactURL else {
            return
        }

        try context.fileManager.removeItem(at: zippedArtifactURL)
    }
}

public extension GitHub {
    @discardableResult
    func uploadActionArtifact(_ artifactURL: URL, named artifactName: String? = nil) async throws -> UploadGitHubActionArtifact.Output {
        try await run(UploadGitHubActionArtifact(artifact: artifactURL, name: artifactName))
    }
}

extension FileManager {
    func zip(_ source: URL, into outputDirectory: URL? = nil) throws -> URL {
        let source = source.fileURL
        let output = (outputDirectory ?? temporaryDirectory)
            .appendingCompat(source.lastPathComponent)
            .appendingPathExtension("zip")
            .fileURL

        if fileExists(atPath: output.filePath) {
            try removeItem(at: output)
        }

        let readURL: URL
        let isReadURLTemporary: Bool
        var isDir: ObjCBool = false
        if fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue {
            readURL = source.fileURL
            isReadURLTemporary = false
        } else {
            let temp = temporaryDirectory.appendingCompat(UUID().uuidString)
            try createDirectory(at: temp, withIntermediateDirectories: true)
            let copy = temp.appendingCompat(source.lastPathComponent).fileURL
            try copyItem(at: source, to: copy)
            readURL = copy
            isReadURLTemporary = true
        }

        let coordinator = NSFileCoordinator()
        var readError: NSError?
        var copyError: NSError?

        coordinator.coordinate(readingItemAt: readURL, options: .forUploading, error: &readError) { zip in
            do {
                try copyItem(at: zip, to: output)
            } catch {
                copyError = error as NSError
            }
        }

        if let readError {
            throw ActionError("Failed to read item at \(source.path)", error: readError)
        }

        if let copyError {
            throw ActionError("Failed to copy zipped output into destination", error: copyError)
        }

        if isReadURLTemporary {
            try removeItem(at: readURL)
        }

        return output
    }
}
