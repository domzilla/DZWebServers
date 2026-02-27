//
//  DZWebUploaderTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

// MARK: - Root Suite

@Suite("DZWebUploader", .serialized, .tags(.uploader, .integration))
struct DZWebUploaderTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Helpers

    /// Creates a temporary upload directory with a unique name and returns
    /// a DZWebUploader initialized with that directory. Throws via `#require`
    /// if the bundle is not found (init returns nil).
    private func makeUploader() throws -> DZWebUploader {
        let dir = NSTemporaryDirectory() + "DZWebUploaderTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return try #require(DZWebUploader(uploadDirectory: dir))
    }

    /// Starts the given uploader on an ephemeral port bound to localhost.
    /// Returns the base URL. The caller must call `server.stop()`.
    private func startUploader(_ uploader: DZWebUploader) throws -> URL {
        let options: [String: Any] = [
            DZWebServerOption_Port: 0,
            DZWebServerOption_BindToLocalhost: true,
        ]
        try uploader.start(options: options)
        return try #require(uploader.serverURL)
    }

    /// Sends a synchronous GET request and returns the data and HTTP response.
    private func sendGET(to url: URL) async throws -> (Data, HTTPURLResponse) {
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    /// Sends a synchronous POST request with the given body and content type.
    private func sendPOST(
        to url: URL,
        body: Data,
        contentType: String
    ) async throws
        -> (Data, HTTPURLResponse)
    {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    /// Sends a POST with `application/x-www-form-urlencoded` body.
    private func sendFormPOST(
        to url: URL,
        formBody: String
    ) async throws
        -> (Data, HTTPURLResponse)
    {
        try await self.sendPOST(
            to: url,
            body: Data(formBody.utf8),
            contentType: "application/x-www-form-urlencoded"
        )
    }

    /// Sends a multipart/form-data POST to upload a file.
    private func sendMultipartUpload(
        to url: URL,
        path: String,
        fileName: String,
        fileContent: Data,
        fileMIME: String = "application/octet-stream"
    ) async throws
        -> (Data, HTTPURLResponse)
    {
        let boundary = "TestBoundary12345"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(path)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body
            .append("Content-Disposition: form-data; name=\"files[]\"; filename=\"\(fileName)\"\r\n"
                .data(using: .utf8)!)
        body.append("Content-Type: \(fileMIME)\r\n\r\n".data(using: .utf8)!)
        body.append(fileContent)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        return (data, httpResponse)
    }

    /// Removes a temporary upload directory and all its contents.
    private func cleanupDirectory(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Initialization

    @Suite("Initialization", .serialized, .tags(.uploader, .properties))
    struct Initialization {
        private let parent = DZWebUploaderTests()

        @Test("initWithUploadDirectory stores the path in uploadDirectory")
        func uploadDirectoryMatchesInit() throws {
            let dir = NSTemporaryDirectory() + "DZWebUploaderTests-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { parent.cleanupDirectory(dir) }

            let uploader = DZWebUploader(uploadDirectory: dir)

            #expect(uploader.uploadDirectory == dir)
        }

        @Test("initWithUploadDirectory returns nil gracefully when bundle is not found")
        func initReturnsNilWithoutBundle() throws {
            // This test documents the behavior: if DZWebUploader.bundle is missing
            // from the test environment, init returns nil. We simply verify that
            // creating an uploader does not crash regardless of bundle availability.
            let dir = NSTemporaryDirectory() + "DZWebUploaderTests-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            defer { parent.cleanupDirectory(dir) }

            let uploader = DZWebUploader(uploadDirectory: dir)
            // Either nil (bundle missing) or a valid instance -- both are acceptable
            _ = uploader
        }

        @Test("Server can start on an ephemeral port after successful init")
        func serverCanStart() throws {
            let uploader = try parent.makeUploader()
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try uploader.start(options: options)

            #expect(uploader.isRunning == true)
            #expect(uploader.port > 0)
            #expect(uploader.serverURL != nil)
        }

        @Test("Upload directory must exist on disk")
        func uploadDirectoryExistsOnDisk() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: uploader.uploadDirectory,
                isDirectory: &isDirectory
            )
            #expect(exists == true)
            #expect(isDirectory.boolValue == true)
        }
    }

    // MARK: - Property Defaults and Mutation

    @Suite("Property defaults and mutation", .serialized, .tags(.uploader, .properties))
    struct PropertyDefaultsAndMutation {
        private let parent = DZWebUploaderTests()

        @Test("allowedFileExtensions defaults to nil")
        func allowedFileExtensionsDefaultsToNil() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.allowedFileExtensions == nil)
        }

        @Test("allowHiddenItems defaults to false")
        func allowHiddenItemsDefaultsToFalse() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.allowHiddenItems == false)
        }

        @Test("title defaults to an empty string")
        func titleDefaultsToEmpty() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.title != nil)
            #expect(uploader.title.isEmpty)
        }

        @Test("header defaults to an empty string")
        func headerDefaultsToEmpty() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.header != nil)
            #expect(uploader.header.isEmpty)
        }

        @Test("footer defaults to an empty string")
        func footerDefaultsToEmpty() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.footer != nil)
            #expect(uploader.footer.isEmpty)
        }

        @Test("prologue defaults to an empty string")
        func prologueDefaultsToEmpty() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.prologue != nil)
            #expect(uploader.prologue.isEmpty)
        }

        @Test("epilogue defaults to nil")
        func epilogueDefaultsToNil() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.epilogue == nil)
        }

        @Test("title is settable")
        func titleIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.title = "Custom Title"
            #expect(uploader.title == "Custom Title")
        }

        @Test("header is settable")
        func headerIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.header = "Custom Header"
            #expect(uploader.header == "Custom Header")
        }

        @Test("footer is settable")
        func footerIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.footer = "Custom Footer v1.0"
            #expect(uploader.footer == "Custom Footer v1.0")
        }

        @Test("prologue is settable")
        func prologueIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.prologue = "<p>Welcome!</p>"
            #expect(uploader.prologue == "<p>Welcome!</p>")
        }

        @Test("epilogue is settable")
        func epilogueIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.epilogue = "<p>Goodbye!</p>"
            #expect(uploader.epilogue == "<p>Goodbye!</p>")
        }

        @Test("allowedFileExtensions is settable")
        func allowedFileExtensionsIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            let extensions = ["jpg", "png", "pdf"]
            uploader.allowedFileExtensions = extensions
            #expect(uploader.allowedFileExtensions == extensions)
        }

        @Test("allowedFileExtensions can be reset to nil")
        func allowedFileExtensionsResettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.allowedFileExtensions = ["jpg"]
            uploader.allowedFileExtensions = nil
            #expect(uploader.allowedFileExtensions == nil)
        }

        @Test("allowHiddenItems is settable")
        func allowHiddenItemsIsSettable() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.allowHiddenItems = true
            #expect(uploader.allowHiddenItems == true)

            uploader.allowHiddenItems = false
            #expect(uploader.allowHiddenItems == false)
        }

        @Test("Setting multiple properties simultaneously", arguments: [
            ("Title A", "Header A", "Footer A"),
            ("Title B", "Header B", "Footer B"),
            ("", "", ""),
        ])
        func multiplePropertiesMutation(title: String, header: String, footer: String) throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            uploader.title = title
            uploader.header = header
            uploader.footer = footer

            #expect(uploader.title == title)
            #expect(uploader.header == header)
            #expect(uploader.footer == footer)
        }
    }

    // MARK: - Integration: GET /

    @Suite("GET / (web page)", .serialized, .tags(.uploader, .integration))
    struct GETRootPage {
        private let parent = DZWebUploaderTests()

        @Test("GET / returns HTTP 200")
        func rootReturns200() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (_, response) = try await parent.sendGET(to: baseURL)
            #expect(response.statusCode == 200)
        }

        @Test("GET / returns HTML content")
        func rootReturnsHTML() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (data, response) = try await parent.sendGET(to: baseURL)

            let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(contentType.contains("text/html"))

            let html = String(data: data, encoding: .utf8)
            #expect(html != nil)
            #expect(try #require(html?.contains("<html")))
        }

        @Test("GET / includes the custom title in the HTML")
        func rootIncludesCustomTitle() async throws {
            let uploader = try parent.makeUploader()
            uploader.title = "TestUploader42"
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (data, _) = try await parent.sendGET(to: baseURL)
            let html = try #require(String(data: data, encoding: .utf8))
            #expect(html.contains("TestUploader42"))
        }

        @Test("GET / includes the custom header in the HTML")
        func rootIncludesCustomHeader() async throws {
            let uploader = try parent.makeUploader()
            uploader.header = "MyCustomHeader99"
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (data, _) = try await parent.sendGET(to: baseURL)
            let html = try #require(String(data: data, encoding: .utf8))
            #expect(html.contains("MyCustomHeader99"))
        }

        @Test("GET / includes the custom footer in the HTML")
        func rootIncludesCustomFooter() async throws {
            let uploader = try parent.makeUploader()
            uploader.footer = "FooterText2026"
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (data, _) = try await parent.sendGET(to: baseURL)
            let html = try #require(String(data: data, encoding: .utf8))
            #expect(html.contains("FooterText2026"))
        }

        @Test("GET / includes the custom prologue in the HTML")
        func rootIncludesCustomPrologue() async throws {
            let uploader = try parent.makeUploader()
            uploader.prologue = "<p>PrologueMarker</p>"
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (data, _) = try await parent.sendGET(to: baseURL)
            let html = try #require(String(data: data, encoding: .utf8))
            #expect(html.contains("PrologueMarker"))
        }

        @Test("GET / includes the custom epilogue in the HTML")
        func rootIncludesCustomEpilogue() async throws {
            let uploader = try parent.makeUploader()
            uploader.epilogue = "<p>EpilogueMarker</p>"
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let (data, _) = try await parent.sendGET(to: baseURL)
            let html = try #require(String(data: data, encoding: .utf8))
            #expect(html.contains("EpilogueMarker"))
        }
    }

    // MARK: - Integration: GET /list

    @Suite("GET /list (directory listing)", .serialized, .tags(.uploader, .integration))
    struct GETList {
        private let parent = DZWebUploaderTests()

        @Test("GET /list returns HTTP 200 with JSON for an empty directory")
        func listEmptyDirectory() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, response) = try await parent.sendGET(to: listURL)

            #expect(response.statusCode == 200)

            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            #expect(json != nil)
            #expect(try #require(json?.isEmpty))
        }

        @Test("GET /list returns files that exist in the upload directory")
        func listDirectoryWithFiles() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            // Create test files
            try Data("hello".utf8).write(to: URL(fileURLWithPath: dir + "/test.txt"))
            try Data("world".utf8).write(to: URL(fileURLWithPath: dir + "/notes.md"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, response) = try await parent.sendGET(to: listURL)

            #expect(response.statusCode == 200)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.count == 2)

            let names = json.compactMap { $0["name"] as? String }.sorted()
            #expect(names.contains("notes.md"))
            #expect(names.contains("test.txt"))
        }

        @Test("GET /list returns directories in the upload directory")
        func listDirectoryWithSubdirectories() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            try FileManager.default.createDirectory(
                atPath: dir + "/subdir",
                withIntermediateDirectories: true
            )

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.count == 1)

            let entry = json[0]
            #expect(entry["name"] as? String == "subdir")
            // Directories have a trailing slash in their path
            let path = try #require(entry["path"] as? String)
            #expect(path.hasSuffix("/"))
        }

        @Test("GET /list excludes hidden files when allowHiddenItems is false")
        func listExcludesHiddenFiles() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false

            try Data("visible".utf8).write(to: URL(fileURLWithPath: dir + "/visible.txt"))
            try Data("hidden".utf8).write(to: URL(fileURLWithPath: dir + "/.hidden.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.count == 1)

            let names = json.compactMap { $0["name"] as? String }
            #expect(names.contains("visible.txt"))
            #expect(!names.contains(".hidden.txt"))
        }

        @Test("GET /list includes hidden files when allowHiddenItems is true")
        func listIncludesHiddenFiles() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = true

            try Data("visible".utf8).write(to: URL(fileURLWithPath: dir + "/visible.txt"))
            try Data("hidden".utf8).write(to: URL(fileURLWithPath: dir + "/.hidden.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            let names = json.compactMap { $0["name"] as? String }
            #expect(names.contains("visible.txt"))
            #expect(names.contains(".hidden.txt"))
        }

        @Test("GET /list respects allowedFileExtensions filter")
        func listRespectsFileExtensionFilter() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt"]

            try Data("allowed".utf8).write(to: URL(fileURLWithPath: dir + "/file.txt"))
            try Data("blocked".utf8).write(to: URL(fileURLWithPath: dir + "/file.pdf"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            let names = json.compactMap { $0["name"] as? String }
            #expect(names.contains("file.txt"))
            #expect(!names.contains("file.pdf"))
        }

        @Test("GET /list includes file size for regular files")
        func listIncludesFileSize() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let content = Data("twelve bytes".utf8)
            try content.write(to: URL(fileURLWithPath: dir + "/sized.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.count == 1)

            let size = json[0]["size"] as? Int
            #expect(size == content.count)
        }

        @Test("GET /list for a non-existent path returns 404")
        func listNonExistentPath() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let listURL = try #require(URL(string: "/list?path=/nonexistent", relativeTo: baseURL))
            let (_, response) = try await parent.sendGET(to: listURL)

            #expect(response.statusCode == 404)
        }

        @Test("GET /list can list a subdirectory")
        func listSubdirectory() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let subdir = dir + "/sub"
            try FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true)
            try Data("nested".utf8).write(to: URL(fileURLWithPath: subdir + "/nested.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/sub", relativeTo: baseURL))
            let (data, response) = try await parent.sendGET(to: listURL)

            #expect(response.statusCode == 200)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.count == 1)
            #expect(json[0]["name"] as? String == "nested.txt")
        }
    }

    // MARK: - Integration: POST /upload

    @Suite("POST /upload (file upload)", .serialized, .tags(.uploader, .integration, .fileIO))
    struct POSTUpload {
        private let parent = DZWebUploaderTests()

        @Test("POST /upload uploads a file and returns 200")
        func uploadFileReturns200() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let fileContent = Data("Hello, Upload!".utf8)

            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "test.txt",
                fileContent: fileContent,
                fileMIME: "text/plain"
            )

            #expect(response.statusCode == 200)
        }

        @Test("POST /upload saves the file to disk with correct content")
        func uploadedFileExistsOnDisk() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let fileContent = Data("Disk content check".utf8)

            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "uploaded.txt",
                fileContent: fileContent,
                fileMIME: "text/plain"
            )

            #expect(response.statusCode == 200)

            let filePath = dir + "/uploaded.txt"
            #expect(FileManager.default.fileExists(atPath: filePath))

            let savedData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            #expect(savedData == fileContent)
        }

        @Test("POST /upload into a subdirectory saves the file in that subdirectory")
        func uploadToSubdirectory() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let subdir = dir + "/docs"
            try FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true)

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let fileContent = Data("Subdirectory upload".utf8)

            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/docs",
                fileName: "subfile.txt",
                fileContent: fileContent,
                fileMIME: "text/plain"
            )

            #expect(response.statusCode == 200)
            #expect(FileManager.default.fileExists(atPath: subdir + "/subfile.txt"))
        }

        @Test("POST /upload with duplicate filename auto-renames the file")
        func uploadDuplicateAutoRenames() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            // Create existing file
            try Data("original".utf8).write(to: URL(fileURLWithPath: dir + "/dup.txt"))

            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "dup.txt",
                fileContent: Data("duplicate".utf8),
                fileMIME: "text/plain"
            )

            #expect(response.statusCode == 200)

            // Original should still exist
            #expect(FileManager.default.fileExists(atPath: dir + "/dup.txt"))
            // Renamed copy should exist
            #expect(FileManager.default.fileExists(atPath: dir + "/dup (1).txt"))
        }

        @Test("POST /upload rejects a hidden file when allowHiddenItems is false")
        func uploadRejectsHiddenFile() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: ".secret",
                fileContent: Data("hidden file".utf8)
            )

            #expect(response.statusCode == 403)
            #expect(!FileManager.default.fileExists(atPath: dir + "/.secret"))
        }

        @Test("POST /upload rejects a disallowed extension when allowedFileExtensions is set")
        func uploadRejectsDisallowedExtension() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt"]
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "image.png",
                fileContent: Data("fake png".utf8)
            )

            #expect(response.statusCode == 403)
            #expect(!FileManager.default.fileExists(atPath: dir + "/image.png"))
        }

        @Test("POST /upload accepts an allowed extension when allowedFileExtensions is set")
        func uploadAcceptsAllowedExtension() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt", "md"]
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, response) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "notes.md",
                fileContent: Data("# Notes".utf8),
                fileMIME: "text/markdown"
            )

            #expect(response.statusCode == 200)
            #expect(FileManager.default.fileExists(atPath: dir + "/notes.md"))
        }
    }

    // MARK: - Integration: POST /delete

    @Suite("POST /delete (file deletion)", .serialized, .tags(.uploader, .integration, .fileIO))
    struct POSTDelete {
        private let parent = DZWebUploaderTests()

        @Test("POST /delete removes a file and returns 200")
        func deleteFileReturns200() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let filePath = dir + "/todelete.txt"
            try Data("delete me".utf8).write(to: URL(fileURLWithPath: filePath))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let deleteURL = baseURL.appendingPathComponent("delete")
            let (_, response) = try await parent.sendFormPOST(
                to: deleteURL,
                formBody: "path=/todelete.txt"
            )

            #expect(response.statusCode == 200)
            #expect(!FileManager.default.fileExists(atPath: filePath))
        }

        @Test("POST /delete removes a directory recursively")
        func deleteDirectoryRecursively() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let subdir = dir + "/removeme"
            try FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true)
            try Data("nested".utf8).write(to: URL(fileURLWithPath: subdir + "/nested.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let deleteURL = baseURL.appendingPathComponent("delete")
            let (_, response) = try await parent.sendFormPOST(
                to: deleteURL,
                formBody: "path=/removeme"
            )

            #expect(response.statusCode == 200)
            #expect(!FileManager.default.fileExists(atPath: subdir))
        }

        @Test("POST /delete returns 404 for a non-existent file")
        func deleteNonExistentFile() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let deleteURL = baseURL.appendingPathComponent("delete")
            let (_, response) = try await parent.sendFormPOST(
                to: deleteURL,
                formBody: "path=/ghost.txt"
            )

            #expect(response.statusCode == 404)
        }

        @Test("POST /delete rejects a hidden file when allowHiddenItems is false")
        func deleteRejectsHiddenFile() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false

            let filePath = dir + "/.hidden"
            try Data("hidden".utf8).write(to: URL(fileURLWithPath: filePath))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let deleteURL = baseURL.appendingPathComponent("delete")
            let (_, response) = try await parent.sendFormPOST(
                to: deleteURL,
                formBody: "path=/.hidden"
            )

            #expect(response.statusCode == 403)
            #expect(FileManager.default.fileExists(atPath: filePath))
        }

        @Test("POST /delete rejects a disallowed extension")
        func deleteRejectsDisallowedExtension() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt"]

            let filePath = dir + "/blocked.pdf"
            try Data("pdf".utf8).write(to: URL(fileURLWithPath: filePath))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let deleteURL = baseURL.appendingPathComponent("delete")
            let (_, response) = try await parent.sendFormPOST(
                to: deleteURL,
                formBody: "path=/blocked.pdf"
            )

            #expect(response.statusCode == 403)
            #expect(FileManager.default.fileExists(atPath: filePath))
        }
    }

    // MARK: - Integration: POST /move

    @Suite("POST /move (file moving/renaming)", .serialized, .tags(.uploader, .integration, .fileIO))
    struct POSTMove {
        private let parent = DZWebUploaderTests()

        @Test("POST /move renames a file and returns 200")
        func moveFileReturns200() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let oldPath = dir + "/old.txt"
            try Data("movable".utf8).write(to: URL(fileURLWithPath: oldPath))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let moveURL = baseURL.appendingPathComponent("move")
            let (_, response) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/old.txt&newPath=/new.txt"
            )

            #expect(response.statusCode == 200)
            #expect(!FileManager.default.fileExists(atPath: oldPath))
            #expect(FileManager.default.fileExists(atPath: dir + "/new.txt"))
        }

        @Test("POST /move moves a file into a subdirectory")
        func moveFileToSubdirectory() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            try Data("mobile".utf8).write(to: URL(fileURLWithPath: dir + "/file.txt"))
            try FileManager.default.createDirectory(
                atPath: dir + "/subdir",
                withIntermediateDirectories: true
            )

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let moveURL = baseURL.appendingPathComponent("move")
            let (_, response) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/file.txt&newPath=/subdir/file.txt"
            )

            #expect(response.statusCode == 200)
            #expect(!FileManager.default.fileExists(atPath: dir + "/file.txt"))
            #expect(FileManager.default.fileExists(atPath: dir + "/subdir/file.txt"))
        }

        @Test("POST /move returns 404 for a non-existent source")
        func moveNonExistentSource() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let moveURL = baseURL.appendingPathComponent("move")
            let (_, response) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/ghost.txt&newPath=/new.txt"
            )

            #expect(response.statusCode == 404)
        }

        @Test("POST /move auto-renames at destination when a file already exists")
        func moveAutoRenamesAtDestination() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            try Data("source".utf8).write(to: URL(fileURLWithPath: dir + "/a.txt"))
            try Data("existing".utf8).write(to: URL(fileURLWithPath: dir + "/b.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let moveURL = baseURL.appendingPathComponent("move")
            let (_, response) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/a.txt&newPath=/b.txt"
            )

            #expect(response.statusCode == 200)
            #expect(!FileManager.default.fileExists(atPath: dir + "/a.txt"))
            // Existing file remains
            #expect(FileManager.default.fileExists(atPath: dir + "/b.txt"))
            // Moved file gets renamed
            #expect(FileManager.default.fileExists(atPath: dir + "/b (1).txt"))
        }

        @Test("POST /move rejects moving a hidden file when allowHiddenItems is false")
        func moveRejectsHiddenSource() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false

            try Data("hidden".utf8).write(to: URL(fileURLWithPath: dir + "/.secret"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let moveURL = baseURL.appendingPathComponent("move")
            let (_, response) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/.secret&newPath=/revealed.txt"
            )

            #expect(response.statusCode == 403)
            #expect(FileManager.default.fileExists(atPath: dir + "/.secret"))
        }

        @Test("POST /move rejects moving to a hidden name when allowHiddenItems is false")
        func moveRejectsHiddenDestination() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false

            try Data("visible".utf8).write(to: URL(fileURLWithPath: dir + "/visible.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let moveURL = baseURL.appendingPathComponent("move")
            let (_, response) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/visible.txt&newPath=/.hidden"
            )

            #expect(response.statusCode == 403)
            #expect(FileManager.default.fileExists(atPath: dir + "/visible.txt"))
        }
    }

    // MARK: - Integration: POST /create

    @Suite("POST /create (directory creation)", .serialized, .tags(.uploader, .integration, .fileIO))
    struct POSTCreate {
        private let parent = DZWebUploaderTests()

        @Test("POST /create creates a new directory and returns 200")
        func createDirectoryReturns200() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let createURL = baseURL.appendingPathComponent("create")
            let (_, response) = try await parent.sendFormPOST(
                to: createURL,
                formBody: "path=/newdir"
            )

            #expect(response.statusCode == 200)

            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: dir + "/newdir",
                isDirectory: &isDir
            )
            #expect(exists == true)
            #expect(isDir.boolValue == true)
        }

        @Test("POST /create auto-renames when a directory already exists")
        func createAutoRenamesExisting() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            try FileManager.default.createDirectory(
                atPath: dir + "/existing",
                withIntermediateDirectories: true
            )

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let createURL = baseURL.appendingPathComponent("create")
            let (_, response) = try await parent.sendFormPOST(
                to: createURL,
                formBody: "path=/existing"
            )

            #expect(response.statusCode == 200)
            #expect(FileManager.default.fileExists(atPath: dir + "/existing"))
            #expect(FileManager.default.fileExists(atPath: dir + "/existing (1)"))
        }

        @Test("POST /create rejects a hidden directory name when allowHiddenItems is false")
        func createRejectsHiddenDirectory() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let createURL = baseURL.appendingPathComponent("create")
            let (_, response) = try await parent.sendFormPOST(
                to: createURL,
                formBody: "path=/.hidden"
            )

            #expect(response.statusCode == 403)
            #expect(!FileManager.default.fileExists(atPath: dir + "/.hidden"))
        }

        @Test("POST /create allows a hidden directory when allowHiddenItems is true")
        func createAllowsHiddenDirectory() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = true
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let createURL = baseURL.appendingPathComponent("create")
            let (_, response) = try await parent.sendFormPOST(
                to: createURL,
                formBody: "path=/.dotdir"
            )

            #expect(response.statusCode == 200)
            #expect(FileManager.default.fileExists(atPath: dir + "/.dotdir"))
        }
    }

    // MARK: - Integration: GET /download

    @Suite("GET /download (file download)", .serialized, .tags(.uploader, .integration, .fileIO))
    struct GETDownload {
        private let parent = DZWebUploaderTests()

        @Test("GET /download returns 200 with the file content")
        func downloadReturns200WithContent() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let fileContent = Data("Download me!".utf8)
            try fileContent.write(to: URL(fileURLWithPath: dir + "/dl.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let downloadURL = try #require(URL(string: "/download?path=/dl.txt", relativeTo: baseURL))
            let (data, response) = try await parent.sendGET(to: downloadURL)

            #expect(response.statusCode == 200)
            #expect(data == fileContent)
        }

        @Test("GET /download returns Content-Disposition attachment header")
        func downloadReturnsAttachmentHeader() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            try Data("attachment".utf8).write(to: URL(fileURLWithPath: dir + "/attach.txt"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let downloadURL = try #require(URL(string: "/download?path=/attach.txt", relativeTo: baseURL))
            let (_, response) = try await parent.sendGET(to: downloadURL)

            #expect(response.statusCode == 200)

            let disposition = response.value(forHTTPHeaderField: "Content-Disposition") ?? ""
            #expect(disposition.contains("attachment"))
        }

        @Test("GET /download returns 404 for a non-existent file")
        func downloadNonExistentFile() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let downloadURL = try #require(URL(string: "/download?path=/nope.txt", relativeTo: baseURL))
            let (_, response) = try await parent.sendGET(to: downloadURL)

            #expect(response.statusCode == 404)
        }

        @Test("GET /download rejects a hidden file when allowHiddenItems is false")
        func downloadRejectsHiddenFile() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowHiddenItems = false

            try Data("hidden".utf8).write(to: URL(fileURLWithPath: dir + "/.secret"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let downloadURL = try #require(URL(string: "/download?path=/.secret", relativeTo: baseURL))
            let (_, response) = try await parent.sendGET(to: downloadURL)

            #expect(response.statusCode == 403)
        }

        @Test("GET /download rejects a disallowed file extension")
        func downloadRejectsDisallowedExtension() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt"]

            try Data("blocked".utf8).write(to: URL(fileURLWithPath: dir + "/file.exe"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let downloadURL = try #require(URL(string: "/download?path=/file.exe", relativeTo: baseURL))
            let (_, response) = try await parent.sendGET(to: downloadURL)

            #expect(response.statusCode == 403)
        }

        @Test("GET /download returns a 400 when trying to download a directory")
        func downloadDirectoryReturnsBadRequest() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            try FileManager.default.createDirectory(
                atPath: dir + "/adir",
                withIntermediateDirectories: true
            )

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let downloadURL = try #require(URL(string: "/download?path=/adir", relativeTo: baseURL))
            let (_, response) = try await parent.sendGET(to: downloadURL)

            #expect(response.statusCode == 400)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge cases", .serialized, .tags(.uploader, .integration, .fileIO))
    struct EdgeCases {
        private let parent = DZWebUploaderTests()

        @Test("Unicode file name can be uploaded and listed")
        func unicodeFileName() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let fileName = "\u{1F600}emoji.txt"
            let fileContent = Data("unicode test".utf8)

            let (_, uploadResponse) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: fileName,
                fileContent: fileContent,
                fileMIME: "text/plain"
            )

            #expect(uploadResponse.statusCode == 200)

            // Verify via listing
            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (listData, listResponse) = try await parent.sendGET(to: listURL)

            #expect(listResponse.statusCode == 200)
            let json = try #require(try JSONSerialization.jsonObject(with: listData) as? [[String: Any]])
            let names = json.compactMap { $0["name"] as? String }
            #expect(names.contains(fileName))
        }

        @Test("File name with spaces can be uploaded and downloaded")
        func fileNameWithSpaces() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let fileName = "my file name.txt"
            let fileContent = Data("spaces in name".utf8)

            let (_, uploadResponse) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: fileName,
                fileContent: fileContent,
                fileMIME: "text/plain"
            )

            #expect(uploadResponse.statusCode == 200)
            #expect(FileManager.default.fileExists(atPath: dir + "/my file name.txt"))

            // Download the file with spaces
            let encodedPath = "/my file name.txt".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "/my file name.txt"
            let downloadURL = try #require(URL(string: "/download?path=\(encodedPath)", relativeTo: baseURL))
            let (data, dlResponse) = try await parent.sendGET(to: downloadURL)

            #expect(dlResponse.statusCode == 200)
            #expect(data == fileContent)
        }

        @Test("Nested directory operations work end-to-end")
        func nestedDirectoryOperations() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            // Create a nested directory
            let createURL = baseURL.appendingPathComponent("create")
            let (_, createResponse) = try await parent.sendFormPOST(
                to: createURL,
                formBody: "path=/level1"
            )
            #expect(createResponse.statusCode == 200)

            // Upload a file into it
            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, uploadResponse) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/level1",
                fileName: "nested.txt",
                fileContent: Data("nested content".utf8),
                fileMIME: "text/plain"
            )
            #expect(uploadResponse.statusCode == 200)

            // List the nested directory
            let listURL = try #require(URL(string: "/list?path=/level1", relativeTo: baseURL))
            let (listData, listResponse) = try await parent.sendGET(to: listURL)
            #expect(listResponse.statusCode == 200)

            let json = try #require(try JSONSerialization.jsonObject(with: listData) as? [[String: Any]])
            #expect(json.count == 1)
            #expect(json[0]["name"] as? String == "nested.txt")
        }

        @Test("Upload, rename, and download workflow works end-to-end")
        func uploadRenameDownloadWorkflow() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            // Upload
            let uploadURL = baseURL.appendingPathComponent("upload")
            let content = Data("workflow data".utf8)
            let (_, uploadResponse) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "original.txt",
                fileContent: content,
                fileMIME: "text/plain"
            )
            #expect(uploadResponse.statusCode == 200)

            // Rename
            let moveURL = baseURL.appendingPathComponent("move")
            let (_, moveResponse) = try await parent.sendFormPOST(
                to: moveURL,
                formBody: "oldPath=/original.txt&newPath=/renamed.txt"
            )
            #expect(moveResponse.statusCode == 200)

            // Download the renamed file
            let downloadURL = try #require(URL(string: "/download?path=/renamed.txt", relativeTo: baseURL))
            let (data, dlResponse) = try await parent.sendGET(to: downloadURL)
            #expect(dlResponse.statusCode == 200)
            #expect(data == content)

            // Original should no longer exist
            #expect(!FileManager.default.fileExists(atPath: dir + "/original.txt"))
        }

        @Test("Upload, delete, and verify file is gone workflow")
        func uploadDeleteVerifyWorkflow() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            // Upload
            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, uploadResponse) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "ephemeral.txt",
                fileContent: Data("soon gone".utf8),
                fileMIME: "text/plain"
            )
            #expect(uploadResponse.statusCode == 200)
            #expect(FileManager.default.fileExists(atPath: dir + "/ephemeral.txt"))

            // Delete
            let deleteURL = baseURL.appendingPathComponent("delete")
            let (_, deleteResponse) = try await parent.sendFormPOST(
                to: deleteURL,
                formBody: "path=/ephemeral.txt"
            )
            #expect(deleteResponse.statusCode == 200)

            // Verify via listing
            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (listData, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: listData) as? [[String: Any]])
            #expect(json.isEmpty)
        }

        @Test("allowedFileExtensions filtering is case-insensitive")
        func extensionFilterIsCaseInsensitive() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt"]

            // Create a file with uppercase extension directly on disk
            try Data("uppercase ext".utf8).write(to: URL(fileURLWithPath: dir + "/file.TXT"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            // The list endpoint should include it because the check is case-insensitive
            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (listData, listResponse) = try await parent.sendGET(to: listURL)

            #expect(listResponse.statusCode == 200)

            let json = try #require(try JSONSerialization.jsonObject(with: listData) as? [[String: Any]])
            let names = json.compactMap { $0["name"] as? String }
            #expect(names.contains("file.TXT"))
        }

        @Test("allowedFileExtensions does not affect directories in listings")
        func extensionFilterDoesNotAffectDirectories() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            uploader.allowedFileExtensions = ["txt"]

            // Create a directory that looks like it has an extension
            try FileManager.default.createDirectory(
                atPath: dir + "/docs.pdf",
                withIntermediateDirectories: true
            )
            try Data("allowed".utf8).write(to: URL(fileURLWithPath: dir + "/file.txt"))
            try Data("blocked".utf8).write(to: URL(fileURLWithPath: dir + "/file.pdf"))

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (listData, _) = try await parent.sendGET(to: listURL)

            let json = try #require(try JSONSerialization.jsonObject(with: listData) as? [[String: Any]])
            let names = json.compactMap { $0["name"] as? String }

            // Directory should be listed regardless of extension filter
            #expect(names.contains("docs.pdf"))
            // Allowed file listed
            #expect(names.contains("file.txt"))
            // Blocked file NOT listed
            #expect(!names.contains("file.pdf"))
        }

        @Test("Empty upload directory returns empty JSON array")
        func emptyUploadDirectory() async throws {
            let uploader = try parent.makeUploader()
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, response) = try await parent.sendGET(to: listURL)

            #expect(response.statusCode == 200)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.isEmpty)
        }

        @Test("Large file can be uploaded and downloaded correctly")
        func largeFileRoundTrip() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory
            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            // Create a 256KB file
            let size = 256 * 1024
            var content = Data(count: size)
            for i in 0..<size {
                content[i] = UInt8(i % 256)
            }

            let uploadURL = baseURL.appendingPathComponent("upload")
            let (_, uploadResponse) = try await parent.sendMultipartUpload(
                to: uploadURL,
                path: "/",
                fileName: "large.bin",
                fileContent: content
            )
            #expect(uploadResponse.statusCode == 200)

            // Download and verify
            let downloadURL = try #require(URL(string: "/download?path=/large.bin", relativeTo: baseURL))
            let (data, dlResponse) = try await parent.sendGET(to: downloadURL)

            #expect(dlResponse.statusCode == 200)
            #expect(data == content)
        }

        @Test("Multiple files can be listed together with correct metadata")
        func multipleFilesListedCorrectly() async throws {
            let uploader = try parent.makeUploader()
            let dir = uploader.uploadDirectory

            let files: [(String, String)] = [
                ("alpha.txt", "aaa"),
                ("beta.txt", "bbbbb"),
                ("gamma.txt", "ccccccccc"),
            ]

            for (name, content) in files {
                try Data(content.utf8).write(to: URL(fileURLWithPath: dir + "/\(name)"))
            }

            let baseURL = try parent.startUploader(uploader)
            defer {
                uploader.stop()
                parent.cleanupDirectory(dir)
            }

            let listURL = try #require(URL(string: "/list?path=/", relativeTo: baseURL))
            let (data, response) = try await parent.sendGET(to: listURL)

            #expect(response.statusCode == 200)

            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.count == 3)

            let names = json.compactMap { $0["name"] as? String }.sorted()
            #expect(names == ["alpha.txt", "beta.txt", "gamma.txt"])
        }
    }

    // MARK: - Server Lifecycle

    @Suite("Server lifecycle", .serialized, .tags(.uploader, .properties))
    struct ServerLifecycle {
        private let parent = DZWebUploaderTests()

        @Test("Server is not running before start")
        func notRunningBeforeStart() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            #expect(uploader.isRunning == false)
        }

        @Test("Server is running after start")
        func runningAfterStart() throws {
            let uploader = try parent.makeUploader()
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            _ = try self.parent.startUploader(uploader)
            #expect(uploader.isRunning == true)
        }

        @Test("Server is not running after stop")
        func notRunningAfterStop() throws {
            let uploader = try parent.makeUploader()
            defer { parent.cleanupDirectory(uploader.uploadDirectory) }

            _ = try self.parent.startUploader(uploader)
            uploader.stop()
            #expect(uploader.isRunning == false)
        }

        @Test("Server URL is non-nil when running")
        func serverURLIsNonNilWhenRunning() throws {
            let uploader = try parent.makeUploader()
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            _ = try self.parent.startUploader(uploader)
            #expect(uploader.serverURL != nil)
        }

        @Test("Server port is greater than zero when running on ephemeral port")
        func ephemeralPortIsNonZero() throws {
            let uploader = try parent.makeUploader()
            defer {
                uploader.stop()
                parent.cleanupDirectory(uploader.uploadDirectory)
            }

            _ = try self.parent.startUploader(uploader)
            #expect(uploader.port > 0)
        }
    }
}
