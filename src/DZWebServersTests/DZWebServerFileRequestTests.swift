//
//  DZWebServerFileRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

/// What one handler invocation saw.
private struct FileRequestSnapshot {
    let temporaryPath: String
    let fileContents: Data?
    let contentType: String?
    let contentLength: UInt
    let method: String
    let path: String
}

/// Collects one snapshot per request; the handler runs on a GCD thread.
private final class FileRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [FileRequestSnapshot] = []

    var snapshots: [FileRequestSnapshot] {
        self.lock.withLock { self.storage }
    }

    func record(_ request: DZWebServerFileRequest) {
        let snapshot = FileRequestSnapshot(
            temporaryPath: request.temporaryPath,
            fileContents: FileManager.default.contents(atPath: request.temporaryPath),
            contentType: request.contentType,
            contentLength: request.contentLength,
            method: request.method,
            path: request.path
        )
        self.lock.withLock { self.storage.append(snapshot) }
    }
}

/// The caller must call `server.stop()`.
private func makeFileServer(
    method: String = "POST",
    path: String = "/upload"
) throws
    -> (server: DZWebServer, recorder: FileRequestRecorder, url: URL)
{
    let server = DZWebServer()
    let recorder = FileRequestRecorder()

    server.addHandler(
        forMethod: method,
        path: path,
        request: DZWebServerFileRequest.self
    ) { request -> DZWebServerResponse? in
        recorder.record(request as! DZWebServerFileRequest)
        return DZWebServerDataResponse(text: "OK")
    }

    try TestSupport.start(server)
    let url = try #require(server.serverURL).appendingPathComponent(String(path.dropFirst()))
    return (server, recorder, url)
}

/// Sends `body` to a fresh server and returns the single snapshot its handler recorded.
private func uploadAndRecord(
    _ body: Data,
    contentType: String = "application/octet-stream"
) async throws
    -> FileRequestSnapshot
{
    let (server, recorder, url) = try makeFileServer()
    defer { server.stop() }

    let (statusCode, data, _) = try await TestSupport.sendRequest(
        method: "POST",
        url: url,
        body: body,
        headers: ["Content-Type": contentType]
    )
    #expect(statusCode == 200)
    #expect(String(data: data, encoding: .utf8) == "OK")
    return try #require(recorder.snapshots.first)
}

@Suite("DZWebServerFileRequest", .serialized, .tags(.request, .fileIO, .integration))
struct DZWebServerFileRequestTests {
    // MARK: Temporary File

    @Suite("Temporary file")
    struct TemporaryFile {
        @Test("temporaryPath is a file inside the system temporary directory that exists during the handler")
        func temporaryPathIsExistingFileInTempDirectory() async throws {
            let snapshot = try await uploadAndRecord(Data("hello".utf8))

            #expect(snapshot.temporaryPath.hasPrefix(NSTemporaryDirectory()))
            #expect(snapshot.fileContents != nil)
        }

        @Test("Consecutive requests get unique temporary files with independent contents")
        func consecutiveRequestsGetUniqueFiles() async throws {
            let (server, recorder, url) = try makeFileServer()
            defer { server.stop() }

            _ = try await TestSupport.sendRequest(method: "POST", url: url, body: Data("AAAA".utf8))
            _ = try await TestSupport.sendRequest(method: "POST", url: url, body: Data("BBBB".utf8))

            let snapshots = recorder.snapshots
            try #require(snapshots.count == 2)
            #expect(snapshots[0].temporaryPath != snapshots[1].temporaryPath)
            #expect(snapshots[0].fileContents == Data("AAAA".utf8))
            #expect(snapshots[1].fileContents == Data("BBBB".utf8))
        }

        @Test("Temporary file is removed once the request is released")
        func temporaryFileIsRemovedAfterRelease() async throws {
            let snapshot = try await uploadAndRecord(Data("cleanup-test".utf8))

            // The connection releases the request asynchronously after stop(), so poll with a deadline.
            let deadline = Date().addingTimeInterval(5)
            while FileManager.default.fileExists(atPath: snapshot.temporaryPath), Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(!FileManager.default.fileExists(atPath: snapshot.temporaryPath))
        }
    }

    // MARK: Body Content

    @Suite("Body content")
    struct BodyContent {
        @Test("Empty body creates an empty temporary file")
        func emptyBodyCreatesEmptyFile() async throws {
            let snapshot = try await uploadAndRecord(Data())

            #expect(snapshot.fileContents == Data())
        }

        @Test("All 256 byte values are stored exactly")
        func allByteValuesAreStored() async throws {
            let body = Data((0...255).map { UInt8($0) })
            let snapshot = try await uploadAndRecord(body)

            #expect(snapshot.fileContents == body)
        }

        @Test("Payloads of various sizes are stored without truncation", arguments: [1, 100 * 1024, 1024 * 1024])
        func payloadsAreStoredWithoutTruncation(size: Int) async throws {
            let body = Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ 13) })
            let snapshot = try await uploadAndRecord(body)

            #expect(snapshot.fileContents == body)
        }

        @Test(
            "Body is stored verbatim regardless of content type",
            arguments: [
                "application/json",
                "text/plain; charset=utf-8",
                "image/png",
                "application/x-www-form-urlencoded",
                "multipart/form-data",
            ]
        )
        func bodyIsStoredRegardlessOfContentType(contentType: String) async throws {
            let body = Data("Hello \u{4E16}\u{754C} \u{1F600}".utf8)
            let snapshot = try await uploadAndRecord(body, contentType: contentType)

            #expect(snapshot.fileContents == body)
            #expect(snapshot.contentType == contentType)
        }
    }

    // MARK: Request Metadata

    @Suite("Request metadata")
    struct RequestMetadata {
        @Test("contentLength, method and path match the sent request")
        func metadataMatchesSentRequest() async throws {
            let snapshot = try await uploadAndRecord(Data(repeating: 0x42, count: 512))

            #expect(snapshot.contentLength == 512)
            #expect(snapshot.method == "POST")
            #expect(snapshot.path == "/upload")
        }

        @Test("PUT request body is stored to the temporary file")
        func putRequestBodyIsStored() async throws {
            let (server, recorder, url) = try makeFileServer(method: "PUT", path: "/files/resource")
            defer { server.stop() }

            let (statusCode, _, _) = try await TestSupport.sendRequest(
                method: "PUT",
                url: url,
                body: Data("put-body-content".utf8)
            )

            #expect(statusCode == 200)
            let snapshot = try #require(recorder.snapshots.first)
            #expect(snapshot.method == "PUT")
            #expect(snapshot.path == "/files/resource")
            #expect(snapshot.fileContents == Data("put-body-content".utf8))
        }
    }
}
