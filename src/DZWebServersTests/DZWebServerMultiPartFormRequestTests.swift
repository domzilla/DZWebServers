//
//  DZWebServerMultiPartFormRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Multipart Form Data Request

@Suite("DZWebServerMultiPartFormRequest", .serialized, .tags(.request, .integration, .fileIO))
struct DZWebServerMultiPartFormRequestTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Helpers

    /// Thread-safe capture container for extracting request properties inside a server handler.
    private final class RequestCapture: @unchecked Sendable {
        var arguments: [DZWebServerMultiPartArgument]?
        var files: [DZWebServerMultiPartFile]?
        var firstArgumentByName: [String: DZWebServerMultiPartArgument] = [:]
        var firstFileByName: [String: DZWebServerMultiPartFile] = [:]
        var argumentControlNames: [String] = []
        var fileControlNames: [String] = []
        var fileTemporaryPaths: [String] = []
        var fileData: [String: Data] = [:]
    }

    /// Constructs a raw multipart/form-data body from the given text fields and file parts.
    private static func createMultipartBody(
        boundary: String,
        fields: [(name: String, value: String)],
        files: [(name: String, filename: String, contentType: String, data: Data)]
    )
        -> Data
    {
        var body = Data()

        for field in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(field.value)\r\n".data(using: .utf8)!)
        }

        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body
                .append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n"
                    .data(using: .utf8)!)
            body.append("Content-Type: \(file.contentType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    /// Starts a server with a multipart handler, sends a POST request with the given body,
    /// waits for the response, then stops the server. Returns the capture object.
    private static func performMultipartRequest(
        boundary: String,
        body: Data,
        capture: RequestCapture
    ) async throws
        -> (data: Data, response: URLResponse)
    {
        let server = DZWebServer()

        server.addHandler(
            forMethod: "POST",
            path: "/upload",
            request: DZWebServerMultiPartFormRequest.self
        ) { request -> DZWebServerResponse? in
            let multipartRequest = request as! DZWebServerMultiPartFormRequest

            capture.arguments = multipartRequest.arguments as? [DZWebServerMultiPartArgument]
            capture.files = multipartRequest.files as? [DZWebServerMultiPartFile]

            // Capture control names in order
            if let args = capture.arguments {
                capture.argumentControlNames = args.map(\.controlName)
            }
            if let files = capture.files {
                capture.fileControlNames = files.map(\.controlName)
                capture.fileTemporaryPaths = files.map(\.temporaryPath)

                for file in files {
                    if let data = FileManager.default.contents(atPath: file.temporaryPath) {
                        capture.fileData[file.controlName + ":" + file.fileName] = data
                    }
                }
            }

            // Capture lookup results for common names
            for arg in capture.arguments ?? [] {
                if capture.firstArgumentByName[arg.controlName] == nil {
                    capture.firstArgumentByName[arg.controlName] = multipartRequest
                        .firstArgument(forControlName: arg.controlName)
                }
            }
            for file in capture.files ?? [] {
                if capture.firstFileByName[file.controlName] == nil {
                    capture.firstFileByName[file.controlName] = multipartRequest
                        .firstFile(forControlName: file.controlName)
                }
            }

            return DZWebServerDataResponse(text: "OK")
        }

        let started = server.start(withPort: 0, bonjourName: nil)
        #expect(started == true, "Server failed to start")
        let port = server.port

        defer { server.stop() }

        var request = URLRequest(url: URL(string: "http://localhost:\(port)/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)

        return try await session.data(for: request)
    }

    // MARK: - Class Method

    @Suite("Class method")
    struct ClassMethod {
        @Test("mimeType returns multipart/form-data")
        func mimeTypeReturnsMultipartFormData() {
            let mimeType = DZWebServerMultiPartFormRequest.mimeType()

            #expect(mimeType == "multipart/form-data")
        }
    }

    // MARK: - Form Fields (Arguments)

    @Suite("Form fields (arguments)")
    struct FormFields {
        @Test("Single text field is parsed with correct controlName and string value")
        func singleTextField() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "username", value: "Dominic")],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?.first?.controlName == "username")
            #expect(capture.arguments?.first?.string == "Dominic")
        }

        @Test("Single text field data property contains the raw UTF-8 bytes")
        func singleTextFieldDataProperty() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "message", value: "hello")],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            let expectedData = "hello".data(using: .utf8)
            #expect(capture.arguments?.first?.data == expectedData)
        }

        @Test("Multiple text fields are parsed in order with correct count")
        func multipleTextFields() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [
                    (name: "first", value: "Alice"),
                    (name: "second", value: "Bob"),
                    (name: "third", value: "Charlie"),
                ],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 3)
            #expect(capture.argumentControlNames == ["first", "second", "third"])
            #expect(capture.arguments?[0].string == "Alice")
            #expect(capture.arguments?[1].string == "Bob")
            #expect(capture.arguments?[2].string == "Charlie")
        }

        @Test("Field with unicode value is parsed correctly")
        func fieldWithUnicodeValue() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let unicodeValue = "\u{1F44B} Hej v\u{00E4}rlden! \u{4F60}\u{597D}"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "greeting", value: unicodeValue)],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?.first?.string == unicodeValue)
        }

        @Test("Field with empty value is parsed as an empty string")
        func fieldWithEmptyValue() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "empty", value: "")],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?.first?.string == "")
            #expect(capture.arguments?.first?.data.count == 0)
        }

        @Test("Field with very long value is parsed completely")
        func fieldWithVeryLongValue() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let longValue = String(repeating: "ABCDEFGHIJ", count: 1000) // 10,000 characters
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "longfield", value: longValue)],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?.first?.string == longValue)
        }
    }

    // MARK: - File Uploads (Files)

    @Suite("File uploads (files)")
    struct FileUploads {
        @Test("Single file upload is parsed with correct controlName and fileName")
        func singleFileUpload() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let fileData = Data("file content here".utf8)
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "document", filename: "report.txt", contentType: "text/plain", data: fileData)]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?.count == 1)
            #expect(capture.files?.first?.controlName == "document")
            #expect(capture.files?.first?.fileName == "report.txt")
        }

        @Test("Uploaded file temporary path exists on disk")
        func fileTemporaryPathExists() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let fileData = Data("temp file test".utf8)
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(
                    name: "attachment",
                    filename: "test.dat",
                    contentType: "application/octet-stream",
                    data: fileData
                )]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.fileTemporaryPaths.count == 1)
            let tempPath = try #require(capture.fileTemporaryPaths.first)
            #expect(tempPath.isEmpty == false)
        }

        @Test("Uploaded file content matches the original data")
        func fileContentMatchesOriginal() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let originalData = Data("The quick brown fox jumps over the lazy dog.".utf8)
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "textfile", filename: "fox.txt", contentType: "text/plain", data: originalData)]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            let readData = capture.fileData["textfile:fox.txt"]
            #expect(readData == originalData)
        }

        @Test("Multiple file uploads are parsed in order with correct count")
        func multipleFileUploads() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [
                    (name: "file1", filename: "a.txt", contentType: "text/plain", data: Data("aaa".utf8)),
                    (name: "file2", filename: "b.png", contentType: "image/png", data: Data([0x89, 0x50, 0x4E, 0x47])),
                    (
                        name: "file3",
                        filename: "c.json",
                        contentType: "application/json",
                        data: Data("{\"key\":1}".utf8)
                    ),
                ]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?.count == 3)
            #expect(capture.fileControlNames == ["file1", "file2", "file3"])
            #expect(capture.files?[0].fileName == "a.txt")
            #expect(capture.files?[1].fileName == "b.png")
            #expect(capture.files?[2].fileName == "c.json")
        }

        @Test("File with unicode filename is parsed correctly")
        func fileWithUnicodeFilename() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let unicodeFilename = "\u{00FC}bersicht.txt"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "doc", filename: unicodeFilename, contentType: "text/plain", data: Data("data".utf8))]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?.count == 1)
            #expect(capture.files?.first?.fileName == unicodeFilename)
        }

        @Test("File with empty content is parsed with zero-length data on disk")
        func fileWithEmptyContent() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "empty", filename: "empty.bin", contentType: "application/octet-stream", data: Data())]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?.count == 1)
            #expect(capture.files?.first?.fileName == "empty.bin")

            let readData = capture.fileData["empty:empty.bin"]
            #expect(readData?.count == 0)
        }

        @Test("Large file upload of 100KB is parsed correctly")
        func largeFileUpload() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let largeData = Data(repeating: 0xAB, count: 100 * 1024) // 100 KB
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(
                    name: "bigfile",
                    filename: "large.bin",
                    contentType: "application/octet-stream",
                    data: largeData
                )]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?.count == 1)

            let readData = capture.fileData["bigfile:large.bin"]
            #expect(readData?.count == largeData.count)
            #expect(readData == largeData)
        }
    }

    // MARK: - Lookup Methods

    @Suite("Lookup methods")
    struct LookupMethods {
        @Test("firstArgumentForControlName returns the correct argument for an existing name")
        func firstArgumentForExistingName() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [
                    (name: "color", value: "blue"),
                    (name: "size", value: "large"),
                ],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            let colorArg = capture.firstArgumentByName["color"]
            #expect(colorArg != nil)
            #expect(colorArg?.string == "blue")

            let sizeArg = capture.firstArgumentByName["size"]
            #expect(sizeArg != nil)
            #expect(sizeArg?.string == "large")
        }

        @Test("firstArgumentForControlName returns nil for a non-existing name")
        func firstArgumentForNonExistingName() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "present", value: "yes")],
                files: []
            )

            let server = DZWebServer()
            var lookupResult: DZWebServerMultiPartArgument? = DZWebServerMultiPartArgument()

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                lookupResult = multipartRequest.firstArgument(forControlName: "nonexistent")
                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            #expect(lookupResult == nil)
        }

        @Test("firstFileForControlName returns the correct file for an existing name")
        func firstFileForExistingName() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "photo", filename: "pic.jpg", contentType: "image/jpeg", data: Data([0xFF, 0xD8]))]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            let photoFile = capture.firstFileByName["photo"]
            #expect(photoFile != nil)
            #expect(photoFile?.fileName == "pic.jpg")
            #expect(photoFile?.controlName == "photo")
        }

        @Test("firstFileForControlName returns nil for a non-existing name")
        func firstFileForNonExistingName() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "avatar", filename: "me.png", contentType: "image/png", data: Data([0x89, 0x50]))]
            )

            let server = DZWebServer()
            var lookupResult: DZWebServerMultiPartFile? = DZWebServerMultiPartFile()

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                lookupResult = multipartRequest.firstFile(forControlName: "missing")
                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            #expect(lookupResult == nil)
        }
    }

    // MARK: - Mixed Fields and Files

    @Suite("Mixed fields and files")
    struct MixedFieldsAndFiles {
        @Test("Form with both text fields and file uploads parses all parts")
        func formWithFieldsAndFiles() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let fileData = Data("PDF content simulation".utf8)
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [
                    (name: "title", value: "My Document"),
                    (name: "author", value: "Dominic"),
                ],
                files: [
                    (name: "attachment", filename: "doc.pdf", contentType: "application/pdf", data: fileData),
                ]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 2)
            #expect(capture.files?.count == 1)

            #expect(capture.arguments?[0].controlName == "title")
            #expect(capture.arguments?[0].string == "My Document")
            #expect(capture.arguments?[1].controlName == "author")
            #expect(capture.arguments?[1].string == "Dominic")
            #expect(capture.files?[0].controlName == "attachment")
            #expect(capture.files?[0].fileName == "doc.pdf")
        }

        @Test("Multiple fields with same control name returns first via firstArgumentForControlName")
        func multipleFieldsSameControlNameReturnsFirst() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [
                    (name: "tag", value: "swift"),
                    (name: "tag", value: "objc"),
                    (name: "tag", value: "testing"),
                ],
                files: []
            )

            let server = DZWebServer()
            var firstTagValue: String?
            var totalTagCount = 0

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                firstTagValue = multipartRequest.firstArgument(forControlName: "tag")?.string

                let allArgs = multipartRequest.arguments as? [DZWebServerMultiPartArgument] ?? []
                totalTagCount = allArgs.filter { $0.controlName == "tag" }.count

                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            #expect(firstTagValue == "swift")
            #expect(totalTagCount == 3)
        }

        @Test("Mixed form with multiple fields and multiple files preserves order")
        func mixedFormPreservesOrder() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [
                    (name: "name", value: "Test"),
                    (name: "description", value: "A test upload"),
                ],
                files: [
                    (
                        name: "image",
                        filename: "photo.jpg",
                        contentType: "image/jpeg",
                        data: Data([0xFF, 0xD8, 0xFF, 0xE0])
                    ),
                    (
                        name: "thumbnail",
                        filename: "thumb.png",
                        contentType: "image/png",
                        data: Data([0x89, 0x50, 0x4E, 0x47])
                    ),
                ]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 2)
            #expect(capture.files?.count == 2)

            #expect(capture.argumentControlNames == ["name", "description"])
            #expect(capture.fileControlNames == ["image", "thumbnail"])
        }
    }

    // MARK: - MultiPart Properties

    @Suite("MultiPart base properties")
    struct MultiPartProperties {
        @Test("controlName is correct for each argument part")
        func controlNameIsCorrectForArguments() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [
                    (name: "alpha", value: "1"),
                    (name: "beta", value: "2"),
                ],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?[0].controlName == "alpha")
            #expect(capture.arguments?[1].controlName == "beta")
        }

        @Test("controlName is correct for each file part")
        func controlNameIsCorrectForFiles() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [
                    (
                        name: "primary",
                        filename: "main.bin",
                        contentType: "application/octet-stream",
                        data: Data([0x01])
                    ),
                    (
                        name: "secondary",
                        filename: "alt.bin",
                        contentType: "application/octet-stream",
                        data: Data([0x02])
                    ),
                ]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?[0].controlName == "primary")
            #expect(capture.files?[1].controlName == "secondary")
        }

        @Test("contentType defaults to text/plain for arguments without explicit Content-Type")
        func contentTypeDefaultsToTextPlain() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            // Standard multipart form fields do not include a Content-Type header;
            // per RFC 2388, the default is "text/plain".
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "field", value: "value")],
                files: []
            )

            let server = DZWebServer()
            var capturedContentType: String?

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                capturedContentType = (multipartRequest.arguments as? [DZWebServerMultiPartArgument])?.first?
                    .contentType
                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            #expect(capturedContentType == "text/plain")
        }

        @Test("mimeType on a file part matches the provided content type")
        func mimeTypeOnFileMatchesProvidedContentType() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(name: "img", filename: "pic.png", contentType: "image/png", data: Data([0x89]))]
            )

            let server = DZWebServer()
            var capturedMimeType: String?

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                capturedMimeType = (multipartRequest.files as? [DZWebServerMultiPartFile])?.first?.mimeType
                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            #expect(capturedMimeType == "image/png")
        }

        @Test("mimeType strips parameters from content type string")
        func mimeTypeStripsParameters() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"

            // Manually construct a multipart body where the file part has
            // a Content-Type with parameters (e.g., "text/plain; charset=utf-8").
            var body = Data()
            try body.append(#require("--\(boundary)\r\n".data(using: .utf8)))
            try body
                .append(#require("Content-Disposition: form-data; name=\"doc\"; filename=\"notes.txt\"\r\n"
                        .data(using: .utf8)))
            try body.append(#require("Content-Type: text/plain; charset=utf-8\r\n\r\n".data(using: .utf8)))
            try body.append(#require("Some notes".data(using: .utf8)))
            try body.append(#require("\r\n".data(using: .utf8)))
            try body.append(#require("--\(boundary)--\r\n".data(using: .utf8)))

            let server = DZWebServer()
            var capturedContentType: String?
            var capturedMimeType: String?

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                let file = (multipartRequest.files as? [DZWebServerMultiPartFile])?.first
                capturedContentType = file?.contentType
                capturedMimeType = file?.mimeType
                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            // contentType should include the full value with parameters
            #expect(capturedContentType == "text/plain; charset=utf-8")
            // mimeType should strip parameters
            #expect(capturedMimeType == "text/plain")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge cases")
    struct EdgeCases {
        @Test("Empty form with no fields and no files produces empty arrays")
        func emptyForm() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 0)
            #expect(capture.files?.count == 0)
        }

        @Test("Field with special characters in name is parsed correctly")
        func fieldWithSpecialCharactersInName() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "field-name_with.special", value: "specialvalue")],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?.first?.controlName == "field-name_with.special")
            #expect(capture.arguments?.first?.string == "specialvalue")
        }

        @Test("Binary file data with all byte values is preserved exactly")
        func binaryFileDataPreserved() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            var binaryData = Data()
            for i: UInt8 in 0...255 {
                binaryData.append(i)
            }
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(
                    name: "binary",
                    filename: "allbytes.bin",
                    contentType: "application/octet-stream",
                    data: binaryData
                )]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            let readData = capture.fileData["binary:allbytes.bin"]
            #expect(readData == binaryData)
        }

        @Test("Field value containing boundary-like text does not confuse the parser")
        func fieldValueContainingBoundaryLikeText() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            // The value contains text that looks like a boundary marker but is not one.
            let trickyValue = "This has --SomeBoundary in it"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [(name: "tricky", value: trickyValue)],
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?.first?.string == trickyValue)
        }

        @Test("Form with many fields processes all of them")
        func formWithManyFields() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            var fields: [(name: String, value: String)] = []
            for i in 0..<50 {
                fields.append((name: "field_\(i)", value: "value_\(i)"))
            }
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: fields,
                files: []
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.arguments?.count == 50)

            for i in 0..<50 {
                #expect(capture.arguments?[i].controlName == "field_\(i)")
                #expect(capture.arguments?[i].string == "value_\(i)")
            }
        }

        @Test("File with spaces in filename is parsed correctly")
        func fileWithSpacesInFilename() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [(
                    name: "doc",
                    filename: "my document file.txt",
                    contentType: "text/plain",
                    data: Data("content".utf8)
                )]
            )

            let capture = RequestCapture()
            _ = try await DZWebServerMultiPartFormRequestTests.performMultipartRequest(
                boundary: boundary,
                body: body,
                capture: capture
            )

            #expect(capture.files?.count == 1)
            #expect(capture.files?.first?.fileName == "my document file.txt")
        }

        @Test("Argument string property returns nil for binary content type")
        func argumentStringReturnsNilForBinaryContentType() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"

            // Manually construct a part with a non-text content type to test that
            // the string property returns nil.
            var body = Data()
            try body.append(#require("--\(boundary)\r\n".data(using: .utf8)))
            try body.append(#require("Content-Disposition: form-data; name=\"binaryarg\"\r\n".data(using: .utf8)))
            try body.append(#require("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)))
            body.append(Data([0x00, 0x01, 0x02, 0x03]))
            try body.append(#require("\r\n".data(using: .utf8)))
            try body.append(#require("--\(boundary)--\r\n".data(using: .utf8)))

            let server = DZWebServer()
            var capturedString: String? = "placeholder"
            var capturedData: Data?

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                let arg = (multipartRequest.arguments as? [DZWebServerMultiPartArgument])?.first
                capturedString = arg?.string
                capturedData = arg?.data
                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            // string should be nil because content type is not text/*
            #expect(capturedString == nil)
            // data should still contain the raw bytes
            #expect(capturedData == Data([0x00, 0x01, 0x02, 0x03]))
        }

        @Test("Multiple files with same control name returns first via firstFileForControlName")
        func multipleFilesSameControlNameReturnsFirst() async throws {
            let boundary = "TestBoundary-\(UUID().uuidString)"
            let body = DZWebServerMultiPartFormRequestTests.createMultipartBody(
                boundary: boundary,
                fields: [],
                files: [
                    (name: "attachment", filename: "first.txt", contentType: "text/plain", data: Data("one".utf8)),
                    (name: "attachment", filename: "second.txt", contentType: "text/plain", data: Data("two".utf8)),
                ]
            )

            let server = DZWebServer()
            var firstFileName: String?
            var totalFileCount = 0

            server.addHandler(
                forMethod: "POST",
                path: "/upload",
                request: DZWebServerMultiPartFormRequest.self
            ) { request -> DZWebServerResponse? in
                let multipartRequest = request as! DZWebServerMultiPartFormRequest
                firstFileName = multipartRequest.firstFile(forControlName: "attachment")?.fileName

                let allFiles = multipartRequest.files as? [DZWebServerMultiPartFile] ?? []
                totalFileCount = allFiles.filter { $0.controlName == "attachment" }.count

                return DZWebServerDataResponse(text: "OK")
            }

            let started = server.start(withPort: 0, bonjourName: nil)
            #expect(started == true)
            defer { server.stop() }

            var request = try URLRequest(url: #require(URL(string: "http://localhost:\(server.port)/upload")))
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10
            _ = try await URLSession(configuration: config).data(for: request)

            #expect(firstFileName == "first.txt")
            #expect(totalFileCount == 2)
        }
    }
}
