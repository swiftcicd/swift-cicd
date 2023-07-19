import Foundation
import SwiftCICore
import SwiftCIPlatforms

// The following steps are outlined in this comment:
// https://github.com/actions/upload-artifact/issues/180#issuecomment-1086306269
//
// - Step 1: There is a HTTP POST call to create the artifact container:
//  https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-http-client.ts#L101
//
// - Step 2: Then multiple PUT calls to actually upload the content:
//  https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-http-client.ts#L421
//
// - Step 3: Followed by a PATCH call to finalize the artifact upload:
//  https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-http-client.ts#L542

// TODO: Mimic the logic outlined in this diagram:
// https://github.com/actions/toolkit/blob/main/packages/artifact/docs/implementation-details.md#uploadcompression-flow

/*

 https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/contracts.ts
 export interface ArtifactResponse {
   containerId: string
   size: number
   signedContent: string
   fileContainerResourceUrl: string
   type: string
   name: string
   url: string
 }

 export interface CreateArtifactParameters {
   Type: string
   Name: string
   RetentionDays?: number
 }

 export interface PatchArtifactSize {
   Size: number
 }

 export interface PatchArtifactSizeSuccessResponse {
   containerId: number
   size: number
   signedContent: string
   type: string
   name: string
   url: string
   uploadUrl: string
 }

 export interface UploadResults {
   /**
    * The size in bytes of data that was transferred during the upload process to the actions backend service. This takes into account possible
    * gzip compression to reduce the amount of data that needs to be transferred
    */
   uploadSize: number

   /**
    * The raw size of the files that were specified for upload
    */
   totalSize: number

   /**
    * An array of files that failed to upload
    */
   failedItems: string[]
 }

 export interface ListArtifactsResponse {
   count: number
   value: ArtifactResponse[]
 }

 export interface QueryArtifactResponse {
   count: number
   value: ContainerEntry[]
 }

 export interface ContainerEntry {
   containerId: number
   scopeIdentifier: string
   path: string
   itemType: string
   status: string
   fileLength?: number
   fileEncoding?: number
   fileType?: number
   dateCreated: string
   dateLastModified: string
   createdBy: string
   lastModifiedBy: string
   itemLocation: string
   contentLocation: string
   fileId?: number
   contentId: string
 }

 https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/upload-response.ts
 export interface UploadResponse {
   /**
    * The name of the artifact that was uploaded
    */
   artifactName: string

   /**
    * A list of all items that are meant to be uploaded as part of the artifact
    */
   artifactItems: string[]

   /**
    * Total size of the artifact in bytes that was uploaded
    */
   size: number

   /**
    * A list of items that were not uploaded as part of the artifact (includes queued items that were not uploaded if
    * continueOnError is set to false). This is a subset of artifactItems.
    */
   failedItems: string[]
 }
 */


public struct UploadGitHubArtifact: Action {

    let artifactURL: URL
    let artifactName: String
    let itemPath: String
    @State var zippedArtifactURL: URL?

    private var artifactsBaseURL: URL {
        get throws {
            // FIXME: ACTIONS_RUNTIME_URL is missing
            // FIXME: ACTIONS_RUNTIME_TOKEN is missing
            let url = try context.environment.github.$runtimeURL.require()
            let runID = try context.environment.github.$runID.require()
            return url.appending("_apis/pipelines/workflows/\(runID)/artifacts?api-version=6.0-preview")
        }
    }

    public init(artifact: URL, name: String? = nil, itemPath: String) throws {
        self.artifactURL = artifact
        self.artifactName = name ?? artifact.deletingPathExtension().lastPathComponent
        self.itemPath = itemPath
    }

    private struct Chunk {//}: CustomDebugStringConvertible {
        let data: Data
//        let isZipped: Bool
        let byteRange: Range<Int>
        let totalBytes: Int

        var contentRange: String {
//        https://github.com/actions/toolkit/blob/03eca1b0c77c26d3eaa0a4e9c1583d6e32b87f6f/packages/artifact/src/internal/utils.ts#L118
//            export function getContentRange(
//              start: number,
//              end: number,
//              total: number
//            ): string {
//              // Format: `bytes start-end/fileSize
//              // start and end are inclusive
//              // For a 200 byte chunk starting at byte 0:
//              // Content-Range: bytes 0-199/200
//              return `bytes ${start}-${end}/${total}`
//            }
            "bytes \(byteRange.lowerBound)-\(byteRange.upperBound - 1)/\(totalBytes)"
        }

//        var debugDescription: String {
//            "\(self) - (Content-Range: \(contentRange))"
//        }
    }

    public func run() async throws -> Void {
        var artifactURL = self.artifactURL

        var isZipped = false
        var isDirectory = ObjCBool(false)
        if context.fileManager.fileExists(atPath: artifactURL.filePath, isDirectory: &isDirectory), isDirectory.boolValue {
            logger.info("Artifact is a directory. Zipping...")
            let zip = try context.fileManager.zip(artifactURL)
            zippedArtifactURL = zip
            artifactURL = zip
            isZipped = true
        }

        guard let totalBytes = try context.fileManager.attributesOfItem(atPath: artifactURL.filePath)[.size] as? Int else {
            throw ActionError("Couldn't determine the size of the artifact at: \(artifactURL.filePath)")
        }

        logger.info("Artifact is \(totalBytes) bytes large")

        guard let stream = InputStream(url: artifactURL) else {
            throw ActionError("Failed to open InputStream to artifact at: \(artifactURL.filePath)")
        }

        // Step 1: Create the artifact container
        logger.info("Creating artifact container")
        let fileContainerResourceURL = try await createArtifactContainer()

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


                // This worked a couple times until I added isZipped to chunk and the debugDescription


//                Data(buffer[..<amount])
//                Data(bytes: buffer, count: buffer.count)
                let chunk = Chunk(data: Data(buffer[..<amount]), byteRange: offset..<offset+amount, totalBytes: totalBytes)
                offset += amount
                logger.info("Uploading chunk: \(chunk.contentRange)")
                try await uploadChunk(chunk, toArtifactContainer: fileContainerResourceURL, itemPath: itemPath)
            }
        }
        stream.close()

        // Step 3: Finalize the artifact upload
        logger.info("Finalizing artifact upload")
        try await finalizeArtifactUpload(totalBytes: totalBytes)
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

    private func createArtifactContainer() async throws -> URL {
        struct Body: Encodable {
            let type = "actions_storage"
            let name: String
        }

        struct Response: Decodable {
            let fileContainerResourceUrl: URL
        }

        let body = Body(name: "'\"\(artifactName)\"'")
        let request = try request(method: "POST", url: artifactsBaseURL, contentType: "application/json", body: body)
        let data = try await validate(URLSession.shared.data(for: request))
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.fileContainerResourceUrl
    }

    private func uploadChunk(_ chunk: Chunk, toArtifactContainer url: URL, itemPath: String) async throws {
        let url = url.appendingQueryItems([URLQueryItem(name: "itemPath", value: itemPath)])
        var request = try request(method: "PUT", url: url, contentType: "application/octet-stream", bodyData: nil)
        request.addValue(chunk.contentRange, forHTTPHeaderField: "Content-Range")
//        if chunk.isZipped {
//            request.addValue("zip", forHTTPHeaderField: "Content-Encoding")
//            // TODO: Do we need to add this header?
////            requestOptions['x-tfs-filelength'] = uncompressedLength
//        }
        try await validate(URLSession.shared.upload(for: request, from: chunk.data))
    }

    private func finalizeArtifactUpload(totalBytes: Int) async throws {
        struct Body: Encodable {
            let size: Int
        }

        let url = try artifactsBaseURL.appendingQueryItems([URLQueryItem(name: "artifactName", value: artifactName)])
        let body = Body(size: totalBytes)
        let request = try request(method: "PATCH", url: url, contentType: "application/json", body: body)
        try await validate(URLSession.shared.data(for: request))
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

public extension Action {
    func uploadGitHubArtifact(at artifactURL: URL, named artifactName: String? = nil, itemPath: String) async throws {
        try await action(UploadGitHubArtifact(artifact: artifactURL, name: artifactName, itemPath: itemPath))
    }
}

fileprivate extension URL {
    mutating func append(_ path: String) {
        if #available(macOS 13.0, *) {
            self.append(path: path)
        } else {
            self.appendPathComponent(path)
        }
    }

    func appending(_ path: String) -> URL {
        var copy = self
        copy.append(path)
        return copy
    }

    mutating func appendQueryItems(_ items: [URLQueryItem]) {
        if #available(macOS 13.0, *) {
            self.append(queryItems: items)
        } else {
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
            var queryItems = components.queryItems ?? []
            queryItems.append(contentsOf: items)
            self = components.url!
        }
    }

    func appendingQueryItems(_ items: [URLQueryItem]) -> URL {
        var copy = self
        copy.appendQueryItems(items)
        return copy
    }

    var fileURL: URL {
        guard !isFileURL else {
            return self
        }

        if #available(macOS 13.0, *) {
            return URL(filePath: self.path(), directoryHint: .checkFileSystem, relativeTo: nil)
        } else {
            return URL(fileURLWithPath: self.path)
        }
    }

    var filePath: String {
        if #available(macOS 13.0, *) {
            return self.path()
        } else {
            return self.path
        }
    }
}

