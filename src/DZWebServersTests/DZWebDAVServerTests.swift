//
//  DZWebDAVServerTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

// MARK: - Root Suite

@Suite("DZWebDAVServer", .serialized, .tags(.webDAV))
struct DZWebDAVServerTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Helpers

    /// Creates a DZWebDAVServer with a unique temporary upload directory, starts it on
    /// an ephemeral localhost port, and returns the server, base URL, and upload directory path.
    private func makeServer() throws -> (DZWebDAVServer, URL, String) {
        let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let server = DZWebDAVServer(uploadDirectory: dir)
        let options: [String: Any] = [
            DZWebServerOption_Port: 0,
            DZWebServerOption_BindToLocalhost: true,
        ]
        try server.start(options: options)
        let baseURL = try #require(server.serverURL)
        return (server, baseURL, dir)
    }

    /// Creates a DZWebDAVServer with custom configuration (not started).
    private func makeConfiguredServer(dir: String) -> DZWebDAVServer {
        DZWebDAVServer(uploadDirectory: dir)
    }

    /// Sends an HTTP request with the given method, optional body, and optional headers.
    private func sendRequest(
        method: String,
        url: URL,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws
        -> (statusCode: Int, data: Data, response: HTTPURLResponse)
    {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        return (httpResponse.statusCode, data, httpResponse)
    }

    /// Writes a file with the given content at a path relative to the upload directory.
    @discardableResult
    private func writeFile(
        named name: String,
        content: Data,
        inDirectory dir: String
    ) throws
        -> String
    {
        let path = (dir as NSString).appendingPathComponent(name)
        let parentDir = (path as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parentDir) {
            try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }
        try content.write(to: URL(fileURLWithPath: path))
        return path
    }

    /// Creates a subdirectory inside the upload directory.
    @discardableResult
    private func createSubdirectory(
        named name: String,
        inDirectory dir: String
    ) throws
        -> String
    {
        let path = (dir as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    // MARK: - Initialization

    @Suite("Initialization", .serialized, .tags(.properties))
    struct Initialization {
        private let parent = DZWebDAVServerTests()

        @Test("initWithUploadDirectory stores the path in uploadDirectory")
        func initStoresUploadDirectory() throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-init-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)

            #expect(server.uploadDirectory == dir)
        }

        @Test("Server can start on port 0 with localhost binding")
        func serverStartsOnEphemeralPort() throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            #expect(server.isRunning == true)
            #expect(server.port > 0)
            #expect(baseURL.scheme == "http")
        }

        @Test("uploadDirectory matches the path given at init")
        func uploadDirectoryMatchesInitPath() throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-match-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)

            #expect(server.uploadDirectory == dir)
        }

        @Test("Server can be stopped after starting")
        func serverCanBeStopped() throws {
            let (server, _, dir) = try parent.makeServer()
            defer { try? FileManager.default.removeItem(atPath: dir) }

            server.stop()

            #expect(server.isRunning == false)
        }
    }

    // MARK: - Property Defaults and Mutation

    @Suite("Property Defaults and Mutation", .serialized, .tags(.properties))
    struct PropertyDefaultsAndMutation {
        @Test("allowedFileExtensions defaults to nil")
        func allowedFileExtensionsDefaultNil() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-props-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)

            #expect(server.allowedFileExtensions == nil)
        }

        @Test("allowHiddenItems defaults to false")
        func allowHiddenItemsDefaultFalse() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidden-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)

            #expect(server.allowHiddenItems == false)
        }

        @Test("allowedFileExtensions can be set and read back")
        func allowedFileExtensionsSettable() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-ext-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)
            server.allowedFileExtensions = ["txt", "pdf", "jpg"]

            #expect(server.allowedFileExtensions == ["txt", "pdf", "jpg"])
        }

        @Test("allowedFileExtensions can be set back to nil")
        func allowedFileExtensionsResettableToNil() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extnull-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)
            server.allowedFileExtensions = ["txt"]
            server.allowedFileExtensions = nil

            #expect(server.allowedFileExtensions == nil)
        }

        @Test("allowHiddenItems can be set to true")
        func allowHiddenItemsSettable() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidset-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)
            server.allowHiddenItems = true

            #expect(server.allowHiddenItems == true)
        }

        @Test("allowHiddenItems can be toggled back to false")
        func allowHiddenItemsToggleable() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidtoggle-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)
            server.allowHiddenItems = true
            server.allowHiddenItems = false

            #expect(server.allowHiddenItems == false)
        }

        @Test("delegate is nil by default")
        func delegateDefaultNil() {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-del-\(UUID().uuidString)"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let server = DZWebDAVServer(uploadDirectory: dir)

            #expect(server.delegate == nil)
        }
    }

    // MARK: - OPTIONS

    @Suite("OPTIONS", .serialized, .tags(.integration))
    struct OPTIONSTests {
        private let parent = DZWebDAVServerTests()

        @Test("OPTIONS returns 200 with Allow header containing WebDAV methods")
        func optionsReturnsAllowHeader() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let result = try await parent.sendRequest(method: "OPTIONS", url: baseURL)

            #expect(result.statusCode == 200)
        }

        @Test("OPTIONS response includes DAV header advertising class 1")
        func optionsReturnsDavClass1() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let result = try await parent.sendRequest(method: "OPTIONS", url: baseURL)
            let davHeader = result.response.value(forHTTPHeaderField: "DAV")

            #expect(davHeader != nil, "OPTIONS response should include a DAV header")
            #expect(davHeader?.contains("1") == true, "DAV header should advertise class 1 compliance")
        }
    }

    // MARK: - GET (Download)

    @Suite("GET (Download)", .serialized, .tags(.integration, .fileIO))
    struct GETTests {
        private let parent = DZWebDAVServerTests()

        @Test("GET an existing file returns 200 with correct content")
        func getExistingFileReturns200() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let content = Data("Hello, WebDAV GET!".utf8)
            try self.parent.writeFile(named: "readable.txt", content: content, inDirectory: dir)

            let fileURL = baseURL.appendingPathComponent("readable.txt")
            let result = try await parent.sendRequest(method: "GET", url: fileURL)

            #expect(result.statusCode == 200)
            #expect(result.data == content, "GET response body should match the file content")
        }

        @Test("GET a non-existent file returns 404")
        func getNonExistentFileReturns404() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("does_not_exist.txt")
            let result = try await parent.sendRequest(method: "GET", url: fileURL)

            #expect(result.statusCode == 404)
        }

        @Test("GET a directory returns 200 with empty body")
        func getDirectoryReturns200EmptyBody() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.createSubdirectory(named: "subdir", inDirectory: dir)

            let dirURL = baseURL.appendingPathComponent("subdir")
            let result = try await parent.sendRequest(method: "GET", url: dirURL)

            #expect(result.statusCode == 200)
        }

        @Test("GET Content-Type matches file extension for known types")
        func getContentTypeMatchesExtension() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "page.html", content: Data("<html></html>".utf8), inDirectory: dir)

            let fileURL = baseURL.appendingPathComponent("page.html")
            let result = try await parent.sendRequest(method: "GET", url: fileURL)

            #expect(result.statusCode == 200)

            let contentType = result.response.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(
                contentType.contains("html"),
                "Content-Type for .html file should contain 'html', got: \(contentType)"
            )
        }
    }

    // MARK: - PUT (Upload)

    @Suite("PUT (Upload)", .serialized, .tags(.integration, .fileIO))
    struct PUTTests {
        private let parent = DZWebDAVServerTests()

        @Test("PUT a new file returns 201 and creates the file on disk")
        func putNewFileReturns201() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("hello.txt")
            let body = Data("Hello, WebDAV!".utf8)
            let result = try await parent.sendRequest(method: "PUT", url: fileURL, body: body)

            #expect(result.statusCode == 201)

            let filePath = (dir as NSString).appendingPathComponent("hello.txt")
            #expect(
                FileManager.default.fileExists(atPath: filePath),
                "File should exist on disk after PUT"
            )
        }

        @Test("PUT overwrites an existing file and returns 204")
        func putOverwriteReturns204() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("overwrite.txt")

            let r1 = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("version 1".utf8))
            #expect(r1.statusCode == 201)

            let r2 = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("version 2".utf8))
            #expect(r2.statusCode == 204)
        }

        @Test("PUT file content on disk matches the sent body")
        func putBodyDataMatchesDiskContent() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let body = Data("Exact content to verify".utf8)
            let fileURL = baseURL.appendingPathComponent("content_check.txt")
            _ = try await self.parent.sendRequest(method: "PUT", url: fileURL, body: body)

            let filePath = (dir as NSString).appendingPathComponent("content_check.txt")
            let savedData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            #expect(savedData == body, "Saved file content should match the PUT body")
        }

        @Test("PUT into a subdirectory succeeds when the directory exists")
        func putInSubdirectory() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.createSubdirectory(named: "docs", inDirectory: dir)

            let fileURL = baseURL.appendingPathComponent("docs/readme.txt")
            let body = Data("In a subdirectory".utf8)
            let result = try await parent.sendRequest(method: "PUT", url: fileURL, body: body)

            #expect(result.statusCode == 201)

            let filePath = (dir as NSString).appendingPathComponent("docs/readme.txt")
            let savedData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            #expect(savedData == body)
        }

        @Test("PUT into a non-existent parent directory returns 409 Conflict")
        func putMissingParentReturns409() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("nonexistent/dir/file.txt")
            let result = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("data".utf8))

            #expect(result.statusCode == 409)
        }

        @Test("PUT an empty file creates a zero-byte file on disk")
        func putEmptyFile() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("empty.txt")
            let result = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data())

            #expect(result.statusCode == 201)

            let filePath = (dir as NSString).appendingPathComponent("empty.txt")
            let savedData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            #expect(savedData.isEmpty, "Empty PUT should create a zero-byte file")
        }

        @Test("PUT a large file (100KB) succeeds and contents match")
        func putLargeFile() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let largeBody = Data(repeating: 0x42, count: 100 * 1024)
            let fileURL = baseURL.appendingPathComponent("large_file.bin")
            let result = try await parent.sendRequest(method: "PUT", url: fileURL, body: largeBody)

            #expect(result.statusCode == 201)

            let filePath = (dir as NSString).appendingPathComponent("large_file.bin")
            let savedData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            #expect(savedData == largeBody, "Large file content should match the PUT body")
        }
    }

    // MARK: - DELETE

    @Suite("DELETE", .serialized, .tags(.integration, .fileIO))
    struct DELETETests {
        private let parent = DZWebDAVServerTests()

        @Test("DELETE an existing file returns 204 and removes it from disk")
        func deleteExistingFileReturns204() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "deleteme.txt", content: Data("delete this".utf8), inDirectory: dir)

            let fileURL = baseURL.appendingPathComponent("deleteme.txt")
            let result = try await parent.sendRequest(method: "DELETE", url: fileURL)

            #expect(result.statusCode == 204)

            let filePath = (dir as NSString).appendingPathComponent("deleteme.txt")
            #expect(
                !FileManager.default.fileExists(atPath: filePath),
                "File should no longer exist after DELETE"
            )
        }

        @Test("DELETE a non-existent file returns 404")
        func deleteNonExistentFileReturns404() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("ghost.txt")
            let result = try await parent.sendRequest(method: "DELETE", url: fileURL)

            #expect(result.statusCode == 404)
        }

        @Test("DELETE a directory removes it and all its contents recursively")
        func deleteDirectoryRemovesContents() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let subDir = try parent.createSubdirectory(named: "folder", inDirectory: dir)
            try self.parent.writeFile(named: "inside.txt", content: Data("nested".utf8), inDirectory: subDir)

            let dirURL = baseURL.appendingPathComponent("folder")
            let result = try await parent.sendRequest(method: "DELETE", url: dirURL)

            #expect(result.statusCode == 204)
            #expect(
                !FileManager.default.fileExists(atPath: subDir),
                "Directory should no longer exist after DELETE"
            )
        }
    }

    // MARK: - MKCOL (Create Directory)

    @Suite("MKCOL (Create Directory)", .serialized, .tags(.integration, .fileIO))
    struct MKCOLTests {
        private let parent = DZWebDAVServerTests()

        @Test("MKCOL creates a new directory and returns 201")
        func mkcolCreatesDirectoryReturns201() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let dirURL = baseURL.appendingPathComponent("newdir")
            let result = try await parent.sendRequest(method: "MKCOL", url: dirURL)

            #expect(result.statusCode == 201)

            let dirPath = (dir as NSString).appendingPathComponent("newdir")
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory)
            #expect(
                exists && isDirectory.boolValue,
                "MKCOL should create a directory on disk"
            )
        }

        @Test("MKCOL on an existing directory returns 500 (filesystem error)")
        func mkcolOnExistingDirectoryReturns500() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.createSubdirectory(named: "existing", inDirectory: dir)

            let dirURL = baseURL.appendingPathComponent("existing")
            let result = try await parent.sendRequest(method: "MKCOL", url: dirURL)

            // createDirectoryAtPath:withIntermediateDirectories:NO fails when the directory
            // already exists, yielding a 500 Internal Server Error.
            #expect(
                result.statusCode == 500,
                "MKCOL on existing directory should fail with 500 Internal Server Error"
            )
        }

        @Test("MKCOL with missing parent directory returns 409 Conflict")
        func mkcolMissingParentReturns409() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let dirURL = baseURL.appendingPathComponent("parent/child")
            let result = try await parent.sendRequest(method: "MKCOL", url: dirURL)

            #expect(result.statusCode == 409)
        }
    }

    // MARK: - COPY

    @Suite("COPY", .serialized, .tags(.integration, .fileIO))
    struct COPYTests {
        private let parent = DZWebDAVServerTests()

        @Test("COPY a file with Destination header creates a copy and preserves the source")
        func copyFileCreatesDestination() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "original.txt", content: Data("copy me".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("original.txt")
            let destinationHeader = "\(baseURL.absoluteString)copy.txt"
            let result = try await parent.sendRequest(
                method: "COPY",
                url: sourceURL,
                headers: ["Destination": destinationHeader]
            )

            #expect(result.statusCode == 201)

            // Source still exists
            let srcPath = (dir as NSString).appendingPathComponent("original.txt")
            #expect(
                FileManager.default.fileExists(atPath: srcPath),
                "Source file should still exist after COPY"
            )

            // Destination exists with matching content
            let dstPath = (dir as NSString).appendingPathComponent("copy.txt")
            #expect(
                FileManager.default.fileExists(atPath: dstPath),
                "Destination file should exist after COPY"
            )

            let copiedContent = try Data(contentsOf: URL(fileURLWithPath: dstPath))
            #expect(
                copiedContent == Data("copy me".utf8),
                "Copied file content should match the source"
            )
        }

        @Test("COPY without Destination header returns 400")
        func copyWithoutDestinationReturns400() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "source.txt", content: Data("data".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("source.txt")
            let result = try await parent.sendRequest(method: "COPY", url: sourceURL)

            #expect(result.statusCode == 400)
        }

        @Test("COPY with Overwrite:F when destination exists returns 412 Precondition Failed")
        func copyOverwriteFWhenDestExistsReturns412() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "src.txt", content: Data("source".utf8), inDirectory: dir)
            try self.parent.writeFile(named: "dst.txt", content: Data("existing".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("src.txt")
            let destinationHeader = "\(baseURL.absoluteString)dst.txt"
            let result = try await parent.sendRequest(
                method: "COPY",
                url: sourceURL,
                headers: [
                    "Destination": destinationHeader,
                    "Overwrite": "F",
                ]
            )

            #expect(result.statusCode == 412)
        }

        @Test("COPY a directory duplicates it recursively with all contents")
        func copyDirectoryRecursively() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let srcDir = try parent.createSubdirectory(named: "srcdir", inDirectory: dir)
            try self.parent.writeFile(named: "nested.txt", content: Data("nested content".utf8), inDirectory: srcDir)

            let sourceURL = baseURL.appendingPathComponent("srcdir")
            let destinationHeader = "\(baseURL.absoluteString)dstdir"
            let result = try await parent.sendRequest(
                method: "COPY",
                url: sourceURL,
                headers: ["Destination": destinationHeader]
            )

            #expect(result.statusCode == 201)

            let copiedFilePath = ((dir as NSString).appendingPathComponent("dstdir") as NSString)
                .appendingPathComponent("nested.txt")
            #expect(
                FileManager.default.fileExists(atPath: copiedFilePath),
                "Recursive COPY should include files inside the directory"
            )

            let copiedContent = try Data(contentsOf: URL(fileURLWithPath: copiedFilePath))
            #expect(copiedContent == Data("nested content".utf8))
        }
    }

    // MARK: - MOVE

    @Suite("MOVE", .serialized, .tags(.integration, .fileIO))
    struct MOVETests {
        private let parent = DZWebDAVServerTests()

        @Test("MOVE a file with Destination header relocates it")
        func moveFileRemovesSourceCreatesDestination() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "moveme.txt", content: Data("move content".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("moveme.txt")
            let destinationHeader = "\(baseURL.absoluteString)moved.txt"
            let result = try await parent.sendRequest(
                method: "MOVE",
                url: sourceURL,
                headers: [
                    "Destination": destinationHeader,
                    "Overwrite": "T",
                ]
            )

            #expect(result.statusCode == 201)

            // Source should be gone
            let srcPath = (dir as NSString).appendingPathComponent("moveme.txt")
            #expect(
                !FileManager.default.fileExists(atPath: srcPath),
                "Source file should not exist after MOVE"
            )

            // Destination should exist with correct content
            let dstPath = (dir as NSString).appendingPathComponent("moved.txt")
            let movedContent = try Data(contentsOf: URL(fileURLWithPath: dstPath))
            #expect(
                movedContent == Data("move content".utf8),
                "Moved file content should match the original"
            )
        }

        @Test("MOVE without Destination header returns 400")
        func moveWithoutDestinationReturns400() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "orphan.txt", content: Data("data".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("orphan.txt")
            let result = try await parent.sendRequest(
                method: "MOVE",
                url: sourceURL,
                headers: ["Overwrite": "T"]
            )

            #expect(result.statusCode == 400)
        }

        @Test("MOVE to existing destination without Overwrite:T returns 412 Precondition Failed")
        func moveToExistingWithoutOverwriteTReturns412() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "src_move.txt", content: Data("source".utf8), inDirectory: dir)
            try self.parent.writeFile(named: "dst_move.txt", content: Data("dest".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("src_move.txt")
            let destinationHeader = "\(baseURL.absoluteString)dst_move.txt"
            let result = try await parent.sendRequest(
                method: "MOVE",
                url: sourceURL,
                headers: [
                    "Destination": destinationHeader,
                    "Overwrite": "F",
                ]
            )

            #expect(result.statusCode == 412)
        }

        @Test("MOVE to existing destination with Overwrite:T replaces destination and returns 204")
        func moveToExistingWithOverwriteTReturns204() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "from.txt", content: Data("new data".utf8), inDirectory: dir)
            try self.parent.writeFile(named: "to.txt", content: Data("old data".utf8), inDirectory: dir)

            let sourceURL = baseURL.appendingPathComponent("from.txt")
            let destinationHeader = "\(baseURL.absoluteString)to.txt"
            let result = try await parent.sendRequest(
                method: "MOVE",
                url: sourceURL,
                headers: [
                    "Destination": destinationHeader,
                    "Overwrite": "T",
                ]
            )

            #expect(result.statusCode == 204)

            let dstPath = (dir as NSString).appendingPathComponent("to.txt")
            let movedContent = try Data(contentsOf: URL(fileURLWithPath: dstPath))
            #expect(
                movedContent == Data("new data".utf8),
                "Destination content should be from the source after MOVE with Overwrite:T"
            )
        }

        @Test("MOVE a directory relocates it with all contents")
        func moveDirectoryRelocatesContents() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let srcDir = try parent.createSubdirectory(named: "move_src", inDirectory: dir)
            try self.parent.writeFile(named: "inside.txt", content: Data("nested data".utf8), inDirectory: srcDir)

            let sourceURL = baseURL.appendingPathComponent("move_src")
            let destinationHeader = "\(baseURL.absoluteString)move_dst"
            let result = try await parent.sendRequest(
                method: "MOVE",
                url: sourceURL,
                headers: [
                    "Destination": destinationHeader,
                    "Overwrite": "T",
                ]
            )

            #expect(result.statusCode == 201)

            // Source should be gone
            #expect(
                !FileManager.default.fileExists(atPath: srcDir),
                "Source directory should not exist after MOVE"
            )

            // Destination should exist with contents
            let dstFilePath = ((dir as NSString).appendingPathComponent("move_dst") as NSString)
                .appendingPathComponent("inside.txt")
            #expect(
                FileManager.default.fileExists(atPath: dstFilePath),
                "Moved directory should contain its original files"
            )
        }
    }

    // MARK: - PROPFIND

    @Suite("PROPFIND", .serialized, .tags(.integration))
    struct PROPFINDTests {
        private let parent = DZWebDAVServerTests()

        @Test("PROPFIND on root with Depth:0 returns 207 with multistatus XML")
        func propfindRootDepth0Returns207() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "0"]
            )

            #expect(result.statusCode == 207)

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("multistatus"),
                "PROPFIND response should contain a DAV:multistatus element"
            )
            #expect(
                xmlString.contains("response"),
                "PROPFIND response should contain at least one DAV:response element"
            )
        }

        @Test("PROPFIND on root with Depth:1 returns root and children")
        func propfindDepth1ReturnsChildren() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "file1.txt", content: Data("one".utf8), inDirectory: dir)
            try self.parent.writeFile(named: "file2.txt", content: Data("two".utf8), inDirectory: dir)
            try self.parent.createSubdirectory(named: "subdir", inDirectory: dir)

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "1"]
            )

            #expect(result.statusCode == 207)

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("file1.txt"),
                "PROPFIND Depth:1 should list file1.txt"
            )
            #expect(
                xmlString.contains("file2.txt"),
                "PROPFIND Depth:1 should list file2.txt"
            )
            #expect(
                xmlString.contains("subdir"),
                "PROPFIND Depth:1 should list subdirectories"
            )
        }

        @Test("PROPFIND with Depth:0 returns only the resource itself, not children")
        func propfindDepth0DoesNotReturnChildren() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "child.txt", content: Data("child".utf8), inDirectory: dir)

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "0"]
            )

            #expect(result.statusCode == 207)

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                !xmlString.contains("child.txt"),
                "PROPFIND Depth:0 should not list child items"
            )
        }

        @Test("PROPFIND response is XML with multistatus namespace")
        func propfindResponseIsXml() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "0"]
            )

            let contentType = result.response.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(
                contentType.contains("xml"),
                "PROPFIND Content-Type should be XML, got: \(contentType)"
            )

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("DAV:"),
                "PROPFIND response should reference the DAV: namespace"
            )
        }

        @Test("PROPFIND includes file sizes in response")
        func propfindIncludesFileSizes() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let content = Data("twelve bytes".utf8) // 12 bytes
            try self.parent.writeFile(named: "sized.txt", content: content, inDirectory: dir)

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "1"]
            )

            #expect(result.statusCode == 207)

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("getcontentlength"),
                "PROPFIND response should include getcontentlength property"
            )
        }

        @Test("PROPFIND includes dates in response")
        func propfindIncludesDates() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            try self.parent.writeFile(named: "dated.txt", content: Data("data".utf8), inDirectory: dir)

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "1"]
            )

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("creationdate") || xmlString.contains("getlastmodified"),
                "PROPFIND response should include date properties"
            )
        }

        @Test("PROPFIND includes collection resource type for directories")
        func propfindIncludesCollectionResourceType() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "0"]
            )

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("collection"),
                "PROPFIND on a directory should include a collection resourcetype"
            )
        }

        @Test("PROPFIND on a non-existent resource returns 404")
        func propfindNonExistentReturns404() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("nonexistent.txt")
            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: fileURL,
                headers: ["Depth": "0"]
            )

            #expect(result.statusCode == 404)
        }

        @Test("PROPFIND without Depth header returns 400")
        func propfindWithoutDepthHeaderReturns400() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let result = try await parent.sendRequest(method: "PROPFIND", url: baseURL)

            #expect(result.statusCode == 400)
        }
    }

    // MARK: - File Extensions Filter

    @Suite("File Extensions Filter", .serialized, .tags(.integration, .fileIO))
    struct FileExtensionsFilter {
        private let parent = DZWebDAVServerTests()

        /// Creates a server with allowedFileExtensions configured and started.
        private func makeFilteredServer(
            extensions: [String],
            dir: String
        ) throws
            -> (DZWebDAVServer, URL)
        {
            let server = DZWebDAVServer(uploadDirectory: dir)
            server.allowedFileExtensions = extensions
            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            let baseURL = try #require(server.serverURL)
            return (server, baseURL)
        }

        @Test("allowedFileExtensions = ['txt'] allows PUT of .txt file")
        func putAllowedExtensionSucceeds() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extallow-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent("allowed.txt")
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("text content".utf8)
            )

            #expect(result.statusCode == 201)
        }

        @Test("allowedFileExtensions = ['txt'] blocks PUT of .jpg file with 403")
        func putDisallowedExtensionReturns403() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extblock-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent("blocked.jpg")
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("image data".utf8)
            )

            #expect(result.statusCode == 403)
        }

        @Test("allowedFileExtensions = ['txt'] blocks GET of .pdf file with 403")
        func getDisallowedExtensionReturns403() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extget-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            // Create the file before setting extension filter
            try self.parent.writeFile(named: "secret.pdf", content: Data("pdf data".utf8), inDirectory: dir)

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent("secret.pdf")
            let result = try await parent.sendRequest(method: "GET", url: fileURL)

            #expect(result.statusCode == 403)
        }

        @Test("allowedFileExtensions = ['txt'] blocks DELETE of .exe file with 403")
        func deleteDisallowedExtensionReturns403() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extdel-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            try self.parent.writeFile(named: "no_delete.exe", content: Data("binary".utf8), inDirectory: dir)

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent("no_delete.exe")
            let result = try await parent.sendRequest(method: "DELETE", url: fileURL)

            #expect(result.statusCode == 403)
        }

        @Test("Extension filter is case-insensitive (.TXT matches 'txt' filter)")
        func extensionFilterCaseInsensitive() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extcase-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent("uppercase.TXT")
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("case test".utf8)
            )

            #expect(
                result.statusCode == 201,
                "Extension filter should be case-insensitive (.TXT should match 'txt')"
            )
        }

        @Test("MKCOL is not affected by file extension filter")
        func mkcolNotAffectedByExtensionFilter() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extmk-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let dirURL = baseURL.appendingPathComponent("my.folder")
            let result = try await parent.sendRequest(method: "MKCOL", url: dirURL)

            #expect(
                result.statusCode == 201,
                "MKCOL should not be blocked by file extension filter"
            )
        }

        @Test(
            "Extension filter blocks various disallowed extensions",
            arguments: ["blocked.jpg", "blocked.png", "blocked.exe", "blocked.pdf", "blocked.zip"]
        )
        func putVariousDisallowedExtensions(fileName: String) async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-extvar-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeFilteredServer(extensions: ["txt"], dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent(fileName)
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("test".utf8)
            )

            #expect(
                result.statusCode == 403,
                "PUT of \(fileName) should be blocked when only 'txt' is allowed"
            )
        }
    }

    // MARK: - Hidden Items

    @Suite("Hidden Items", .serialized, .tags(.integration, .fileIO))
    struct HiddenItems {
        private let parent = DZWebDAVServerTests()

        /// Creates a server with allowHiddenItems configured and started.
        private func makeHiddenItemsServer(
            allowHidden: Bool,
            dir: String
        ) throws
            -> (DZWebDAVServer, URL)
        {
            let server = DZWebDAVServer(uploadDirectory: dir)
            server.allowHiddenItems = allowHidden
            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            let baseURL = try #require(server.serverURL)
            return (server, baseURL)
        }

        @Test("allowHiddenItems=false blocks PUT of .hidden file with 403")
        func putHiddenFileDenied() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidput-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: false, dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent(".hidden")
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("hidden content".utf8)
            )

            #expect(result.statusCode == 403)
        }

        @Test("allowHiddenItems=true allows PUT of .hidden file")
        func putHiddenFileAllowed() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidallow-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: true, dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent(".hidden")
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("hidden content".utf8)
            )

            #expect(result.statusCode == 201)
        }

        @Test("allowHiddenItems=false blocks GET of .secret file with 403")
        func getHiddenFileDenied() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidget-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            try self.parent.writeFile(named: ".secret", content: Data("secret data".utf8), inDirectory: dir)

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: false, dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent(".secret")
            let result = try await parent.sendRequest(method: "GET", url: fileURL)

            #expect(result.statusCode == 403)
        }

        @Test("allowHiddenItems=true allows GET of .secret file")
        func getHiddenFileAllowed() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidgetok-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let content = Data("secret data".utf8)
            try self.parent.writeFile(named: ".secret", content: content, inDirectory: dir)

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: true, dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent(".secret")
            let result = try await parent.sendRequest(method: "GET", url: fileURL)

            #expect(result.statusCode == 200)
            #expect(result.data == content)
        }

        @Test("allowHiddenItems=false blocks MKCOL of .hiddenfolder with 403")
        func mkcolHiddenDirectoryDenied() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidmk-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: false, dir: dir)
            defer { server.stop() }

            let dirURL = baseURL.appendingPathComponent(".hiddenfolder")
            let result = try await parent.sendRequest(method: "MKCOL", url: dirURL)

            #expect(result.statusCode == 403)
        }

        @Test("PROPFIND Depth:1 excludes hidden items when allowHiddenItems=false")
        func propfindExcludesHiddenItems() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidpf-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            try self.parent.writeFile(named: "visible.txt", content: Data("visible".utf8), inDirectory: dir)
            try self.parent.writeFile(named: ".invisible", content: Data("hidden".utf8), inDirectory: dir)

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: false, dir: dir)
            defer { server.stop() }

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "1"]
            )

            #expect(result.statusCode == 207)

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("visible.txt"),
                "PROPFIND should include visible files"
            )
            #expect(
                !xmlString.contains(".invisible"),
                "PROPFIND should exclude hidden files when allowHiddenItems=false"
            )
        }

        @Test("PROPFIND Depth:1 includes hidden items when allowHiddenItems=true")
        func propfindIncludesHiddenItems() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hidpfok-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            try self.parent.writeFile(named: "visible.txt", content: Data("visible".utf8), inDirectory: dir)
            try self.parent.writeFile(named: ".dotfile", content: Data("hidden".utf8), inDirectory: dir)

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: true, dir: dir)
            defer { server.stop() }

            let result = try await parent.sendRequest(
                method: "PROPFIND",
                url: baseURL,
                headers: ["Depth": "1"]
            )

            #expect(result.statusCode == 207)

            let xmlString = String(data: result.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("visible.txt"),
                "PROPFIND should include visible files"
            )
            #expect(
                xmlString.contains(".dotfile"),
                "PROPFIND should include hidden files when allowHiddenItems=true"
            )
        }

        @Test("allowHiddenItems=false blocks DELETE of .hidden file with 403")
        func deleteHiddenFileDenied() async throws {
            let dir = NSTemporaryDirectory() + "DZWebDAVServerTests-hiddel-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: dir) }

            try self.parent.writeFile(named: ".hidden_delete", content: Data("data".utf8), inDirectory: dir)

            let (server, baseURL) = try makeHiddenItemsServer(allowHidden: false, dir: dir)
            defer { server.stop() }

            let fileURL = baseURL.appendingPathComponent(".hidden_delete")
            let result = try await parent.sendRequest(method: "DELETE", url: fileURL)

            #expect(result.statusCode == 403)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases", .serialized, .tags(.integration, .fileIO))
    struct EdgeCases {
        private let parent = DZWebDAVServerTests()

        @Test("PUT a file with unicode characters in the name")
        func putFileWithUnicodeName() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileName = "caf\u{00E9}-\u{00FC}ber.txt"
            let fileURL = baseURL.appendingPathComponent(fileName)
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("unicode test".utf8)
            )

            #expect(
                result.statusCode == 201,
                "PUT with unicode filename should succeed"
            )
        }

        @Test("PUT a file with spaces in the name")
        func putFileWithSpacesInName() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("my document.txt")
            let result = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("spaces test".utf8)
            )

            #expect(
                result.statusCode == 201,
                "PUT with spaces in filename should succeed"
            )
        }

        @Test("GET and PUT round-trip with unicode filename preserves content")
        func unicodeFileNameRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileName = "\u{65E5}\u{672C}\u{8A9E}\u{30C6}\u{30B9}\u{30C8}.txt"
            let content = Data("Japanese test content".utf8)
            let fileURL = baseURL.appendingPathComponent(fileName)

            let putResult = try await parent.sendRequest(method: "PUT", url: fileURL, body: content)
            #expect(putResult.statusCode == 201)

            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.statusCode == 200)
            #expect(getResult.data == content)
        }

        @Test("PUT and GET an empty file")
        func emptyFileRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("empty.dat")
            let putResult = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data())
            #expect(putResult.statusCode == 201)

            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.statusCode == 200)
            #expect(getResult.data.isEmpty, "GET of empty file should return empty data")
        }

        @Test("PUT and GET a large file (100KB) preserves content")
        func largeFileRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            var largeBody = Data(count: 100 * 1024)
            for i in 0..<largeBody.count {
                largeBody[i] = UInt8(i % 256)
            }

            let fileURL = baseURL.appendingPathComponent("large.bin")
            let putResult = try await parent.sendRequest(method: "PUT", url: fileURL, body: largeBody)
            #expect(putResult.statusCode == 201)

            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.statusCode == 200)
            #expect(getResult.data == largeBody, "Large file content should survive PUT/GET round-trip")
        }

        @Test("Nested directory structures: MKCOL step-by-step then PUT in deepest directory")
        func nestedDirectoryStepByStep() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            // Create parent
            let r1 = try await parent.sendRequest(
                method: "MKCOL",
                url: baseURL.appendingPathComponent("level1")
            )
            #expect(r1.statusCode == 201)

            // Create child
            let r2 = try await parent.sendRequest(
                method: "MKCOL",
                url: baseURL.appendingPathComponent("level1/level2")
            )
            #expect(r2.statusCode == 201)

            // Create grandchild
            let r3 = try await parent.sendRequest(
                method: "MKCOL",
                url: baseURL.appendingPathComponent("level1/level2/level3")
            )
            #expect(r3.statusCode == 201)

            // PUT file in deepest directory
            let fileURL = baseURL.appendingPathComponent("level1/level2/level3/deep.txt")
            let r4 = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("deep".utf8))
            #expect(r4.statusCode == 201)

            // Verify via GET
            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.statusCode == 200)
            #expect(getResult.data == Data("deep".utf8))
        }

        @Test("Special characters in filenames (percent-encoded by URL) are handled")
        func specialCharactersInFilename() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            // Parentheses and ampersand are special characters
            let fileName = "report (final) & summary.txt"
            let content = Data("special chars".utf8)
            let fileURL = baseURL.appendingPathComponent(fileName)

            let putResult = try await parent.sendRequest(method: "PUT", url: fileURL, body: content)
            #expect(putResult.statusCode == 201)

            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.statusCode == 200)
            #expect(getResult.data == content)
        }
    }

    // MARK: - Round-Trip Tests

    @Suite("Round-Trip", .serialized, .tags(.integration, .fileIO))
    struct RoundTrip {
        private let parent = DZWebDAVServerTests()

        @Test("PUT a file then GET it back yields identical content")
        func putThenGetRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let content = Data("Round-trip content verification \u{1F680}".utf8)
            let fileURL = baseURL.appendingPathComponent("roundtrip.txt")

            let putResult = try await parent.sendRequest(method: "PUT", url: fileURL, body: content)
            #expect(putResult.statusCode == 201)

            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.statusCode == 200)
            #expect(
                getResult.data == content,
                "GET response body should exactly match the PUT body"
            )
        }

        @Test("MKCOL then PUT file inside directory then PROPFIND verifies listing")
        func mkcolPutPropfindRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            // MKCOL
            let mkcolURL = baseURL.appendingPathComponent("testfolder")
            let mkcolResult = try await parent.sendRequest(method: "MKCOL", url: mkcolURL)
            #expect(mkcolResult.statusCode == 201)

            // PUT file inside directory
            let fileURL = baseURL.appendingPathComponent("testfolder/document.txt")
            let putResult = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("nested file".utf8)
            )
            #expect(putResult.statusCode == 201)

            // PROPFIND the directory
            let propfindResult = try await parent.sendRequest(
                method: "PROPFIND",
                url: mkcolURL,
                headers: ["Depth": "1"]
            )
            #expect(propfindResult.statusCode == 207)

            let xmlString = String(data: propfindResult.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("document.txt"),
                "PROPFIND should list the file inside the created directory"
            )
        }

        @Test("PUT then COPY then GET both files yields identical content")
        func putCopyGetRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let content = Data("Copy round-trip data".utf8)

            // PUT original
            let originalURL = baseURL.appendingPathComponent("original.dat")
            let putResult = try await parent.sendRequest(method: "PUT", url: originalURL, body: content)
            #expect(putResult.statusCode == 201)

            // COPY
            let copyURL = baseURL.appendingPathComponent("duplicate.dat")
            let copyResult = try await parent.sendRequest(
                method: "COPY",
                url: originalURL,
                headers: ["Destination": copyURL.absoluteString]
            )
            #expect(copyResult.statusCode == 201)

            // GET original
            let getOriginal = try await parent.sendRequest(method: "GET", url: originalURL)
            #expect(getOriginal.statusCode == 200)
            #expect(getOriginal.data == content)

            // GET copy
            let getCopy = try await parent.sendRequest(method: "GET", url: copyURL)
            #expect(getCopy.statusCode == 200)
            #expect(
                getCopy.data == content,
                "Copy should have identical content to the original"
            )
        }

        @Test("PUT then MOVE then GET from new location succeeds, GET from old returns 404")
        func putMoveGetRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let content = Data("Move round-trip data".utf8)

            // PUT at old location
            let oldURL = baseURL.appendingPathComponent("old_location.txt")
            let putResult = try await parent.sendRequest(method: "PUT", url: oldURL, body: content)
            #expect(putResult.statusCode == 201)

            // MOVE to new location
            let newURL = baseURL.appendingPathComponent("new_location.txt")
            let moveResult = try await parent.sendRequest(
                method: "MOVE",
                url: oldURL,
                headers: [
                    "Destination": newURL.absoluteString,
                    "Overwrite": "T",
                ]
            )
            #expect(moveResult.statusCode == 201)

            // GET from new location
            let getNew = try await parent.sendRequest(method: "GET", url: newURL)
            #expect(getNew.statusCode == 200)
            #expect(
                getNew.data == content,
                "File at new location should have the original content"
            )

            // GET from old location should 404
            let getOld = try await parent.sendRequest(method: "GET", url: oldURL)
            #expect(
                getOld.statusCode == 404,
                "Old location should return 404 after MOVE"
            )
        }

        @Test("PUT then DELETE then GET returns 404")
        func putDeleteGetRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("ephemeral.txt")

            let putResult = try await parent.sendRequest(
                method: "PUT",
                url: fileURL,
                body: Data("temporary".utf8)
            )
            #expect(putResult.statusCode == 201)

            let deleteResult = try await parent.sendRequest(method: "DELETE", url: fileURL)
            #expect(deleteResult.statusCode == 204)

            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(
                getResult.statusCode == 404,
                "File should be gone after DELETE"
            )
        }

        @Test("Multiple sequential PUTs to the same file alternate between 201 and 204")
        func multiplePutsAlternateStatusCodes() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let fileURL = baseURL.appendingPathComponent("versioned.txt")

            // First PUT -> 201 (created)
            let r1 = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("v1".utf8))
            #expect(r1.statusCode == 201)

            // Second PUT -> 204 (overwrite)
            let r2 = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("v2".utf8))
            #expect(r2.statusCode == 204)

            // Third PUT -> 204 (overwrite)
            let r3 = try await parent.sendRequest(method: "PUT", url: fileURL, body: Data("v3".utf8))
            #expect(r3.statusCode == 204)

            // Final content should be v3
            let getResult = try await parent.sendRequest(method: "GET", url: fileURL)
            #expect(getResult.data == Data("v3".utf8))
        }

        @Test("COPY a directory recursively preserves all nested contents")
        func copyDirectoryRecursiveRoundTrip() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            // Create directory with a file in it
            let srcDir = try parent.createSubdirectory(named: "srcdir", inDirectory: dir)
            try self.parent.writeFile(named: "nested.txt", content: Data("nested content".utf8), inDirectory: srcDir)

            let sourceURL = baseURL.appendingPathComponent("srcdir")
            let destinationHeader = "\(baseURL.absoluteString)dstdir"
            let result = try await parent.sendRequest(
                method: "COPY",
                url: sourceURL,
                headers: ["Destination": destinationHeader]
            )

            #expect(result.statusCode == 201)

            // Verify nested file via GET
            let nestedFileURL = baseURL.appendingPathComponent("dstdir/nested.txt")
            let getResult = try await parent.sendRequest(method: "GET", url: nestedFileURL)
            #expect(getResult.statusCode == 200)
            #expect(getResult.data == Data("nested content".utf8))
        }

        @Test("MOVE a directory then PROPFIND verifies new location contents")
        func moveDirectoryPropfindVerify() async throws {
            let (server, baseURL, dir) = try parent.makeServer()
            defer {
                server.stop()
                try? FileManager.default.removeItem(atPath: dir)
            }

            let srcDir = try parent.createSubdirectory(named: "movable", inDirectory: dir)
            try self.parent.writeFile(named: "inside.txt", content: Data("moved data".utf8), inDirectory: srcDir)

            let sourceURL = baseURL.appendingPathComponent("movable")
            let destURL = baseURL.appendingPathComponent("relocated")
            let moveResult = try await parent.sendRequest(
                method: "MOVE",
                url: sourceURL,
                headers: [
                    "Destination": destURL.absoluteString,
                    "Overwrite": "T",
                ]
            )
            #expect(moveResult.statusCode == 201)

            // PROPFIND the new directory
            let propfindResult = try await parent.sendRequest(
                method: "PROPFIND",
                url: destURL,
                headers: ["Depth": "1"]
            )
            #expect(propfindResult.statusCode == 207)

            let xmlString = String(data: propfindResult.data, encoding: .utf8) ?? ""
            #expect(
                xmlString.contains("inside.txt"),
                "PROPFIND of moved directory should list its contents"
            )

            // Original location should be gone
            let getOldResult = try await parent.sendRequest(
                method: "PROPFIND",
                url: sourceURL,
                headers: ["Depth": "0"]
            )
            #expect(
                getOldResult.statusCode == 404,
                "Original directory should not exist after MOVE"
            )
        }
    }
}
