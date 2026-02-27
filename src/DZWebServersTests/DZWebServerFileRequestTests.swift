//
//  DZWebServerFileRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Sendable Capture Helper

/// Thread-safe container for capturing request properties inside a handler block.
private final class FileRequestCapture: @unchecked Sendable {
    var temporaryPath: String?
    var fileContents: Data?
    var contentType: String?
    var contentLength: UInt = 0
    var method: String?
    var path: String?
    var fileExistsDuringHandler: Bool = false
}

// MARK: - Server Helpers

/// Starts a local DZWebServer bound to localhost on an ephemeral port and registers
/// a POST handler at the given path that captures file request properties.
private func makeFileServer(
    handlerPath: String = "/upload",
    capture: FileRequestCapture = FileRequestCapture()
) throws
    -> (DZWebServer, FileRequestCapture, URL)
{
    let server = DZWebServer()

    server.addHandler(
        forMethod: "POST",
        path: handlerPath,
        request: DZWebServerFileRequest.self
    ) { request -> DZWebServerResponse? in
        let fileRequest = request as! DZWebServerFileRequest
        capture.temporaryPath = fileRequest.temporaryPath
        capture.contentType = fileRequest.contentType
        capture.contentLength = fileRequest.contentLength
        capture.method = fileRequest.method
        capture.path = fileRequest.path

        let fileURL = URL(fileURLWithPath: fileRequest.temporaryPath)
        capture.fileExistsDuringHandler = FileManager.default.fileExists(atPath: fileRequest.temporaryPath)
        capture.fileContents = try? Data(contentsOf: fileURL)

        return DZWebServerDataResponse(text: "OK")
    }

    let options: [String: Any] = [
        DZWebServerOption_Port: 0,
        DZWebServerOption_BindToLocalhost: true,
    ]
    try server.start(options: options)

    let baseURL = URL(string: "http://localhost:\(server.port)")!
    let endpointURL = baseURL.appendingPathComponent(handlerPath)

    return (server, capture, endpointURL)
}

/// Sends a POST request with the given body data and content type.
private func sendFilePost(
    to url: URL,
    body: Data,
    contentType: String = "application/octet-stream"
) async throws
    -> (Data, HTTPURLResponse)
{
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, response as! HTTPURLResponse)
}

// MARK: - Root Suite