extension FileManager {
    func zip(_ source: URL, into outputDirectory: URL? = nil) throws -> URL {
        let source = source.fileURL
        let output = (outputDirectory ?? temporaryDirectory)
            .appending(source.lastPathComponent)
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
            let temp = temporaryDirectory.appending(UUID().uuidString)
            try createDirectory(at: temp, withIntermediateDirectories: true)
            let copy = temp.appending(source.lastPathComponent).fileURL
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


/*

 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.create = void 0;
 const artifact_client_1 = __nccwpck_require__(8802);
 /**
  * Constructs an ArtifactClient
  */
 function create() {
     return artifact_client_1.DefaultArtifactClient.create();
 }
 exports.create = create;
 //# sourceMappingURL=artifact-client.js.map

 /***/ }),

 /***/ 8802:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
     function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
     return new (P || (P = Promise))(function (resolve, reject) {
         function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
         function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
         function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
         step((generator = generator.apply(thisArg, _arguments || [])).next());
     });
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.DefaultArtifactClient = void 0;
 const core = __importStar(__nccwpck_require__(2186));
 const upload_specification_1 = __nccwpck_require__(183);
 const upload_http_client_1 = __nccwpck_require__(4354);
 const utils_1 = __nccwpck_require__(6327);
 const path_and_artifact_name_validation_1 = __nccwpck_require__(7398);
 const download_http_client_1 = __nccwpck_require__(8538);
 const download_specification_1 = __nccwpck_require__(5686);
 const config_variables_1 = __nccwpck_require__(2222);
 const path_1 = __nccwpck_require__(1017);
 class DefaultArtifactClient {
     /**
      * Constructs a DefaultArtifactClient
      */
     static create() {
         return new DefaultArtifactClient();
     }
     /**
      * Uploads an artifact
      */
     uploadArtifact(name, files, rootDirectory, options) {
         return __awaiter(this, void 0, void 0, function* () {
             core.info(`Starting artifact upload
 For more detailed logs during the artifact upload process, enable step-debugging: https://docs.github.com/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging#enabling-step-debug-logging`);
             path_and_artifact_name_validation_1.checkArtifactName(name);
             // Get specification for the files being uploaded
             const uploadSpecification = upload_specification_1.getUploadSpecification(name, rootDirectory, files);
             const uploadResponse = {
                 artifactName: name,
                 artifactItems: [],
                 size: 0,
                 failedItems: []
             };
             const uploadHttpClient = new upload_http_client_1.UploadHttpClient();
             if (uploadSpecification.length === 0) {
                 core.warning(`No files found that can be uploaded`);
             }
             else {
                 // Create an entry for the artifact in the file container
                 const response = yield uploadHttpClient.createArtifactInFileContainer(name, options);
                 if (!response.fileContainerResourceUrl) {
                     core.debug(response.toString());
                     throw new Error('No URL provided by the Artifact Service to upload an artifact to');
                 }
                 core.debug(`Upload Resource URL: ${response.fileContainerResourceUrl}`);
                 core.info(`Container for artifact "${name}" successfully created. Starting upload of file(s)`);
                 // Upload each of the files that were found concurrently
                 const uploadResult = yield uploadHttpClient.uploadArtifactToFileContainer(response.fileContainerResourceUrl, uploadSpecification, options);
                 // Update the size of the artifact to indicate we are done uploading
                 // The uncompressed size is used for display when downloading a zip of the artifact from the UI
                 core.info(`File upload process has finished. Finalizing the artifact upload`);
                 yield uploadHttpClient.patchArtifactSize(uploadResult.totalSize, name);
                 if (uploadResult.failedItems.length > 0) {
                     core.info(`Upload finished. There were ${uploadResult.failedItems.length} items that failed to upload`);
                 }
                 else {
                     core.info(`Artifact has been finalized. All files have been successfully uploaded!`);
                 }
                 core.info(`
 The raw size of all the files that were specified for upload is ${uploadResult.totalSize} bytes
 The size of all the files that were uploaded is ${uploadResult.uploadSize} bytes. This takes into account any gzip compression used to reduce the upload size, time and storage

 Note: The size of downloaded zips can differ significantly from the reported size. For more information see: https://github.com/actions/upload-artifact#zipped-artifact-downloads \r\n`);
                 uploadResponse.artifactItems = uploadSpecification.map(item => item.absoluteFilePath);
                 uploadResponse.size = uploadResult.uploadSize;
                 uploadResponse.failedItems = uploadResult.failedItems;
             }
             return uploadResponse;
         });
     }
     downloadArtifact(name, path, options) {
         return __awaiter(this, void 0, void 0, function* () {
             const downloadHttpClient = new download_http_client_1.DownloadHttpClient();
             const artifacts = yield downloadHttpClient.listArtifacts();
             if (artifacts.count === 0) {
                 throw new Error(`Unable to find any artifacts for the associated workflow`);
             }
             const artifactToDownload = artifacts.value.find(artifact => {
                 return artifact.name === name;
             });
             if (!artifactToDownload) {
                 throw new Error(`Unable to find an artifact with the name: ${name}`);
             }
             const items = yield downloadHttpClient.getContainerItems(artifactToDownload.name, artifactToDownload.fileContainerResourceUrl);
             if (!path) {
                 path = config_variables_1.getWorkSpaceDirectory();
             }
             path = path_1.normalize(path);
             path = path_1.resolve(path);
             // During upload, empty directories are rejected by the remote server so there should be no artifacts that consist of only empty directories
             const downloadSpecification = download_specification_1.getDownloadSpecification(name, items.value, path, (options === null || options === void 0 ? void 0 : options.createArtifactFolder) || false);
             if (downloadSpecification.filesToDownload.length === 0) {
                 core.info(`No downloadable files were found for the artifact: ${artifactToDownload.name}`);
             }
             else {
                 // Create all necessary directories recursively before starting any download
                 yield utils_1.createDirectoriesForArtifact(downloadSpecification.directoryStructure);
                 core.info('Directory structure has been setup for the artifact');
                 yield utils_1.createEmptyFilesForArtifact(downloadSpecification.emptyFilesToCreate);
                 yield downloadHttpClient.downloadSingleArtifact(downloadSpecification.filesToDownload);
             }
             return {
                 artifactName: name,
                 downloadPath: downloadSpecification.rootDownloadLocation
             };
         });
     }
     downloadAllArtifacts(path) {
         return __awaiter(this, void 0, void 0, function* () {
             const downloadHttpClient = new download_http_client_1.DownloadHttpClient();
             const response = [];
             const artifacts = yield downloadHttpClient.listArtifacts();
             if (artifacts.count === 0) {
                 core.info('Unable to find any artifacts for the associated workflow');
                 return response;
             }
             if (!path) {
                 path = config_variables_1.getWorkSpaceDirectory();
             }
             path = path_1.normalize(path);
             path = path_1.resolve(path);
             let downloadedArtifacts = 0;
             while (downloadedArtifacts < artifacts.count) {
                 const currentArtifactToDownload = artifacts.value[downloadedArtifacts];
                 downloadedArtifacts += 1;
                 core.info(`starting download of artifact ${currentArtifactToDownload.name} : ${downloadedArtifacts}/${artifacts.count}`);
                 // Get container entries for the specific artifact
                 const items = yield downloadHttpClient.getContainerItems(currentArtifactToDownload.name, currentArtifactToDownload.fileContainerResourceUrl);
                 const downloadSpecification = download_specification_1.getDownloadSpecification(currentArtifactToDownload.name, items.value, path, true);
                 if (downloadSpecification.filesToDownload.length === 0) {
                     core.info(`No downloadable files were found for any artifact ${currentArtifactToDownload.name}`);
                 }
                 else {
                     yield utils_1.createDirectoriesForArtifact(downloadSpecification.directoryStructure);
                     yield utils_1.createEmptyFilesForArtifact(downloadSpecification.emptyFilesToCreate);
                     yield downloadHttpClient.downloadSingleArtifact(downloadSpecification.filesToDownload);
                 }
                 response.push({
                     artifactName: currentArtifactToDownload.name,
                     downloadPath: downloadSpecification.rootDownloadLocation
                 });
             }
             return response;
         });
     }
 }
 exports.DefaultArtifactClient = DefaultArtifactClient;
 //# sourceMappingURL=artifact-client.js.map

 /***/ }),

 /***/ 2222:
 /***/ ((__unused_webpack_module, exports) => {

 "use strict";

 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.getRetentionDays = exports.getWorkSpaceDirectory = exports.getWorkFlowRunId = exports.getRuntimeUrl = exports.getRuntimeToken = exports.getDownloadFileConcurrency = exports.getInitialRetryIntervalInMilliseconds = exports.getRetryMultiplier = exports.getRetryLimit = exports.getUploadChunkSize = exports.getUploadFileConcurrency = void 0;
 // The number of concurrent uploads that happens at the same time
 function getUploadFileConcurrency() {
     return 2;
 }
 exports.getUploadFileConcurrency = getUploadFileConcurrency;
 // When uploading large files that can't be uploaded with a single http call, this controls
 // the chunk size that is used during upload
 function getUploadChunkSize() {
     return 8 * 1024 * 1024; // 8 MB Chunks
 }
 exports.getUploadChunkSize = getUploadChunkSize;
 // The maximum number of retries that can be attempted before an upload or download fails
 function getRetryLimit() {
     return 5;
 }
 exports.getRetryLimit = getRetryLimit;
 // With exponential backoff, the larger the retry count, the larger the wait time before another attempt
 // The retry multiplier controls by how much the backOff time increases depending on the number of retries
 function getRetryMultiplier() {
     return 1.5;
 }
 exports.getRetryMultiplier = getRetryMultiplier;
 // The initial wait time if an upload or download fails and a retry is being attempted for the first time
 function getInitialRetryIntervalInMilliseconds() {
     return 3000;
 }
 exports.getInitialRetryIntervalInMilliseconds = getInitialRetryIntervalInMilliseconds;
 // The number of concurrent downloads that happens at the same time
 function getDownloadFileConcurrency() {
     return 2;
 }
 exports.getDownloadFileConcurrency = getDownloadFileConcurrency;
 function getRuntimeToken() {
     const token = process.env['ACTIONS_RUNTIME_TOKEN'];
     if (!token) {
         throw new Error('Unable to get ACTIONS_RUNTIME_TOKEN env variable');
     }
     return token;
 }
 exports.getRuntimeToken = getRuntimeToken;
 function getRuntimeUrl() {
     const runtimeUrl = process.env['ACTIONS_RUNTIME_URL'];
     if (!runtimeUrl) {
         throw new Error('Unable to get ACTIONS_RUNTIME_URL env variable');
     }
     return runtimeUrl;
 }
 exports.getRuntimeUrl = getRuntimeUrl;
 function getWorkFlowRunId() {
     const workFlowRunId = process.env['GITHUB_RUN_ID'];
     if (!workFlowRunId) {
         throw new Error('Unable to get GITHUB_RUN_ID env variable');
     }
     return workFlowRunId;
 }
 exports.getWorkFlowRunId = getWorkFlowRunId;
 function getWorkSpaceDirectory() {
     const workspaceDirectory = process.env['GITHUB_WORKSPACE'];
     if (!workspaceDirectory) {
         throw new Error('Unable to get GITHUB_WORKSPACE env variable');
     }
     return workspaceDirectory;
 }
 exports.getWorkSpaceDirectory = getWorkSpaceDirectory;
 function getRetentionDays() {
     return process.env['GITHUB_RETENTION_DAYS'];
 }
 exports.getRetentionDays = getRetentionDays;
 //# sourceMappingURL=config-variables.js.map

 /***/ }),

 /***/ 3549:
 /***/ ((__unused_webpack_module, exports) => {

 "use strict";

 /**
  * CRC64: cyclic redundancy check, 64-bits
  *
  * In order to validate that artifacts are not being corrupted over the wire, this redundancy check allows us to
  * validate that there was no corruption during transmission. The implementation here is based on Go's hash/crc64 pkg,
  * but without the slicing-by-8 optimization: https://cs.opensource.google/go/go/+/master:src/hash/crc64/crc64.go
  *
  * This implementation uses a pregenerated table based on 0x9A6C9329AC4BC9B5 as the polynomial, the same polynomial that
  * is used for Azure Storage: https://github.com/Azure/azure-storage-net/blob/cbe605f9faa01bfc3003d75fc5a16b2eaccfe102/Lib/Common/Core/Util/Crc64.cs#L27
  */
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 // when transpile target is >= ES2020 (after dropping node 12) these can be changed to bigint literals - ts(2737)
 const PREGEN_POLY_TABLE = [
     BigInt('0x0000000000000000'),
     BigInt('0x7F6EF0C830358979'),
     BigInt('0xFEDDE190606B12F2'),
     BigInt('0x81B31158505E9B8B'),
     BigInt('0xC962E5739841B68F'),
     BigInt('0xB60C15BBA8743FF6'),
     BigInt('0x37BF04E3F82AA47D'),
     BigInt('0x48D1F42BC81F2D04'),
     BigInt('0xA61CECB46814FE75'),
     BigInt('0xD9721C7C5821770C'),
     BigInt('0x58C10D24087FEC87'),
     BigInt('0x27AFFDEC384A65FE'),
     BigInt('0x6F7E09C7F05548FA'),
     BigInt('0x1010F90FC060C183'),
     BigInt('0x91A3E857903E5A08'),
     BigInt('0xEECD189FA00BD371'),
     BigInt('0x78E0FF3B88BE6F81'),
     BigInt('0x078E0FF3B88BE6F8'),
     BigInt('0x863D1EABE8D57D73'),
     BigInt('0xF953EE63D8E0F40A'),
     BigInt('0xB1821A4810FFD90E'),
     BigInt('0xCEECEA8020CA5077'),
     BigInt('0x4F5FFBD87094CBFC'),
     BigInt('0x30310B1040A14285'),
     BigInt('0xDEFC138FE0AA91F4'),
     BigInt('0xA192E347D09F188D'),
     BigInt('0x2021F21F80C18306'),
     BigInt('0x5F4F02D7B0F40A7F'),
     BigInt('0x179EF6FC78EB277B'),
     BigInt('0x68F0063448DEAE02'),
     BigInt('0xE943176C18803589'),
     BigInt('0x962DE7A428B5BCF0'),
     BigInt('0xF1C1FE77117CDF02'),
     BigInt('0x8EAF0EBF2149567B'),
     BigInt('0x0F1C1FE77117CDF0'),
     BigInt('0x7072EF2F41224489'),
     BigInt('0x38A31B04893D698D'),
     BigInt('0x47CDEBCCB908E0F4'),
     BigInt('0xC67EFA94E9567B7F'),
     BigInt('0xB9100A5CD963F206'),
     BigInt('0x57DD12C379682177'),
     BigInt('0x28B3E20B495DA80E'),
     BigInt('0xA900F35319033385'),
     BigInt('0xD66E039B2936BAFC'),
     BigInt('0x9EBFF7B0E12997F8'),
     BigInt('0xE1D10778D11C1E81'),
     BigInt('0x606216208142850A'),
     BigInt('0x1F0CE6E8B1770C73'),
     BigInt('0x8921014C99C2B083'),
     BigInt('0xF64FF184A9F739FA'),
     BigInt('0x77FCE0DCF9A9A271'),
     BigInt('0x08921014C99C2B08'),
     BigInt('0x4043E43F0183060C'),
     BigInt('0x3F2D14F731B68F75'),
     BigInt('0xBE9E05AF61E814FE'),
     BigInt('0xC1F0F56751DD9D87'),
     BigInt('0x2F3DEDF8F1D64EF6'),
     BigInt('0x50531D30C1E3C78F'),
     BigInt('0xD1E00C6891BD5C04'),
     BigInt('0xAE8EFCA0A188D57D'),
     BigInt('0xE65F088B6997F879'),
     BigInt('0x9931F84359A27100'),
     BigInt('0x1882E91B09FCEA8B'),
     BigInt('0x67EC19D339C963F2'),
     BigInt('0xD75ADABD7A6E2D6F'),
     BigInt('0xA8342A754A5BA416'),
     BigInt('0x29873B2D1A053F9D'),
     BigInt('0x56E9CBE52A30B6E4'),
     BigInt('0x1E383FCEE22F9BE0'),
     BigInt('0x6156CF06D21A1299'),
     BigInt('0xE0E5DE5E82448912'),
     BigInt('0x9F8B2E96B271006B'),
     BigInt('0x71463609127AD31A'),
     BigInt('0x0E28C6C1224F5A63'),
     BigInt('0x8F9BD7997211C1E8'),
     BigInt('0xF0F5275142244891'),
     BigInt('0xB824D37A8A3B6595'),
     BigInt('0xC74A23B2BA0EECEC'),
     BigInt('0x46F932EAEA507767'),
     BigInt('0x3997C222DA65FE1E'),
     BigInt('0xAFBA2586F2D042EE'),
     BigInt('0xD0D4D54EC2E5CB97'),
     BigInt('0x5167C41692BB501C'),
     BigInt('0x2E0934DEA28ED965'),
     BigInt('0x66D8C0F56A91F461'),
     BigInt('0x19B6303D5AA47D18'),
     BigInt('0x980521650AFAE693'),
     BigInt('0xE76BD1AD3ACF6FEA'),
     BigInt('0x09A6C9329AC4BC9B'),
     BigInt('0x76C839FAAAF135E2'),
     BigInt('0xF77B28A2FAAFAE69'),
     BigInt('0x8815D86ACA9A2710'),
     BigInt('0xC0C42C4102850A14'),
     BigInt('0xBFAADC8932B0836D'),
     BigInt('0x3E19CDD162EE18E6'),
     BigInt('0x41773D1952DB919F'),
     BigInt('0x269B24CA6B12F26D'),
     BigInt('0x59F5D4025B277B14'),
     BigInt('0xD846C55A0B79E09F'),
     BigInt('0xA72835923B4C69E6'),
     BigInt('0xEFF9C1B9F35344E2'),
     BigInt('0x90973171C366CD9B'),
     BigInt('0x1124202993385610'),
     BigInt('0x6E4AD0E1A30DDF69'),
     BigInt('0x8087C87E03060C18'),
     BigInt('0xFFE938B633338561'),
     BigInt('0x7E5A29EE636D1EEA'),
     BigInt('0x0134D92653589793'),
     BigInt('0x49E52D0D9B47BA97'),
     BigInt('0x368BDDC5AB7233EE'),
     BigInt('0xB738CC9DFB2CA865'),
     BigInt('0xC8563C55CB19211C'),
     BigInt('0x5E7BDBF1E3AC9DEC'),
     BigInt('0x21152B39D3991495'),
     BigInt('0xA0A63A6183C78F1E'),
     BigInt('0xDFC8CAA9B3F20667'),
     BigInt('0x97193E827BED2B63'),
     BigInt('0xE877CE4A4BD8A21A'),
     BigInt('0x69C4DF121B863991'),
     BigInt('0x16AA2FDA2BB3B0E8'),
     BigInt('0xF86737458BB86399'),
     BigInt('0x8709C78DBB8DEAE0'),
     BigInt('0x06BAD6D5EBD3716B'),
     BigInt('0x79D4261DDBE6F812'),
     BigInt('0x3105D23613F9D516'),
     BigInt('0x4E6B22FE23CC5C6F'),
     BigInt('0xCFD833A67392C7E4'),
     BigInt('0xB0B6C36E43A74E9D'),
     BigInt('0x9A6C9329AC4BC9B5'),
     BigInt('0xE50263E19C7E40CC'),
     BigInt('0x64B172B9CC20DB47'),
     BigInt('0x1BDF8271FC15523E'),
     BigInt('0x530E765A340A7F3A'),
     BigInt('0x2C608692043FF643'),
     BigInt('0xADD397CA54616DC8'),
     BigInt('0xD2BD67026454E4B1'),
     BigInt('0x3C707F9DC45F37C0'),
     BigInt('0x431E8F55F46ABEB9'),
     BigInt('0xC2AD9E0DA4342532'),
     BigInt('0xBDC36EC59401AC4B'),
     BigInt('0xF5129AEE5C1E814F'),
     BigInt('0x8A7C6A266C2B0836'),
     BigInt('0x0BCF7B7E3C7593BD'),
     BigInt('0x74A18BB60C401AC4'),
     BigInt('0xE28C6C1224F5A634'),
     BigInt('0x9DE29CDA14C02F4D'),
     BigInt('0x1C518D82449EB4C6'),
     BigInt('0x633F7D4A74AB3DBF'),
     BigInt('0x2BEE8961BCB410BB'),
     BigInt('0x548079A98C8199C2'),
     BigInt('0xD53368F1DCDF0249'),
     BigInt('0xAA5D9839ECEA8B30'),
     BigInt('0x449080A64CE15841'),
     BigInt('0x3BFE706E7CD4D138'),
     BigInt('0xBA4D61362C8A4AB3'),
     BigInt('0xC52391FE1CBFC3CA'),
     BigInt('0x8DF265D5D4A0EECE'),
     BigInt('0xF29C951DE49567B7'),
     BigInt('0x732F8445B4CBFC3C'),
     BigInt('0x0C41748D84FE7545'),
     BigInt('0x6BAD6D5EBD3716B7'),
     BigInt('0x14C39D968D029FCE'),
     BigInt('0x95708CCEDD5C0445'),
     BigInt('0xEA1E7C06ED698D3C'),
     BigInt('0xA2CF882D2576A038'),
     BigInt('0xDDA178E515432941'),
     BigInt('0x5C1269BD451DB2CA'),
     BigInt('0x237C997575283BB3'),
     BigInt('0xCDB181EAD523E8C2'),
     BigInt('0xB2DF7122E51661BB'),
     BigInt('0x336C607AB548FA30'),
     BigInt('0x4C0290B2857D7349'),
     BigInt('0x04D364994D625E4D'),
     BigInt('0x7BBD94517D57D734'),
     BigInt('0xFA0E85092D094CBF'),
     BigInt('0x856075C11D3CC5C6'),
     BigInt('0x134D926535897936'),
     BigInt('0x6C2362AD05BCF04F'),
     BigInt('0xED9073F555E26BC4'),
     BigInt('0x92FE833D65D7E2BD'),
     BigInt('0xDA2F7716ADC8CFB9'),
     BigInt('0xA54187DE9DFD46C0'),
     BigInt('0x24F29686CDA3DD4B'),
     BigInt('0x5B9C664EFD965432'),
     BigInt('0xB5517ED15D9D8743'),
     BigInt('0xCA3F8E196DA80E3A'),
     BigInt('0x4B8C9F413DF695B1'),
     BigInt('0x34E26F890DC31CC8'),
     BigInt('0x7C339BA2C5DC31CC'),
     BigInt('0x035D6B6AF5E9B8B5'),
     BigInt('0x82EE7A32A5B7233E'),
     BigInt('0xFD808AFA9582AA47'),
     BigInt('0x4D364994D625E4DA'),
     BigInt('0x3258B95CE6106DA3'),
     BigInt('0xB3EBA804B64EF628'),
     BigInt('0xCC8558CC867B7F51'),
     BigInt('0x8454ACE74E645255'),
     BigInt('0xFB3A5C2F7E51DB2C'),
     BigInt('0x7A894D772E0F40A7'),
     BigInt('0x05E7BDBF1E3AC9DE'),
     BigInt('0xEB2AA520BE311AAF'),
     BigInt('0x944455E88E0493D6'),
     BigInt('0x15F744B0DE5A085D'),
     BigInt('0x6A99B478EE6F8124'),
     BigInt('0x224840532670AC20'),
     BigInt('0x5D26B09B16452559'),
     BigInt('0xDC95A1C3461BBED2'),
     BigInt('0xA3FB510B762E37AB'),
     BigInt('0x35D6B6AF5E9B8B5B'),
     BigInt('0x4AB846676EAE0222'),
     BigInt('0xCB0B573F3EF099A9'),
     BigInt('0xB465A7F70EC510D0'),
     BigInt('0xFCB453DCC6DA3DD4'),
     BigInt('0x83DAA314F6EFB4AD'),
     BigInt('0x0269B24CA6B12F26'),
     BigInt('0x7D0742849684A65F'),
     BigInt('0x93CA5A1B368F752E'),
     BigInt('0xECA4AAD306BAFC57'),
     BigInt('0x6D17BB8B56E467DC'),
     BigInt('0x12794B4366D1EEA5'),
     BigInt('0x5AA8BF68AECEC3A1'),
     BigInt('0x25C64FA09EFB4AD8'),
     BigInt('0xA4755EF8CEA5D153'),
     BigInt('0xDB1BAE30FE90582A'),
     BigInt('0xBCF7B7E3C7593BD8'),
     BigInt('0xC399472BF76CB2A1'),
     BigInt('0x422A5673A732292A'),
     BigInt('0x3D44A6BB9707A053'),
     BigInt('0x759552905F188D57'),
     BigInt('0x0AFBA2586F2D042E'),
     BigInt('0x8B48B3003F739FA5'),
     BigInt('0xF42643C80F4616DC'),
     BigInt('0x1AEB5B57AF4DC5AD'),
     BigInt('0x6585AB9F9F784CD4'),
     BigInt('0xE436BAC7CF26D75F'),
     BigInt('0x9B584A0FFF135E26'),
     BigInt('0xD389BE24370C7322'),
     BigInt('0xACE74EEC0739FA5B'),
     BigInt('0x2D545FB4576761D0'),
     BigInt('0x523AAF7C6752E8A9'),
     BigInt('0xC41748D84FE75459'),
     BigInt('0xBB79B8107FD2DD20'),
     BigInt('0x3ACAA9482F8C46AB'),
     BigInt('0x45A459801FB9CFD2'),
     BigInt('0x0D75ADABD7A6E2D6'),
     BigInt('0x721B5D63E7936BAF'),
     BigInt('0xF3A84C3BB7CDF024'),
     BigInt('0x8CC6BCF387F8795D'),
     BigInt('0x620BA46C27F3AA2C'),
     BigInt('0x1D6554A417C62355'),
     BigInt('0x9CD645FC4798B8DE'),
     BigInt('0xE3B8B53477AD31A7'),
     BigInt('0xAB69411FBFB21CA3'),
     BigInt('0xD407B1D78F8795DA'),
     BigInt('0x55B4A08FDFD90E51'),
     BigInt('0x2ADA5047EFEC8728')
 ];
 class CRC64 {
     constructor() {
         this._crc = BigInt(0);
     }
     update(data) {
         const buffer = typeof data === 'string' ? Buffer.from(data) : data;
         let crc = CRC64.flip64Bits(this._crc);
         for (const dataByte of buffer) {
             const crcByte = Number(crc & BigInt(0xff));
             crc = PREGEN_POLY_TABLE[crcByte ^ dataByte] ^ (crc >> BigInt(8));
         }
         this._crc = CRC64.flip64Bits(crc);
     }
     digest(encoding) {
         switch (encoding) {
             case 'hex':
                 return this._crc.toString(16).toUpperCase();
             case 'base64':
                 return this.toBuffer().toString('base64');
             default:
                 return this.toBuffer();
         }
     }
     toBuffer() {
         return Buffer.from([0, 8, 16, 24, 32, 40, 48, 56].map(s => Number((this._crc >> BigInt(s)) & BigInt(0xff))));
     }
     static flip64Bits(n) {
         return (BigInt(1) << BigInt(64)) - BigInt(1) - n;
     }
 }
 exports["default"] = CRC64;
 //# sourceMappingURL=crc64.js.map

 /***/ }),

 /***/ 8538:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
     function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
     return new (P || (P = Promise))(function (resolve, reject) {
         function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
         function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
         function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
         step((generator = generator.apply(thisArg, _arguments || [])).next());
     });
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.DownloadHttpClient = void 0;
 const fs = __importStar(__nccwpck_require__(7147));
 const core = __importStar(__nccwpck_require__(2186));
 const zlib = __importStar(__nccwpck_require__(9796));
 const utils_1 = __nccwpck_require__(6327);
 const url_1 = __nccwpck_require__(7310);
 const status_reporter_1 = __nccwpck_require__(9081);
 const perf_hooks_1 = __nccwpck_require__(4074);
 const http_manager_1 = __nccwpck_require__(6527);
 const config_variables_1 = __nccwpck_require__(2222);
 const requestUtils_1 = __nccwpck_require__(755);
 class DownloadHttpClient {
     constructor() {
         this.downloadHttpManager = new http_manager_1.HttpManager(config_variables_1.getDownloadFileConcurrency(), '@actions/artifact-download');
         // downloads are usually significantly faster than uploads so display status information every second
         this.statusReporter = new status_reporter_1.StatusReporter(1000);
     }
     /**
      * Gets a list of all artifacts that are in a specific container
      */
     listArtifacts() {
         return __awaiter(this, void 0, void 0, function* () {
             const artifactUrl = utils_1.getArtifactUrl();
             // use the first client from the httpManager, `keep-alive` is not used so the connection will close immediately
             const client = this.downloadHttpManager.getClient(0);
             const headers = utils_1.getDownloadHeaders('application/json');
             const response = yield requestUtils_1.retryHttpClientRequest('List Artifacts', () => __awaiter(this, void 0, void 0, function* () { return client.get(artifactUrl, headers); }));
             const body = yield response.readBody();
             return JSON.parse(body);
         });
     }
     /**
      * Fetches a set of container items that describe the contents of an artifact
      * @param artifactName the name of the artifact
      * @param containerUrl the artifact container URL for the run
      */
     getContainerItems(artifactName, containerUrl) {
         return __awaiter(this, void 0, void 0, function* () {
             // the itemPath search parameter controls which containers will be returned
             const resourceUrl = new url_1.URL(containerUrl);
             resourceUrl.searchParams.append('itemPath', artifactName);
             // use the first client from the httpManager, `keep-alive` is not used so the connection will close immediately
             const client = this.downloadHttpManager.getClient(0);
             const headers = utils_1.getDownloadHeaders('application/json');
             const response = yield requestUtils_1.retryHttpClientRequest('Get Container Items', () => __awaiter(this, void 0, void 0, function* () { return client.get(resourceUrl.toString(), headers); }));
             const body = yield response.readBody();
             return JSON.parse(body);
         });
     }
     /**
      * Concurrently downloads all the files that are part of an artifact
      * @param downloadItems information about what items to download and where to save them
      */
     downloadSingleArtifact(downloadItems) {
         return __awaiter(this, void 0, void 0, function* () {
             const DOWNLOAD_CONCURRENCY = config_variables_1.getDownloadFileConcurrency();
             // limit the number of files downloaded at a single time
             core.debug(`Download file concurrency is set to ${DOWNLOAD_CONCURRENCY}`);
             const parallelDownloads = [...new Array(DOWNLOAD_CONCURRENCY).keys()];
             let currentFile = 0;
             let downloadedFiles = 0;
             core.info(`Total number of files that will be downloaded: ${downloadItems.length}`);
             this.statusReporter.setTotalNumberOfFilesToProcess(downloadItems.length);
             this.statusReporter.start();
             yield Promise.all(parallelDownloads.map((index) => __awaiter(this, void 0, void 0, function* () {
                 while (currentFile < downloadItems.length) {
                     const currentFileToDownload = downloadItems[currentFile];
                     currentFile += 1;
                     const startTime = perf_hooks_1.performance.now();
                     yield this.downloadIndividualFile(index, currentFileToDownload.sourceLocation, currentFileToDownload.targetPath);
                     if (core.isDebug()) {
                         core.debug(`File: ${++downloadedFiles}/${downloadItems.length}. ${currentFileToDownload.targetPath} took ${(perf_hooks_1.performance.now() - startTime).toFixed(3)} milliseconds to finish downloading`);
                     }
                     this.statusReporter.incrementProcessedCount();
                 }
             })))
                 .catch(error => {
                 throw new Error(`Unable to download the artifact: ${error}`);
             })
                 .finally(() => {
                 this.statusReporter.stop();
                 // safety dispose all connections
                 this.downloadHttpManager.disposeAndReplaceAllClients();
             });
         });
     }
     /**
      * Downloads an individual file
      * @param httpClientIndex the index of the http client that is used to make all of the calls
      * @param artifactLocation origin location where a file will be downloaded from
      * @param downloadPath destination location for the file being downloaded
      */
     downloadIndividualFile(httpClientIndex, artifactLocation, downloadPath) {
         return __awaiter(this, void 0, void 0, function* () {
             let retryCount = 0;
             const retryLimit = config_variables_1.getRetryLimit();
             let destinationStream = fs.createWriteStream(downloadPath);
             const headers = utils_1.getDownloadHeaders('application/json', true, true);
             // a single GET request is used to download a file
             const makeDownloadRequest = () => __awaiter(this, void 0, void 0, function* () {
                 const client = this.downloadHttpManager.getClient(httpClientIndex);
                 return yield client.get(artifactLocation, headers);
             });
             // check the response headers to determine if the file was compressed using gzip
             const isGzip = (incomingHeaders) => {
                 return ('content-encoding' in incomingHeaders &&
                     incomingHeaders['content-encoding'] === 'gzip');
             };
             // Increments the current retry count and then checks if the retry limit has been reached
             // If there have been too many retries, fail so the download stops. If there is a retryAfterValue value provided,
             // it will be used
             const backOff = (retryAfterValue) => __awaiter(this, void 0, void 0, function* () {
                 retryCount++;
                 if (retryCount > retryLimit) {
                     return Promise.reject(new Error(`Retry limit has been reached. Unable to download ${artifactLocation}`));
                 }
                 else {
                     this.downloadHttpManager.disposeAndReplaceClient(httpClientIndex);
                     if (retryAfterValue) {
                         // Back off by waiting the specified time denoted by the retry-after header
                         core.info(`Backoff due to too many requests, retry #${retryCount}. Waiting for ${retryAfterValue} milliseconds before continuing the download`);
                         yield utils_1.sleep(retryAfterValue);
                     }
                     else {
                         // Back off using an exponential value that depends on the retry count
                         const backoffTime = utils_1.getExponentialRetryTimeInMilliseconds(retryCount);
                         core.info(`Exponential backoff for retry #${retryCount}. Waiting for ${backoffTime} milliseconds before continuing the download`);
                         yield utils_1.sleep(backoffTime);
                     }
                     core.info(`Finished backoff for retry #${retryCount}, continuing with download`);
                 }
             });
             const isAllBytesReceived = (expected, received) => {
                 // be lenient, if any input is missing, assume success, i.e. not truncated
                 if (!expected ||
                     !received ||
                     process.env['ACTIONS_ARTIFACT_SKIP_DOWNLOAD_VALIDATION']) {
                     core.info('Skipping download validation.');
                     return true;
                 }
                 return parseInt(expected) === received;
             };
             const resetDestinationStream = (fileDownloadPath) => __awaiter(this, void 0, void 0, function* () {
                 destinationStream.close();
                 // await until file is created at downloadpath; node15 and up fs.createWriteStream had not created a file yet
                 yield new Promise(resolve => {
                     destinationStream.on('close', resolve);
                     if (destinationStream.writableFinished) {
                         resolve();
                     }
                 });
                 yield utils_1.rmFile(fileDownloadPath);
                 destinationStream = fs.createWriteStream(fileDownloadPath);
             });
             // keep trying to download a file until a retry limit has been reached
             while (retryCount <= retryLimit) {
                 let response;
                 try {
                     response = yield makeDownloadRequest();
                 }
                 catch (error) {
                     // if an error is caught, it is usually indicative of a timeout so retry the download
                     core.info('An error occurred while attempting to download a file');
                     // eslint-disable-next-line no-console
                     console.log(error);
                     // increment the retryCount and use exponential backoff to wait before making the next request
                     yield backOff();
                     continue;
                 }
                 let forceRetry = false;
                 if (utils_1.isSuccessStatusCode(response.message.statusCode)) {
                     // The body contains the contents of the file however calling response.readBody() causes all the content to be converted to a string
                     // which can cause some gzip encoded data to be lost
                     // Instead of using response.readBody(), response.message is a readableStream that can be directly used to get the raw body contents
                     try {
                         const isGzipped = isGzip(response.message.headers);
                         yield this.pipeResponseToFile(response, destinationStream, isGzipped);
                         if (isGzipped ||
                             isAllBytesReceived(response.message.headers['content-length'], yield utils_1.getFileSize(downloadPath))) {
                             return;
                         }
                         else {
                             forceRetry = true;
                         }
                     }
                     catch (error) {
                         // retry on error, most likely streams were corrupted
                         forceRetry = true;
                     }
                 }
                 if (forceRetry || utils_1.isRetryableStatusCode(response.message.statusCode)) {
                     core.info(`A ${response.message.statusCode} response code has been received while attempting to download an artifact`);
                     resetDestinationStream(downloadPath);
                     // if a throttled status code is received, try to get the retryAfter header value, else differ to standard exponential backoff
                     utils_1.isThrottledStatusCode(response.message.statusCode)
                         ? yield backOff(utils_1.tryGetRetryAfterValueTimeInMilliseconds(response.message.headers))
                         : yield backOff();
                 }
                 else {
                     // Some unexpected response code, fail immediately and stop the download
                     utils_1.displayHttpDiagnostics(response);
                     return Promise.reject(new Error(`Unexpected http ${response.message.statusCode} during download for ${artifactLocation}`));
                 }
             }
         });
     }
     /**
      * Pipes the response from downloading an individual file to the appropriate destination stream while decoding gzip content if necessary
      * @param response the http response received when downloading a file
      * @param destinationStream the stream where the file should be written to
      * @param isGzip a boolean denoting if the content is compressed using gzip and if we need to decode it
      */
     pipeResponseToFile(response, destinationStream, isGzip) {
         return __awaiter(this, void 0, void 0, function* () {
             yield new Promise((resolve, reject) => {
                 if (isGzip) {
                     const gunzip = zlib.createGunzip();
                     response.message
                         .on('error', error => {
                         core.error(`An error occurred while attempting to read the response stream`);
                         gunzip.close();
                         destinationStream.close();
                         reject(error);
                     })
                         .pipe(gunzip)
                         .on('error', error => {
                         core.error(`An error occurred while attempting to decompress the response stream`);
                         destinationStream.close();
                         reject(error);
                     })
                         .pipe(destinationStream)
                         .on('close', () => {
                         resolve();
                     })
                         .on('error', error => {
                         core.error(`An error occurred while writing a downloaded file to ${destinationStream.path}`);
                         reject(error);
                     });
                 }
                 else {
                     response.message
                         .on('error', error => {
                         core.error(`An error occurred while attempting to read the response stream`);
                         destinationStream.close();
                         reject(error);
                     })
                         .pipe(destinationStream)
                         .on('close', () => {
                         resolve();
                     })
                         .on('error', error => {
                         core.error(`An error occurred while writing a downloaded file to ${destinationStream.path}`);
                         reject(error);
                     });
                 }
             });
             return;
         });
     }
 }
 exports.DownloadHttpClient = DownloadHttpClient;
 //# sourceMappingURL=download-http-client.js.map

 /***/ }),

 /***/ 5686:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.getDownloadSpecification = void 0;
 const path = __importStar(__nccwpck_require__(1017));
 /**
  * Creates a specification for a set of files that will be downloaded
  * @param artifactName the name of the artifact
  * @param artifactEntries a set of container entries that describe that files that make up an artifact
  * @param downloadPath the path where the artifact will be downloaded to
  * @param includeRootDirectory specifies if there should be an extra directory (denoted by the artifact name) where the artifact files should be downloaded to
  */
 function getDownloadSpecification(artifactName, artifactEntries, downloadPath, includeRootDirectory) {
     // use a set for the directory paths so that there are no duplicates
     const directories = new Set();
     const specifications = {
         rootDownloadLocation: includeRootDirectory
             ? path.join(downloadPath, artifactName)
             : downloadPath,
         directoryStructure: [],
         emptyFilesToCreate: [],
         filesToDownload: []
     };
     for (const entry of artifactEntries) {
         // Ignore artifacts in the container that don't begin with the same name
         if (entry.path.startsWith(`${artifactName}/`) ||
             entry.path.startsWith(`${artifactName}\\`)) {
             // normalize all separators to the local OS
             const normalizedPathEntry = path.normalize(entry.path);
             // entry.path always starts with the artifact name, if includeRootDirectory is false, remove the name from the beginning of the path
             const filePath = path.join(downloadPath, includeRootDirectory
                 ? normalizedPathEntry
                 : normalizedPathEntry.replace(artifactName, ''));
             // Case insensitive folder structure maintained in the backend, not every folder is created so the 'folder'
             // itemType cannot be relied upon. The file must be used to determine the directory structure
             if (entry.itemType === 'file') {
                 // Get the directories that we need to create from the filePath for each individual file
                 directories.add(path.dirname(filePath));
                 if (entry.fileLength === 0) {
                     // An empty file was uploaded, create the empty files locally so that no extra http calls are made
                     specifications.emptyFilesToCreate.push(filePath);
                 }
                 else {
                     specifications.filesToDownload.push({
                         sourceLocation: entry.contentLocation,
                         targetPath: filePath
                     });
                 }
             }
         }
     }
     specifications.directoryStructure = Array.from(directories);
     return specifications;
 }
 exports.getDownloadSpecification = getDownloadSpecification;
 //# sourceMappingURL=download-specification.js.map

 /***/ }),

 /***/ 6527:
 /***/ ((__unused_webpack_module, exports, __nccwpck_require__) => {

 "use strict";

 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.HttpManager = void 0;
 const utils_1 = __nccwpck_require__(6327);
 /**
  * Used for managing http clients during either upload or download
  */
 class HttpManager {
     constructor(clientCount, userAgent) {
         if (clientCount < 1) {
             throw new Error('There must be at least one client');
         }
         this.userAgent = userAgent;
         this.clients = new Array(clientCount).fill(utils_1.createHttpClient(userAgent));
     }
     getClient(index) {
         return this.clients[index];
     }
     // client disposal is necessary if a keep-alive connection is used to properly close the connection
     // for more information see: https://github.com/actions/http-client/blob/04e5ad73cd3fd1f5610a32116b0759eddf6570d2/index.ts#L292
     disposeAndReplaceClient(index) {
         this.clients[index].dispose();
         this.clients[index] = utils_1.createHttpClient(this.userAgent);
     }
     disposeAndReplaceAllClients() {
         for (const [index] of this.clients.entries()) {
             this.disposeAndReplaceClient(index);
         }
     }
 }
 exports.HttpManager = HttpManager;
 //# sourceMappingURL=http-manager.js.map

 /***/ }),

 /***/ 7398:
 /***/ ((__unused_webpack_module, exports, __nccwpck_require__) => {

 "use strict";

 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.checkArtifactFilePath = exports.checkArtifactName = void 0;
 const core_1 = __nccwpck_require__(2186);
 /**
  * Invalid characters that cannot be in the artifact name or an uploaded file. Will be rejected
  * from the server if attempted to be sent over. These characters are not allowed due to limitations with certain
  * file systems such as NTFS. To maintain platform-agnostic behavior, all characters that are not supported by an
  * individual filesystem/platform will not be supported on all fileSystems/platforms
  *
  * FilePaths can include characters such as \ and / which are not permitted in the artifact name alone
  */
 const invalidArtifactFilePathCharacters = new Map([
     ['"', ' Double quote "'],
     [':', ' Colon :'],
     ['<', ' Less than <'],
     ['>', ' Greater than >'],
     ['|', ' Vertical bar |'],
     ['*', ' Asterisk *'],
     ['?', ' Question mark ?'],
     ['\r', ' Carriage return \\r'],
     ['\n', ' Line feed \\n']
 ]);
 const invalidArtifactNameCharacters = new Map([
     ...invalidArtifactFilePathCharacters,
     ['\\', ' Backslash \\'],
     ['/', ' Forward slash /']
 ]);
 /**
  * Scans the name of the artifact to make sure there are no illegal characters
  */
 function checkArtifactName(name) {
     if (!name) {
         throw new Error(`Artifact name: ${name}, is incorrectly provided`);
     }
     for (const [invalidCharacterKey, errorMessageForCharacter] of invalidArtifactNameCharacters) {
         if (name.includes(invalidCharacterKey)) {
             throw new Error(`Artifact name is not valid: ${name}. Contains the following character: ${errorMessageForCharacter}

 Invalid characters include: ${Array.from(invalidArtifactNameCharacters.values()).toString()}

 These characters are not allowed in the artifact name due to limitations with certain file systems such as NTFS. To maintain file system agnostic behavior, these characters are intentionally not allowed to prevent potential problems with downloads on different file systems.`);
         }
     }
     core_1.info(`Artifact name is valid!`);
 }
 exports.checkArtifactName = checkArtifactName;
 /**
  * Scans the name of the filePath used to make sure there are no illegal characters
  */
 function checkArtifactFilePath(path) {
     if (!path) {
         throw new Error(`Artifact path: ${path}, is incorrectly provided`);
     }
     for (const [invalidCharacterKey, errorMessageForCharacter] of invalidArtifactFilePathCharacters) {
         if (path.includes(invalidCharacterKey)) {
             throw new Error(`Artifact path is not valid: ${path}. Contains the following character: ${errorMessageForCharacter}

 Invalid characters include: ${Array.from(invalidArtifactFilePathCharacters.values()).toString()}

 The following characters are not allowed in files that are uploaded due to limitations with certain file systems such as NTFS. To maintain file system agnostic behavior, these characters are intentionally not allowed to prevent potential problems with downloads on different file systems.
           `);
         }
     }
 }
 exports.checkArtifactFilePath = checkArtifactFilePath;
 //# sourceMappingURL=path-and-artifact-name-validation.js.map

 /***/ }),

 /***/ 755:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
     function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
     return new (P || (P = Promise))(function (resolve, reject) {
         function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
         function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
         function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
         step((generator = generator.apply(thisArg, _arguments || [])).next());
     });
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.retryHttpClientRequest = exports.retry = void 0;
 const utils_1 = __nccwpck_require__(6327);
 const core = __importStar(__nccwpck_require__(2186));
 const config_variables_1 = __nccwpck_require__(2222);
 function retry(name, operation, customErrorMessages, maxAttempts) {
     return __awaiter(this, void 0, void 0, function* () {
         let response = undefined;
         let statusCode = undefined;
         let isRetryable = false;
         let errorMessage = '';
         let customErrorInformation = undefined;
         let attempt = 1;
         while (attempt <= maxAttempts) {
             try {
                 response = yield operation();
                 statusCode = response.message.statusCode;
                 if (utils_1.isSuccessStatusCode(statusCode)) {
                     return response;
                 }
                 // Extra error information that we want to display if a particular response code is hit
                 if (statusCode) {
                     customErrorInformation = customErrorMessages.get(statusCode);
                 }
                 isRetryable = utils_1.isRetryableStatusCode(statusCode);
                 errorMessage = `Artifact service responded with ${statusCode}`;
             }
             catch (error) {
                 isRetryable = true;
                 errorMessage = error.message;
             }
             if (!isRetryable) {
                 core.info(`${name} - Error is not retryable`);
                 if (response) {
                     utils_1.displayHttpDiagnostics(response);
                 }
                 break;
             }
             core.info(`${name} - Attempt ${attempt} of ${maxAttempts} failed with error: ${errorMessage}`);
             yield utils_1.sleep(utils_1.getExponentialRetryTimeInMilliseconds(attempt));
             attempt++;
         }
         if (response) {
             utils_1.displayHttpDiagnostics(response);
         }
         if (customErrorInformation) {
             throw Error(`${name} failed: ${customErrorInformation}`);
         }
         throw Error(`${name} failed: ${errorMessage}`);
     });
 }
 exports.retry = retry;
 function retryHttpClientRequest(name, method, customErrorMessages = new Map(), maxAttempts = config_variables_1.getRetryLimit()) {
     return __awaiter(this, void 0, void 0, function* () {
         return yield retry(name, method, customErrorMessages, maxAttempts);
     });
 }
 exports.retryHttpClientRequest = retryHttpClientRequest;
 //# sourceMappingURL=requestUtils.js.map

 /***/ }),

 /***/ 9081:
 /***/ ((__unused_webpack_module, exports, __nccwpck_require__) => {

 "use strict";

 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.StatusReporter = void 0;
 const core_1 = __nccwpck_require__(2186);
 /**
  * Status Reporter that displays information about the progress/status of an artifact that is being uploaded or downloaded
  *
  * Variable display time that can be adjusted using the displayFrequencyInMilliseconds variable
  * The total status of the upload/download gets displayed according to this value
  * If there is a large file that is being uploaded, extra information about the individual status can also be displayed using the updateLargeFileStatus function
  */
 class StatusReporter {
     constructor(displayFrequencyInMilliseconds) {
         this.totalNumberOfFilesToProcess = 0;
         this.processedCount = 0;
         this.largeFiles = new Map();
         this.totalFileStatus = undefined;
         this.displayFrequencyInMilliseconds = displayFrequencyInMilliseconds;
     }
     setTotalNumberOfFilesToProcess(fileTotal) {
         this.totalNumberOfFilesToProcess = fileTotal;
         this.processedCount = 0;
     }
     start() {
         // displays information about the total upload/download status
         this.totalFileStatus = setInterval(() => {
             // display 1 decimal place without any rounding
             const percentage = this.formatPercentage(this.processedCount, this.totalNumberOfFilesToProcess);
             core_1.info(`Total file count: ${this.totalNumberOfFilesToProcess} ---- Processed file #${this.processedCount} (${percentage.slice(0, percentage.indexOf('.') + 2)}%)`);
         }, this.displayFrequencyInMilliseconds);
     }
     // if there is a large file that is being uploaded in chunks, this is used to display extra information about the status of the upload
     updateLargeFileStatus(fileName, chunkStartIndex, chunkEndIndex, totalUploadFileSize) {
         // display 1 decimal place without any rounding
         const percentage = this.formatPercentage(chunkEndIndex, totalUploadFileSize);
         core_1.info(`Uploaded ${fileName} (${percentage.slice(0, percentage.indexOf('.') + 2)}%) bytes ${chunkStartIndex}:${chunkEndIndex}`);
     }
     stop() {
         if (this.totalFileStatus) {
             clearInterval(this.totalFileStatus);
         }
     }
     incrementProcessedCount() {
         this.processedCount++;
     }
     formatPercentage(numerator, denominator) {
         // toFixed() rounds, so use extra precision to display accurate information even though 4 decimal places are not displayed
         return ((numerator / denominator) * 100).toFixed(4).toString();
     }
 }
 exports.StatusReporter = StatusReporter;
 //# sourceMappingURL=status-reporter.js.map

 /***/ }),

 /***/ 606:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
     function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
     return new (P || (P = Promise))(function (resolve, reject) {
         function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
         function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
         function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
         step((generator = generator.apply(thisArg, _arguments || [])).next());
     });
 };
 var __asyncValues = (this && this.__asyncValues) || function (o) {
     if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
     var m = o[Symbol.asyncIterator], i;
     return m ? m.call(o) : (o = typeof __values === "function" ? __values(o) : o[Symbol.iterator](), i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i);
     function verb(n) { i[n] = o[n] && function (v) { return new Promise(function (resolve, reject) { v = o[n](v), settle(resolve, reject, v.done, v.value); }); }; }
     function settle(resolve, reject, d, v) { Promise.resolve(v).then(function(v) { resolve({ value: v, done: d }); }, reject); }
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.createGZipFileInBuffer = exports.createGZipFileOnDisk = void 0;
 const fs = __importStar(__nccwpck_require__(7147));
 const zlib = __importStar(__nccwpck_require__(9796));
 const util_1 = __nccwpck_require__(3837);
 const stat = util_1.promisify(fs.stat);
 /**
  * GZipping certain files that are already compressed will likely not yield further size reductions. Creating large temporary gzip
  * files then will just waste a lot of time before ultimately being discarded (especially for very large files).
  * If any of these types of files are encountered then on-disk gzip creation will be skipped and the original file will be uploaded as-is
  */
 const gzipExemptFileExtensions = [
     '.gzip',
     '.zip',
     '.tar.lz',
     '.tar.gz',
     '.tar.bz2',
     '.7z'
 ];
 /**
  * Creates a Gzip compressed file of an original file at the provided temporary filepath location
  * @param {string} originalFilePath filepath of whatever will be compressed. The original file will be unmodified
  * @param {string} tempFilePath the location of where the Gzip file will be created
  * @returns the size of gzip file that gets created
  */
 function createGZipFileOnDisk(originalFilePath, tempFilePath) {
     return __awaiter(this, void 0, void 0, function* () {
         for (const gzipExemptExtension of gzipExemptFileExtensions) {
             if (originalFilePath.endsWith(gzipExemptExtension)) {
                 // return a really large number so that the original file gets uploaded
                 return Number.MAX_SAFE_INTEGER;
             }
         }
         return new Promise((resolve, reject) => {
             const inputStream = fs.createReadStream(originalFilePath);
             const gzip = zlib.createGzip();
             const outputStream = fs.createWriteStream(tempFilePath);
             inputStream.pipe(gzip).pipe(outputStream);
             outputStream.on('finish', () => __awaiter(this, void 0, void 0, function* () {
                 // wait for stream to finish before calculating the size which is needed as part of the Content-Length header when starting an upload
                 const size = (yield stat(tempFilePath)).size;
                 resolve(size);
             }));
             outputStream.on('error', error => {
                 // eslint-disable-next-line no-console
                 console.log(error);
                 reject;
             });
         });
     });
 }
 exports.createGZipFileOnDisk = createGZipFileOnDisk;
 /**
  * Creates a GZip file in memory using a buffer. Should be used for smaller files to reduce disk I/O
  * @param originalFilePath the path to the original file that is being GZipped
  * @returns a buffer with the GZip file
  */
 function createGZipFileInBuffer(originalFilePath) {
     return __awaiter(this, void 0, void 0, function* () {
         return new Promise((resolve) => __awaiter(this, void 0, void 0, function* () {
             var e_1, _a;
             const inputStream = fs.createReadStream(originalFilePath);
             const gzip = zlib.createGzip();
             inputStream.pipe(gzip);
             // read stream into buffer, using experimental async iterators see https://github.com/nodejs/readable-stream/issues/403#issuecomment-479069043
             const chunks = [];
             try {
                 for (var gzip_1 = __asyncValues(gzip), gzip_1_1; gzip_1_1 = yield gzip_1.next(), !gzip_1_1.done;) {
                     const chunk = gzip_1_1.value;
                     chunks.push(chunk);
                 }
             }
             catch (e_1_1) { e_1 = { error: e_1_1 }; }
             finally {
                 try {
                     if (gzip_1_1 && !gzip_1_1.done && (_a = gzip_1.return)) yield _a.call(gzip_1);
                 }
                 finally { if (e_1) throw e_1.error; }
             }
             resolve(Buffer.concat(chunks));
         }));
     });
 }
 exports.createGZipFileInBuffer = createGZipFileInBuffer;
 //# sourceMappingURL=upload-gzip.js.map

 /***/ }),

 /***/ 4354:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
     function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
     return new (P || (P = Promise))(function (resolve, reject) {
         function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
         function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
         function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
         step((generator = generator.apply(thisArg, _arguments || [])).next());
     });
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.UploadHttpClient = void 0;
 const fs = __importStar(__nccwpck_require__(7147));
 const core = __importStar(__nccwpck_require__(2186));
 const tmp = __importStar(__nccwpck_require__(8065));
 const stream = __importStar(__nccwpck_require__(2781));
 const utils_1 = __nccwpck_require__(6327);
 const config_variables_1 = __nccwpck_require__(2222);
 const util_1 = __nccwpck_require__(3837);
 const url_1 = __nccwpck_require__(7310);
 const perf_hooks_1 = __nccwpck_require__(4074);
 const status_reporter_1 = __nccwpck_require__(9081);
 const http_client_1 = __nccwpck_require__(6255);
 const http_manager_1 = __nccwpck_require__(6527);
 const upload_gzip_1 = __nccwpck_require__(606);
 const requestUtils_1 = __nccwpck_require__(755);
 const stat = util_1.promisify(fs.stat);
 class UploadHttpClient {
     constructor() {
         this.uploadHttpManager = new http_manager_1.HttpManager(config_variables_1.getUploadFileConcurrency(), '@actions/artifact-upload');
         this.statusReporter = new status_reporter_1.StatusReporter(10000);
     }
     /**
      * Creates a file container for the new artifact in the remote blob storage/file service
      * @param {string} artifactName Name of the artifact being created
      * @returns The response from the Artifact Service if the file container was successfully created
      */
     createArtifactInFileContainer(artifactName, options) {
         return __awaiter(this, void 0, void 0, function* () {
             const parameters = {
                 Type: 'actions_storage',
                 Name: artifactName
             };
             // calculate retention period
             if (options && options.retentionDays) {
                 const maxRetentionStr = config_variables_1.getRetentionDays();
                 parameters.RetentionDays = utils_1.getProperRetention(options.retentionDays, maxRetentionStr);
             }
             const data = JSON.stringify(parameters, null, 2);
             const artifactUrl = utils_1.getArtifactUrl();
             // use the first client from the httpManager, `keep-alive` is not used so the connection will close immediately
             const client = this.uploadHttpManager.getClient(0);
             const headers = utils_1.getUploadHeaders('application/json', false);
             // Extra information to display when a particular HTTP code is returned
             // If a 403 is returned when trying to create a file container, the customer has exceeded
             // their storage quota so no new artifact containers can be created
             const customErrorMessages = new Map([
                 [
                     http_client_1.HttpCodes.Forbidden,
                     'Artifact storage quota has been hit. Unable to upload any new artifacts'
                 ],
                 [
                     http_client_1.HttpCodes.BadRequest,
                     `The artifact name ${artifactName} is not valid. Request URL ${artifactUrl}`
                 ]
             ]);
             const response = yield requestUtils_1.retryHttpClientRequest('Create Artifact Container', () => __awaiter(this, void 0, void 0, function* () { return client.post(artifactUrl, data, headers); }), customErrorMessages);
             const body = yield response.readBody();
             return JSON.parse(body);
         });
     }
     /**
      * Concurrently upload all of the files in chunks
      * @param {string} uploadUrl Base Url for the artifact that was created
      * @param {SearchResult[]} filesToUpload A list of information about the files being uploaded
      * @returns The size of all the files uploaded in bytes
      */
     uploadArtifactToFileContainer(uploadUrl, filesToUpload, options) {
         return __awaiter(this, void 0, void 0, function* () {
             const FILE_CONCURRENCY = config_variables_1.getUploadFileConcurrency();
             const MAX_CHUNK_SIZE = config_variables_1.getUploadChunkSize();
             core.debug(`File Concurrency: ${FILE_CONCURRENCY}, and Chunk Size: ${MAX_CHUNK_SIZE}`);
             const parameters = [];
             // by default, file uploads will continue if there is an error unless specified differently in the options
             let continueOnError = true;
             if (options) {
                 if (options.continueOnError === false) {
                     continueOnError = false;
                 }
             }
             // prepare the necessary parameters to upload all the files
             for (const file of filesToUpload) {
                 const resourceUrl = new url_1.URL(uploadUrl);
                 resourceUrl.searchParams.append('itemPath', file.uploadFilePath);
                 parameters.push({
                     file: file.absoluteFilePath,
                     resourceUrl: resourceUrl.toString(),
                     maxChunkSize: MAX_CHUNK_SIZE,
                     continueOnError
                 });
             }
             const parallelUploads = [...new Array(FILE_CONCURRENCY).keys()];
             const failedItemsToReport = [];
             let currentFile = 0;
             let completedFiles = 0;
             let uploadFileSize = 0;
             let totalFileSize = 0;
             let abortPendingFileUploads = false;
             this.statusReporter.setTotalNumberOfFilesToProcess(filesToUpload.length);
             this.statusReporter.start();
             // only allow a certain amount of files to be uploaded at once, this is done to reduce potential errors
             yield Promise.all(parallelUploads.map((index) => __awaiter(this, void 0, void 0, function* () {
                 while (currentFile < filesToUpload.length) {
                     const currentFileParameters = parameters[currentFile];
                     currentFile += 1;
                     if (abortPendingFileUploads) {
                         failedItemsToReport.push(currentFileParameters.file);
                         continue;
                     }
                     const startTime = perf_hooks_1.performance.now();
                     const uploadFileResult = yield this.uploadFileAsync(index, currentFileParameters);
                     if (core.isDebug()) {
                         core.debug(`File: ${++completedFiles}/${filesToUpload.length}. ${currentFileParameters.file} took ${(perf_hooks_1.performance.now() - startTime).toFixed(3)} milliseconds to finish upload`);
                     }
                     uploadFileSize += uploadFileResult.successfulUploadSize;
                     totalFileSize += uploadFileResult.totalSize;
                     if (uploadFileResult.isSuccess === false) {
                         failedItemsToReport.push(currentFileParameters.file);
                         if (!continueOnError) {
                             // fail fast
                             core.error(`aborting artifact upload`);
                             abortPendingFileUploads = true;
                         }
                     }
                     this.statusReporter.incrementProcessedCount();
                 }
             })));
             this.statusReporter.stop();
             // done uploading, safety dispose all connections
             this.uploadHttpManager.disposeAndReplaceAllClients();
             core.info(`Total size of all the files uploaded is ${uploadFileSize} bytes`);
             return {
                 uploadSize: uploadFileSize,
                 totalSize: totalFileSize,
                 failedItems: failedItemsToReport
             };
         });
     }
     /**
      * Asynchronously uploads a file. The file is compressed and uploaded using GZip if it is determined to save space.
      * If the upload file is bigger than the max chunk size it will be uploaded via multiple calls
      * @param {number} httpClientIndex The index of the httpClient that is being used to make all of the calls
      * @param {UploadFileParameters} parameters Information about the file that needs to be uploaded
      * @returns The size of the file that was uploaded in bytes along with any failed uploads
      */
     uploadFileAsync(httpClientIndex, parameters) {
         return __awaiter(this, void 0, void 0, function* () {
             const fileStat = yield stat(parameters.file);
             const totalFileSize = fileStat.size;
             const isFIFO = fileStat.isFIFO();
             let offset = 0;
             let isUploadSuccessful = true;
             let failedChunkSizes = 0;
             let uploadFileSize = 0;
             let isGzip = true;
             // the file that is being uploaded is less than 64k in size to increase throughput and to minimize disk I/O
             // for creating a new GZip file, an in-memory buffer is used for compression
             // with named pipes the file size is reported as zero in that case don't read the file in memory
             if (!isFIFO && totalFileSize < 65536) {
                 core.debug(`${parameters.file} is less than 64k in size. Creating a gzip file in-memory to potentially reduce the upload size`);
                 const buffer = yield upload_gzip_1.createGZipFileInBuffer(parameters.file);
                 // An open stream is needed in the event of a failure and we need to retry. If a NodeJS.ReadableStream is directly passed in,
                 // it will not properly get reset to the start of the stream if a chunk upload needs to be retried
                 let openUploadStream;
                 if (totalFileSize < buffer.byteLength) {
                     // compression did not help with reducing the size, use a readable stream from the original file for upload
                     core.debug(`The gzip file created for ${parameters.file} did not help with reducing the size of the file. The original file will be uploaded as-is`);
                     openUploadStream = () => fs.createReadStream(parameters.file);
                     isGzip = false;
                     uploadFileSize = totalFileSize;
                 }
                 else {
                     // create a readable stream using a PassThrough stream that is both readable and writable
                     core.debug(`A gzip file created for ${parameters.file} helped with reducing the size of the original file. The file will be uploaded using gzip.`);
                     openUploadStream = () => {
                         const passThrough = new stream.PassThrough();
                         passThrough.end(buffer);
                         return passThrough;
                     };
                     uploadFileSize = buffer.byteLength;
                 }
                 const result = yield this.uploadChunk(httpClientIndex, parameters.resourceUrl, openUploadStream, 0, uploadFileSize - 1, uploadFileSize, isGzip, totalFileSize);
                 if (!result) {
                     // chunk failed to upload
                     isUploadSuccessful = false;
                     failedChunkSizes += uploadFileSize;
                     core.warning(`Aborting upload for ${parameters.file} due to failure`);
                 }
                 return {
                     isSuccess: isUploadSuccessful,
                     successfulUploadSize: uploadFileSize - failedChunkSizes,
                     totalSize: totalFileSize
                 };
             }
             else {
                 // the file that is being uploaded is greater than 64k in size, a temporary file gets created on disk using the
                 // npm tmp-promise package and this file gets used to create a GZipped file
                 const tempFile = yield tmp.file();
                 core.debug(`${parameters.file} is greater than 64k in size. Creating a gzip file on-disk ${tempFile.path} to potentially reduce the upload size`);
                 // create a GZip file of the original file being uploaded, the original file should not be modified in any way
                 uploadFileSize = yield upload_gzip_1.createGZipFileOnDisk(parameters.file, tempFile.path);
                 let uploadFilePath = tempFile.path;
                 // compression did not help with size reduction, use the original file for upload and delete the temp GZip file
                 // for named pipes totalFileSize is zero, this assumes compression did help
                 if (!isFIFO && totalFileSize < uploadFileSize) {
                     core.debug(`The gzip file created for ${parameters.file} did not help with reducing the size of the file. The original file will be uploaded as-is`);
                     uploadFileSize = totalFileSize;
                     uploadFilePath = parameters.file;
                     isGzip = false;
                 }
                 else {
                     core.debug(`The gzip file created for ${parameters.file} is smaller than the original file. The file will be uploaded using gzip.`);
                 }
                 let abortFileUpload = false;
                 // upload only a single chunk at a time
                 while (offset < uploadFileSize) {
                     const chunkSize = Math.min(uploadFileSize - offset, parameters.maxChunkSize);
                     const startChunkIndex = offset;
                     const endChunkIndex = offset + chunkSize - 1;
                     offset += parameters.maxChunkSize;
                     if (abortFileUpload) {
                         // if we don't want to continue in the event of an error, any pending upload chunks will be marked as failed
                         failedChunkSizes += chunkSize;
                         continue;
                     }
                     const result = yield this.uploadChunk(httpClientIndex, parameters.resourceUrl, () => fs.createReadStream(uploadFilePath, {
                         start: startChunkIndex,
                         end: endChunkIndex,
                         autoClose: false
                     }), startChunkIndex, endChunkIndex, uploadFileSize, isGzip, totalFileSize);
                     if (!result) {
                         // Chunk failed to upload, report as failed and do not continue uploading any more chunks for the file. It is possible that part of a chunk was
                         // successfully uploaded so the server may report a different size for what was uploaded
                         isUploadSuccessful = false;
                         failedChunkSizes += chunkSize;
                         core.warning(`Aborting upload for ${parameters.file} due to failure`);
                         abortFileUpload = true;
                     }
                     else {
                         // if an individual file is greater than 8MB (1024*1024*8) in size, display extra information about the upload status
                         if (uploadFileSize > 8388608) {
                             this.statusReporter.updateLargeFileStatus(parameters.file, startChunkIndex, endChunkIndex, uploadFileSize);
                         }
                     }
                 }
                 // Delete the temporary file that was created as part of the upload. If the temp file does not get manually deleted by
                 // calling cleanup, it gets removed when the node process exits. For more info see: https://www.npmjs.com/package/tmp-promise#about
                 core.debug(`deleting temporary gzip file ${tempFile.path}`);
                 yield tempFile.cleanup();
                 return {
                     isSuccess: isUploadSuccessful,
                     successfulUploadSize: uploadFileSize - failedChunkSizes,
                     totalSize: totalFileSize
                 };
             }
         });
     }
     /**
      * Uploads a chunk of an individual file to the specified resourceUrl. If the upload fails and the status code
      * indicates a retryable status, we try to upload the chunk as well
      * @param {number} httpClientIndex The index of the httpClient being used to make all the necessary calls
      * @param {string} resourceUrl Url of the resource that the chunk will be uploaded to
      * @param {NodeJS.ReadableStream} openStream Stream of the file that will be uploaded
      * @param {number} start Starting byte index of file that the chunk belongs to
      * @param {number} end Ending byte index of file that the chunk belongs to
      * @param {number} uploadFileSize Total size of the file in bytes that is being uploaded
      * @param {boolean} isGzip Denotes if we are uploading a Gzip compressed stream
      * @param {number} totalFileSize Original total size of the file that is being uploaded
      * @returns if the chunk was successfully uploaded
      */
     uploadChunk(httpClientIndex, resourceUrl, openStream, start, end, uploadFileSize, isGzip, totalFileSize) {
         return __awaiter(this, void 0, void 0, function* () {
             // open a new stream and read it to compute the digest
             const digest = yield utils_1.digestForStream(openStream());
             // prepare all the necessary headers before making any http call
             const headers = utils_1.getUploadHeaders('application/octet-stream', true, isGzip, totalFileSize, end - start + 1, utils_1.getContentRange(start, end, uploadFileSize), digest);
             const uploadChunkRequest = () => __awaiter(this, void 0, void 0, function* () {
                 const client = this.uploadHttpManager.getClient(httpClientIndex);
                 return yield client.sendStream('PUT', resourceUrl, openStream(), headers);
             });
             let retryCount = 0;
             const retryLimit = config_variables_1.getRetryLimit();
             // Increments the current retry count and then checks if the retry limit has been reached
             // If there have been too many retries, fail so the download stops
             const incrementAndCheckRetryLimit = (response) => {
                 retryCount++;
                 if (retryCount > retryLimit) {
                     if (response) {
                         utils_1.displayHttpDiagnostics(response);
                     }
                     core.info(`Retry limit has been reached for chunk at offset ${start} to ${resourceUrl}`);
                     return true;
                 }
                 return false;
             };
             const backOff = (retryAfterValue) => __awaiter(this, void 0, void 0, function* () {
                 this.uploadHttpManager.disposeAndReplaceClient(httpClientIndex);
                 if (retryAfterValue) {
                     core.info(`Backoff due to too many requests, retry #${retryCount}. Waiting for ${retryAfterValue} milliseconds before continuing the upload`);
                     yield utils_1.sleep(retryAfterValue);
                 }
                 else {
                     const backoffTime = utils_1.getExponentialRetryTimeInMilliseconds(retryCount);
                     core.info(`Exponential backoff for retry #${retryCount}. Waiting for ${backoffTime} milliseconds before continuing the upload at offset ${start}`);
                     yield utils_1.sleep(backoffTime);
                 }
                 core.info(`Finished backoff for retry #${retryCount}, continuing with upload`);
                 return;
             });
             // allow for failed chunks to be retried multiple times
             while (retryCount <= retryLimit) {
                 let response;
                 try {
                     response = yield uploadChunkRequest();
                 }
                 catch (error) {
                     // if an error is caught, it is usually indicative of a timeout so retry the upload
                     core.info(`An error has been caught http-client index ${httpClientIndex}, retrying the upload`);
                     // eslint-disable-next-line no-console
                     console.log(error);
                     if (incrementAndCheckRetryLimit()) {
                         return false;
                     }
                     yield backOff();
                     continue;
                 }
                 // Always read the body of the response. There is potential for a resource leak if the body is not read which will
                 // result in the connection remaining open along with unintended consequences when trying to dispose of the client
                 yield response.readBody();
                 if (utils_1.isSuccessStatusCode(response.message.statusCode)) {
                     return true;
                 }
                 else if (utils_1.isRetryableStatusCode(response.message.statusCode)) {
                     core.info(`A ${response.message.statusCode} status code has been received, will attempt to retry the upload`);
                     if (incrementAndCheckRetryLimit(response)) {
                         return false;
                     }
                     utils_1.isThrottledStatusCode(response.message.statusCode)
                         ? yield backOff(utils_1.tryGetRetryAfterValueTimeInMilliseconds(response.message.headers))
                         : yield backOff();
                 }
                 else {
                     core.error(`Unexpected response. Unable to upload chunk to ${resourceUrl}`);
                     utils_1.displayHttpDiagnostics(response);
                     return false;
                 }
             }
             return false;
         });
     }
     /**
      * Updates the size of the artifact from -1 which was initially set when the container was first created for the artifact.
      * Updating the size indicates that we are done uploading all the contents of the artifact
      */
     patchArtifactSize(size, artifactName) {
         return __awaiter(this, void 0, void 0, function* () {
             const resourceUrl = new url_1.URL(utils_1.getArtifactUrl());
             resourceUrl.searchParams.append('artifactName', artifactName);
             const parameters = { Size: size };
             const data = JSON.stringify(parameters, null, 2);
             core.debug(`URL is ${resourceUrl.toString()}`);
             // use the first client from the httpManager, `keep-alive` is not used so the connection will close immediately
             const client = this.uploadHttpManager.getClient(0);
             const headers = utils_1.getUploadHeaders('application/json', false);
             // Extra information to display when a particular HTTP code is returned
             const customErrorMessages = new Map([
                 [
                     http_client_1.HttpCodes.NotFound,
                     `An Artifact with the name ${artifactName} was not found`
                 ]
             ]);
             // TODO retry for all possible response codes, the artifact upload is pretty much complete so it at all costs we should try to finish this
             const response = yield requestUtils_1.retryHttpClientRequest('Finalize artifact upload', () => __awaiter(this, void 0, void 0, function* () { return client.patch(resourceUrl.toString(), data, headers); }), customErrorMessages);
             yield response.readBody();
             core.debug(`Artifact ${artifactName} has been successfully uploaded, total size in bytes: ${size}`);
         });
     }
 }
 exports.UploadHttpClient = UploadHttpClient;
 //# sourceMappingURL=upload-http-client.js.map

 /***/ }),

 /***/ 183:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
 }) : (function(o, m, k, k2) {
     if (k2 === undefined) k2 = k;
     o[k2] = m[k];
 }));
 var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
     Object.defineProperty(o, "default", { enumerable: true, value: v });
 }) : function(o, v) {
     o["default"] = v;
 });
 var __importStar = (this && this.__importStar) || function (mod) {
     if (mod && mod.__esModule) return mod;
     var result = {};
     if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
     __setModuleDefault(result, mod);
     return result;
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.getUploadSpecification = void 0;
 const fs = __importStar(__nccwpck_require__(7147));
 const core_1 = __nccwpck_require__(2186);
 const path_1 = __nccwpck_require__(1017);
 const path_and_artifact_name_validation_1 = __nccwpck_require__(7398);
 /**
  * Creates a specification that describes how each file that is part of the artifact will be uploaded
  * @param artifactName the name of the artifact being uploaded. Used during upload to denote where the artifact is stored on the server
  * @param rootDirectory an absolute file path that denotes the path that should be removed from the beginning of each artifact file
  * @param artifactFiles a list of absolute file paths that denote what should be uploaded as part of the artifact
  */
 function getUploadSpecification(artifactName, rootDirectory, artifactFiles) {
     // artifact name was checked earlier on, no need to check again
     const specifications = [];
     if (!fs.existsSync(rootDirectory)) {
         throw new Error(`Provided rootDirectory ${rootDirectory} does not exist`);
     }
     if (!fs.lstatSync(rootDirectory).isDirectory()) {
         throw new Error(`Provided rootDirectory ${rootDirectory} is not a valid directory`);
     }
     // Normalize and resolve, this allows for either absolute or relative paths to be used
     rootDirectory = path_1.normalize(rootDirectory);
     rootDirectory = path_1.resolve(rootDirectory);
     /*
        Example to demonstrate behavior

        Input:
          artifactName: my-artifact
          rootDirectory: '/home/user/files/plz-upload'
          artifactFiles: [
            '/home/user/files/plz-upload/file1.txt',
            '/home/user/files/plz-upload/file2.txt',
            '/home/user/files/plz-upload/dir/file3.txt'
          ]

        Output:
          specifications: [
            ['/home/user/files/plz-upload/file1.txt', 'my-artifact/file1.txt'],
            ['/home/user/files/plz-upload/file1.txt', 'my-artifact/file2.txt'],
            ['/home/user/files/plz-upload/file1.txt', 'my-artifact/dir/file3.txt']
          ]
     */
     for (let file of artifactFiles) {
         if (!fs.existsSync(file)) {
             throw new Error(`File ${file} does not exist`);
         }
         if (!fs.lstatSync(file).isDirectory()) {
             // Normalize and resolve, this allows for either absolute or relative paths to be used
             file = path_1.normalize(file);
             file = path_1.resolve(file);
             if (!file.startsWith(rootDirectory)) {
                 throw new Error(`The rootDirectory: ${rootDirectory} is not a parent directory of the file: ${file}`);
             }
             // Check for forbidden characters in file paths that will be rejected during upload
             const uploadPath = file.replace(rootDirectory, '');
             path_and_artifact_name_validation_1.checkArtifactFilePath(uploadPath);
             /*
               uploadFilePath denotes where the file will be uploaded in the file container on the server. During a run, if multiple artifacts are uploaded, they will all
               be saved in the same container. The artifact name is used as the root directory in the container to separate and distinguish uploaded artifacts

               path.join handles all the following cases and would return 'artifact-name/file-to-upload.txt
                 join('artifact-name/', 'file-to-upload.txt')
                 join('artifact-name/', '/file-to-upload.txt')
                 join('artifact-name', 'file-to-upload.txt')
                 join('artifact-name', '/file-to-upload.txt')
             */
             specifications.push({
                 absoluteFilePath: file,
                 uploadFilePath: path_1.join(artifactName, uploadPath)
             });
         }
         else {
             // Directories are rejected by the server during upload
             core_1.debug(`Removing ${file} from rawSearchResults because it is a directory`);
         }
     }
     return specifications;
 }
 exports.getUploadSpecification = getUploadSpecification;
 //# sourceMappingURL=upload-specification.js.map

 /***/ }),

 /***/ 6327:
 /***/ (function(__unused_webpack_module, exports, __nccwpck_require__) {

 "use strict";

 var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
     function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
     return new (P || (P = Promise))(function (resolve, reject) {
         function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
         function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
         function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
         step((generator = generator.apply(thisArg, _arguments || [])).next());
     });
 };
 var __importDefault = (this && this.__importDefault) || function (mod) {
     return (mod && mod.__esModule) ? mod : { "default": mod };
 };
 Object.defineProperty(exports, "__esModule", ({ value: true }));
 exports.digestForStream = exports.sleep = exports.getProperRetention = exports.rmFile = exports.getFileSize = exports.createEmptyFilesForArtifact = exports.createDirectoriesForArtifact = exports.displayHttpDiagnostics = exports.getArtifactUrl = exports.createHttpClient = exports.getUploadHeaders = exports.getDownloadHeaders = exports.getContentRange = exports.tryGetRetryAfterValueTimeInMilliseconds = exports.isThrottledStatusCode = exports.isRetryableStatusCode = exports.isForbiddenStatusCode = exports.isSuccessStatusCode = exports.getApiVersion = exports.parseEnvNumber = exports.getExponentialRetryTimeInMilliseconds = void 0;
 const crypto_1 = __importDefault(__nccwpck_require__(6113));
 const fs_1 = __nccwpck_require__(7147);
 const core_1 = __nccwpck_require__(2186);
 const http_client_1 = __nccwpck_require__(6255);
 const auth_1 = __nccwpck_require__(5526);
 const config_variables_1 = __nccwpck_require__(2222);
 const crc64_1 = __importDefault(__nccwpck_require__(3549));
 /**
  * Returns a retry time in milliseconds that exponentially gets larger
  * depending on the amount of retries that have been attempted
  */
 function getExponentialRetryTimeInMilliseconds(retryCount) {
     if (retryCount < 0) {
         throw new Error('RetryCount should not be negative');
     }
     else if (retryCount === 0) {
         return config_variables_1.getInitialRetryIntervalInMilliseconds();
     }
     const minTime = config_variables_1.getInitialRetryIntervalInMilliseconds() * config_variables_1.getRetryMultiplier() * retryCount;
     const maxTime = minTime * config_variables_1.getRetryMultiplier();
     // returns a random number between the minTime (inclusive) and the maxTime (exclusive)
     return Math.trunc(Math.random() * (maxTime - minTime) + minTime);
 }
 exports.getExponentialRetryTimeInMilliseconds = getExponentialRetryTimeInMilliseconds;
 /**
  * Parses a env variable that is a number
  */
 function parseEnvNumber(key) {
     const value = Number(process.env[key]);
     if (Number.isNaN(value) || value < 0) {
         return undefined;
     }
     return value;
 }
 exports.parseEnvNumber = parseEnvNumber;
 /**
  * Various utility functions to help with the necessary API calls
  */
 function getApiVersion() {
     return '6.0-preview';
 }
 exports.getApiVersion = getApiVersion;
 function isSuccessStatusCode(statusCode) {
     if (!statusCode) {
         return false;
     }
     return statusCode >= 200 && statusCode < 300;
 }
 exports.isSuccessStatusCode = isSuccessStatusCode;
 function isForbiddenStatusCode(statusCode) {
     if (!statusCode) {
         return false;
     }
     return statusCode === http_client_1.HttpCodes.Forbidden;
 }
 exports.isForbiddenStatusCode = isForbiddenStatusCode;
 function isRetryableStatusCode(statusCode) {
     if (!statusCode) {
         return false;
     }
     const retryableStatusCodes = [
         http_client_1.HttpCodes.BadGateway,
         http_client_1.HttpCodes.GatewayTimeout,
         http_client_1.HttpCodes.InternalServerError,
         http_client_1.HttpCodes.ServiceUnavailable,
         http_client_1.HttpCodes.TooManyRequests,
         413 // Payload Too Large
     ];
     return retryableStatusCodes.includes(statusCode);
 }
 exports.isRetryableStatusCode = isRetryableStatusCode;
 function isThrottledStatusCode(statusCode) {
     if (!statusCode) {
         return false;
     }
     return statusCode === http_client_1.HttpCodes.TooManyRequests;
 }
 exports.isThrottledStatusCode = isThrottledStatusCode;
 /**
  * Attempts to get the retry-after value from a set of http headers. The retry time
  * is originally denoted in seconds, so if present, it is converted to milliseconds
  * @param headers all the headers received when making an http call
  */
 function tryGetRetryAfterValueTimeInMilliseconds(headers) {
     if (headers['retry-after']) {
         const retryTime = Number(headers['retry-after']);
         if (!isNaN(retryTime)) {
             core_1.info(`Retry-After header is present with a value of ${retryTime}`);
             return retryTime * 1000;
         }
         core_1.info(`Returned retry-after header value: ${retryTime} is non-numeric and cannot be used`);
         return undefined;
     }
     core_1.info(`No retry-after header was found. Dumping all headers for diagnostic purposes`);
     // eslint-disable-next-line no-console
     console.log(headers);
     return undefined;
 }
 exports.tryGetRetryAfterValueTimeInMilliseconds = tryGetRetryAfterValueTimeInMilliseconds;
 function getContentRange(start, end, total) {
     // Format: `bytes start-end/fileSize
     // start and end are inclusive
     // For a 200 byte chunk starting at byte 0:
     // Content-Range: bytes 0-199/200
     return `bytes ${start}-${end}/${total}`;
 }
 exports.getContentRange = getContentRange;
 /**
  * Sets all the necessary headers when downloading an artifact
  * @param {string} contentType the type of content being uploaded
  * @param {boolean} isKeepAlive is the same connection being used to make multiple calls
  * @param {boolean} acceptGzip can we accept a gzip encoded response
  * @param {string} acceptType the type of content that we can accept
  * @returns appropriate headers to make a specific http call during artifact download
  */
 function getDownloadHeaders(contentType, isKeepAlive, acceptGzip) {
     const requestOptions = {};
     if (contentType) {
         requestOptions['Content-Type'] = contentType;
     }
     if (isKeepAlive) {
         requestOptions['Connection'] = 'Keep-Alive';
         // keep alive for at least 10 seconds before closing the connection
         requestOptions['Keep-Alive'] = '10';
     }
     if (acceptGzip) {
         // if we are expecting a response with gzip encoding, it should be using an octet-stream in the accept header
         requestOptions['Accept-Encoding'] = 'gzip';
         requestOptions['Accept'] = `application/octet-stream;api-version=${getApiVersion()}`;
     }
     else {
         // default to application/json if we are not working with gzip content
         requestOptions['Accept'] = `application/json;api-version=${getApiVersion()}`;
     }
     return requestOptions;
 }
 exports.getDownloadHeaders = getDownloadHeaders;
 /**
  * Sets all the necessary headers when uploading an artifact
  * @param {string} contentType the type of content being uploaded
  * @param {boolean} isKeepAlive is the same connection being used to make multiple calls
  * @param {boolean} isGzip is the connection being used to upload GZip compressed content
  * @param {number} uncompressedLength the original size of the content if something is being uploaded that has been compressed
  * @param {number} contentLength the length of the content that is being uploaded
  * @param {string} contentRange the range of the content that is being uploaded
  * @returns appropriate headers to make a specific http call during artifact upload
  */
 function getUploadHeaders(contentType, isKeepAlive, isGzip, uncompressedLength, contentLength, contentRange, digest) {
     const requestOptions = {};
     requestOptions['Accept'] = `application/json;api-version=${getApiVersion()}`;
     if (contentType) {
         requestOptions['Content-Type'] = contentType;
     }
     if (isKeepAlive) {
         requestOptions['Connection'] = 'Keep-Alive';
         // keep alive for at least 10 seconds before closing the connection
         requestOptions['Keep-Alive'] = '10';
     }
     if (isGzip) {
         requestOptions['Content-Encoding'] = 'gzip';
         requestOptions['x-tfs-filelength'] = uncompressedLength;
     }
     if (contentLength) {
         requestOptions['Content-Length'] = contentLength;
     }
     if (contentRange) {
         requestOptions['Content-Range'] = contentRange;
     }
     if (digest) {
         requestOptions['x-actions-results-crc64'] = digest.crc64;
         requestOptions['x-actions-results-md5'] = digest.md5;
     }
     return requestOptions;
 }
 exports.getUploadHeaders = getUploadHeaders;
 function createHttpClient(userAgent) {
     return new http_client_1.HttpClient(userAgent, [
         new auth_1.BearerCredentialHandler(config_variables_1.getRuntimeToken())
     ]);
 }
 exports.createHttpClient = createHttpClient;
 function getArtifactUrl() {
     const artifactUrl = `${config_variables_1.getRuntimeUrl()}_apis/pipelines/workflows/${config_variables_1.getWorkFlowRunId()}/artifacts?api-version=${getApiVersion()}`;
     core_1.debug(`Artifact Url: ${artifactUrl}`);
     return artifactUrl;
 }
 exports.getArtifactUrl = getArtifactUrl;
 /**
  * Uh oh! Something might have gone wrong during either upload or download. The IHtttpClientResponse object contains information
  * about the http call that was made by the actions http client. This information might be useful to display for diagnostic purposes, but
  * this entire object is really big and most of the information is not really useful. This function takes the response object and displays only
  * the information that we want.
  *
  * Certain information such as the TLSSocket and the Readable state are not really useful for diagnostic purposes so they can be avoided.
  * Other information such as the headers, the response code and message might be useful, so this is displayed.
  */
 function displayHttpDiagnostics(response) {
     core_1.info(`##### Begin Diagnostic HTTP information #####
 Status Code: ${response.message.statusCode}
 Status Message: ${response.message.statusMessage}
 Header Information: ${JSON.stringify(response.message.headers, undefined, 2)}
 ###### End Diagnostic HTTP information ######`);
 }
 exports.displayHttpDiagnostics = displayHttpDiagnostics;
 function createDirectoriesForArtifact(directories) {
     return __awaiter(this, void 0, void 0, function* () {
         for (const directory of directories) {
             yield fs_1.promises.mkdir(directory, {
                 recursive: true
             });
         }
     });
 }
 exports.createDirectoriesForArtifact = createDirectoriesForArtifact;
 function createEmptyFilesForArtifact(emptyFilesToCreate) {
     return __awaiter(this, void 0, void 0, function* () {
         for (const filePath of emptyFilesToCreate) {
             yield (yield fs_1.promises.open(filePath, 'w')).close();
         }
     });
 }
 exports.createEmptyFilesForArtifact = createEmptyFilesForArtifact;
 function getFileSize(filePath) {
     return __awaiter(this, void 0, void 0, function* () {
         const stats = yield fs_1.promises.stat(filePath);
         core_1.debug(`${filePath} size:(${stats.size}) blksize:(${stats.blksize}) blocks:(${stats.blocks})`);
         return stats.size;
     });
 }
 exports.getFileSize = getFileSize;
 function rmFile(filePath) {
     return __awaiter(this, void 0, void 0, function* () {
         yield fs_1.promises.unlink(filePath);
     });
 }
 exports.rmFile = rmFile;
 function getProperRetention(retentionInput, retentionSetting) {
     if (retentionInput < 0) {
         throw new Error('Invalid retention, minimum value is 1.');
     }
     let retention = retentionInput;
     if (retentionSetting) {
         const maxRetention = parseInt(retentionSetting);
         if (!isNaN(maxRetention) && maxRetention < retention) {
             core_1.warning(`Retention days is greater than the max value allowed by the repository setting, reduce retention to ${maxRetention} days`);
             retention = maxRetention;
         }
     }
     return retention;
 }
 exports.getProperRetention = getProperRetention;
 function sleep(milliseconds) {
     return __awaiter(this, void 0, void 0, function* () {
         return new Promise(resolve => setTimeout(resolve, milliseconds));
     });
 }
 exports.sleep = sleep;
 function digestForStream(stream) {
     return __awaiter(this, void 0, void 0, function* () {
         return new Promise((resolve, reject) => {
             const crc64 = new crc64_1.default();
             const md5 = crypto_1.default.createHash('md5');
             stream
                 .on('data', data => {
                 crc64.update(data);
                 md5.update(data);
             })
                 .on('end', () => resolve({
                 crc64: crc64.digest('base64'),
                 md5: md5.digest('base64')
             }))
                 .on('error', reject);
         });
     });
 }

 */