@Suite("DZWebServerFileRequest", .serialized, .tags(.request, .fileIO, .integration))
struct DZWebServerFileRequestTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Temporary File Properties

    @Suite("Temporary file properties")
    struct TemporaryFileProperties {
        @Test("POST data produces a non-nil temporaryPath")
        func temporaryPathIsNonNil() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("hello".utf8)
            let (_, response) = try await sendFilePost(to: url, body: body)

            #expect(response.statusCode == 200)
            #expect(capture.temporaryPath != nil)
        }

        @Test("POST data produces a non-empty temporaryPath")
        func temporaryPathIsNonEmpty() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("hello".utf8)
            _ = try await sendFilePost(to: url, body: body)

            let path = try #require(capture.temporaryPath)
            #expect(!path.isEmpty)
        }

        @Test("temporaryPath points to a location inside the system temporary directory")
        func temporaryPathIsInTempDirectory() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("temp-dir-check".utf8)
            _ = try await sendFilePost(to: url, body: body)

            let path = try #require(capture.temporaryPath)
            let tempDir = NSTemporaryDirectory()
            #expect(path.hasPrefix(tempDir))
        }

        @Test("File exists at temporaryPath during handler execution")
        func fileExistsDuringHandler() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("existence-check".utf8)
            _ = try await sendFilePost(to: url, body: body)

            #expect(capture.fileExistsDuringHandler == true)
        }
    }

    // MARK: - Body Content Verification

    @Suite("Body content verification")
    struct BodyContentVerification {
        @Test("File contents match the sent data for a simple string")
        func fileContentsMatchSentString() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("Hello, DZWebServer!".utf8)
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
        }

        @Test("File contents match sent data for a small payload of 100 bytes")
        func smallPayload100Bytes() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data(repeating: 0xAB, count: 100)
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
            #expect(fileContents.count == 100)
        }

        @Test("File contents match sent data for a medium payload of 100KB")
        func mediumPayload100KB() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let size = 100 * 1024
            var body = Data(count: size)
            for i in 0..<size {
                body[i] = UInt8(i % 256)
            }
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
            #expect(fileContents.count == size)
        }

        @Test("File contents match sent data for a large payload of 1MB")
        func largePayload1MB() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let size = 1024 * 1024
            var body = Data(count: size)
            for i in 0..<size {
                body[i] = UInt8(i % 256)
            }
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
            #expect(fileContents.count == size)
        }

        @Test("Binary data with all 256 byte values is stored exactly")
        func binaryDataAllByteValues() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            var body = Data(count: 256)
            for i in 0..<256 {
                body[i] = UInt8(i)
            }
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
            for i in 0..<256 {
                #expect(fileContents[i] == UInt8(i))
            }
        }

        @Test("Null bytes in body data are preserved in the temporary file")
        func nullBytesPreserved() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data([0x00, 0x00, 0xFF, 0x00, 0x00])
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
        }

        @Test("UTF-8 encoded text with multibyte characters is stored correctly")
        func utf8MultibyteChracters() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let text = "Hello \u{4E16}\u{754C} \u{1F600}"
            let body = Data(text.utf8)
            _ = try await sendFilePost(to: url, body: body, contentType: "text/plain; charset=utf-8")

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)

            let reconstructed = String(data: fileContents, encoding: .utf8)
            #expect(reconstructed == text)
        }
    }

    // MARK: - Request Metadata

    @Suite("Request metadata")
    struct RequestMetadata {
        @Test("contentType is set to the Content-Type header value sent by the client")
        func contentTypeMatchesSentHeader() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("typed-content".utf8)
            _ = try await sendFilePost(to: url, body: body, contentType: "application/pdf")

            #expect(capture.contentType == "application/pdf")
        }

        @Test("contentLength matches the size of the sent body")
        func contentLengthMatchesBodySize() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data(repeating: 0x42, count: 512)
            _ = try await sendFilePost(to: url, body: body)

            #expect(capture.contentLength == 512)
        }

        @Test("method is POST when a POST request is sent")
        func methodIsPOST() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("method-check".utf8)
            _ = try await sendFilePost(to: url, body: body)

            #expect(capture.method == "POST")
        }

        @Test("path matches the registered handler path")
        func pathMatchesHandlerPath() async throws {
            let (server, capture, url) = try makeFileServer(handlerPath: "/files/upload")
            defer { server.stop() }

            let body = Data("path-check".utf8)
            _ = try await sendFilePost(to: url, body: body)

            #expect(capture.path == "/files/upload")
        }
    }

    // MARK: - Server Response

    @Suite("Server response")
    struct ServerResponse {
        @Test("Server returns HTTP 200 for a valid POST request")
        func serverReturns200() async throws {
            let (server, _, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("ok-check".utf8)
            let (_, response) = try await sendFilePost(to: url, body: body)

            #expect(response.statusCode == 200)
        }

        @Test("Server returns the handler response body")
        func serverReturnsHandlerBody() async throws {
            let (server, _, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("body-check".utf8)
            let (responseData, _) = try await sendFilePost(to: url, body: body)

            let responseText = String(data: responseData, encoding: .utf8)
            #expect(responseText == "OK")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge cases")
    struct EdgeCases {
        @Test("POST with empty body creates a temporary file with zero bytes")
        func emptyBodyCreatesEmptyFile() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data()
            _ = try await sendFilePost(to: url, body: body)

            #expect(capture.temporaryPath != nil)
            #expect(capture.fileExistsDuringHandler == true)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents.isEmpty)
        }

        @Test("POST with single byte stores it correctly")
        func singleBytePayload() async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data([0x42])
            _ = try await sendFilePost(to: url, body: body)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents.count == 1)
            #expect(fileContents[0] == 0x42)
        }

        @Test("Consecutive POST requests each get their own unique temporaryPath")
        func consecutiveRequestsGetUniquePaths() async throws {
            let capture1 = FileRequestCapture()
            let capture2 = FileRequestCapture()
            var captureIndex = 0
            let captures = [capture1, capture2]

            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerFileRequest.self
            ) { request -> DZWebServerResponse? in
                let fileRequest = request as! DZWebServerFileRequest
                let currentCapture = captures[captureIndex]
                currentCapture.temporaryPath = fileRequest.temporaryPath
                currentCapture.fileContents = try? Data(contentsOf: URL(fileURLWithPath: fileRequest.temporaryPath))
                captureIndex += 1
                return DZWebServerDataResponse(text: "OK")
            }

            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            defer { server.stop() }

            let baseURL = try #require(URL(string: "http://localhost:\(server.port)"))
            let endpointURL = baseURL.appendingPathComponent("/upload")

            _ = try await sendFilePost(to: endpointURL, body: Data("first".utf8))
            _ = try await sendFilePost(to: endpointURL, body: Data("second".utf8))

            let path1 = try #require(capture1.temporaryPath)
            let path2 = try #require(capture2.temporaryPath)
            #expect(path1 != path2)
        }

        @Test("Consecutive POST requests store independent data")
        func consecutiveRequestsStoreIndependentData() async throws {
            let capture1 = FileRequestCapture()
            let capture2 = FileRequestCapture()
            var captureIndex = 0
            let captures = [capture1, capture2]

            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerFileRequest.self
            ) { request -> DZWebServerResponse? in
                let fileRequest = request as! DZWebServerFileRequest
                let currentCapture = captures[captureIndex]
                currentCapture.temporaryPath = fileRequest.temporaryPath
                currentCapture.fileContents = try? Data(contentsOf: URL(fileURLWithPath: fileRequest.temporaryPath))
                captureIndex += 1
                return DZWebServerDataResponse(text: "OK")
            }

            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            defer { server.stop() }

            let baseURL = try #require(URL(string: "http://localhost:\(server.port)"))
            let endpointURL = baseURL.appendingPathComponent("/upload")

            _ = try await sendFilePost(to: endpointURL, body: Data("AAAA".utf8))
            _ = try await sendFilePost(to: endpointURL, body: Data("BBBB".utf8))

            let contents1 = try #require(capture1.fileContents)
            let contents2 = try #require(capture2.fileContents)
            #expect(contents1 == Data("AAAA".utf8))
            #expect(contents2 == Data("BBBB".utf8))
        }

        @Test("POST with various content types preserves body data regardless of type", arguments: [
            "application/octet-stream",
            "application/json",
            "text/plain",
            "image/png",
            "application/x-www-form-urlencoded",
            "multipart/form-data",
        ])
        func variousContentTypesPreserveData(contentType: String) async throws {
            let (server, capture, url) = try makeFileServer()
            defer { server.stop() }

            let body = Data("content-type-test".utf8)
            _ = try await sendFilePost(to: url, body: body, contentType: contentType)

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == body)
        }
    }

    // MARK: - File Cleanup

    @Suite("File cleanup")
    struct FileCleanup {
        @Test("Temporary file is removed after the request is deallocated")
        func temporaryFileIsRemovedAfterDeallocation() async throws {
            let capture = FileRequestCapture()

            // Scope the server so the request object gets deallocated after stop
            do {
                let server = DZWebServer()
                server.addHandler(
                    forMethod: "POST",
                    path: "/upload",
                    request: DZWebServerFileRequest.self
                ) { request -> DZWebServerResponse? in
                    let fileRequest = request as! DZWebServerFileRequest
                    capture.temporaryPath = fileRequest.temporaryPath
                    capture.fileExistsDuringHandler = FileManager.default.fileExists(
                        atPath: fileRequest.temporaryPath
                    )
                    return DZWebServerDataResponse(text: "OK")
                }

                let options: [String: Any] = [
                    DZWebServerOption_Port: 0,
                    DZWebServerOption_BindToLocalhost: true,
                ]
                try server.start(options: options)

                let baseURL = try #require(URL(string: "http://localhost:\(server.port)"))
                let endpointURL = baseURL.appendingPathComponent("/upload")

                _ = try await sendFilePost(to: endpointURL, body: Data("cleanup-test".utf8))

                // The file existed during handler execution
                #expect(capture.fileExistsDuringHandler == true)

                server.stop()
            }

            // Give the runtime a moment to deallocate the request
            try await Task.sleep(for: .milliseconds(200))

            // After the request is deallocated, the temporary file should be gone
            let path = try #require(capture.temporaryPath)
            let fileStillExists = FileManager.default.fileExists(atPath: path)
            #expect(fileStillExists == false)
        }
    }

    // MARK: - PUT Method

    @Suite("PUT method support")
    struct PUTMethodSupport {
        @Test("PUT request body is stored to the temporary file correctly")
        func putRequestBodyIsStored() async throws {
            let capture = FileRequestCapture()
            let server = DZWebServer()

            server.addHandler(
                forMethod: "PUT",
                path: "/resource",
                request: DZWebServerFileRequest.self
            ) { request -> DZWebServerResponse? in
                let fileRequest = request as! DZWebServerFileRequest
                capture.temporaryPath = fileRequest.temporaryPath
                capture.fileContents = try? Data(contentsOf: URL(fileURLWithPath: fileRequest.temporaryPath))
                capture.method = fileRequest.method
                return DZWebServerDataResponse(text: "Created")
            }

            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            defer { server.stop() }

            let baseURL = try #require(URL(string: "http://localhost:\(server.port)"))
            let endpointURL = baseURL.appendingPathComponent("/resource")

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "PUT"
            request.httpBody = Data("put-body-content".utf8)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(capture.method == "PUT")

            let fileContents = try #require(capture.fileContents)
            #expect(fileContents == Data("put-body-content".utf8))
        }
    }
}
