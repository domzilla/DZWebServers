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

/// A temporary upload directory and the uploader serving it. Stops the server and removes the
/// directory when the suite instance is released.
private final class UploaderFixture {
    let directory: String
    let uploader: DZWebUploader
    private var baseURL: URL?

    init() throws {
        self.directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebUploaderTests")
        self.uploader = DZWebUploader(uploadDirectory: self.directory)
    }

    deinit {
        // stop() aborts in DEBUG when the server is not running.
        if self.uploader.isRunning {
            self.uploader.stop()
        }
        try? FileManager.default.removeItem(atPath: self.directory)
    }

    func start() throws {
        try TestSupport.start(self.uploader)
        let baseURL = try #require(self.uploader.serverURL)
        self.baseURL = baseURL
    }

    // MARK: Files

    func path(_ relativePath: String) -> String {
        (self.directory as NSString).appendingPathComponent(relativePath)
    }

    func fileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: self.path(relativePath))
    }

    func isDirectory(_ relativePath: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: self.path(relativePath), isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    func contents(_ relativePath: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: self.path(relativePath)))
    }

    func writeFile(_ relativePath: String, content: String) throws {
        try Data(content.utf8).write(to: URL(fileURLWithPath: self.path(relativePath)))
    }

    func createDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(atPath: self.path(relativePath), withIntermediateDirectories: true)
    }

    // MARK: Requests

    func get(
        _ endpoint: String,
        path: String? = nil
    ) async throws
        -> (statusCode: Int, data: Data, response: HTTPURLResponse)
    {
        let baseURL = try #require(self.baseURL)
        var components = try #require(URLComponents(url: baseURL, resolvingAgainstBaseURL: false))
        components.path = endpoint
        if let path {
            components.queryItems = [URLQueryItem(name: "path", value: path)]
        }
        return try await TestSupport.sendRequest(url: #require(components.url))
    }

    func list(_ path: String) async throws -> [[String: Any]] {
        let (statusCode, data, _) = try await self.get("/list", path: path)
        #expect(statusCode == 200)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    func postForm(
        _ endpoint: String,
        body: String
    ) async throws
        -> Int
    {
        let (statusCode, _, _) = try await TestSupport.sendRequest(
            method: "POST",
            url: #require(self.baseURL).appendingPathComponent(endpoint),
            body: Data(body.utf8),
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
        return statusCode
    }

    func upload(
        fileName: String,
        content: Data,
        toPath path: String = "/"
    ) async throws
        -> (statusCode: Int, data: Data, response: HTTPURLResponse)
    {
        let boundary = "DZWebUploaderTestsBoundary"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"path\"\r\n\r\n\(path)\r\n".utf8))
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"files[]\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(content)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        return try await TestSupport.sendRequest(
            method: "POST",
            url: #require(self.baseURL).appendingPathComponent("upload"),
            body: body,
            headers: [
                "Content-Type": "multipart/form-data; boundary=\(boundary)",
                "Accept": "application/json",
            ]
        )
    }
}

@Suite("DZWebUploader", .serialized, .tags(.uploader, .integration))
struct DZWebUploaderTests {
    // MARK: Initialization

    @Suite("Initialization", .tags(.properties))
    struct Initialization {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("initWithUploadDirectory stores the path in uploadDirectory")
        func initStoresUploadDirectory() {
            #expect(self.fixture.uploader.uploadDirectory == self.fixture.directory)
        }

        @Test("Access control properties default to allowing all extensions and hiding hidden items")
        func accessControlDefaults() {
            #expect(self.fixture.uploader.allowedFileExtensions == nil)
            #expect(self.fixture.uploader.allowHiddenItems == false)
            #expect(self.fixture.uploader.epilogue == nil)
        }

        @Test("title, header, prologue and footer return their documented defaults")
        func textPropertiesReturnDocumentedDefaults() {
            let uploader = self.fixture.uploader
            withKnownIssue(
                "Framework bug: declared nonnull with documented defaults, but the getters return nil until set"
            ) {
                #expect(!uploader.title.isEmpty)
                #expect(uploader.header == uploader.title)
                #expect(!uploader.prologue.isEmpty)
                #expect(!uploader.footer.isEmpty)
            }
        }
    }

    // MARK: Web Page

    @Suite("GET / (web page)")
    struct WebPage {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("GET / serves the HTML page with the bundled default prologue")
        func rootServesHTMLPage() async throws {
            try self.fixture.start()

            let (statusCode, data, response) = try await self.fixture.get("/")
            let html = try #require(String(data: data, encoding: .utf8))

            #expect(statusCode == 200)
            #expect(response.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("text/html") == true)
            #expect(html.contains("<html"))
            #expect(html.contains("Drag &amp; drop files on this window"))
        }

        @Test("GET / renders the custom title, header, prologue, epilogue and footer")
        func rootRendersCustomTexts() async throws {
            self.fixture.uploader.title = "TitleMarker"
            self.fixture.uploader.header = "HeaderMarker"
            self.fixture.uploader.prologue = "<p>PrologueMarker</p>"
            self.fixture.uploader.epilogue = "<p>EpilogueMarker</p>"
            self.fixture.uploader.footer = "FooterMarker"
            try self.fixture.start()

            let (_, data, _) = try await self.fixture.get("/")
            let html = try #require(String(data: data, encoding: .utf8))

            #expect(html.contains("<title>TitleMarker</title>"))
            #expect(html.contains("<h1>HeaderMarker</h1>"))
            #expect(html.contains("<p>PrologueMarker</p>"))
            #expect(html.contains("<p>EpilogueMarker</p>"))
            #expect(html.contains("<p class=\"footer\">FooterMarker</p>"))
            #expect(!html.contains("Drag &amp; drop files on this window"))
        }
    }

    // MARK: Listing

    @Suite("GET /list (directory listing)")
    struct Listing {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("Listing an empty directory returns an empty JSON array")
        func listEmptyDirectory() async throws {
            try self.fixture.start()

            #expect(try await self.fixture.list("/").isEmpty)
        }

        @Test("Listing returns files sorted by name with path and size")
        func listReturnsFilesWithMetadata() async throws {
            try self.fixture.writeFile("gamma.txt", content: "ccccccccc")
            try self.fixture.writeFile("alpha.txt", content: "aaa")
            try self.fixture.writeFile("beta.txt", content: "bbbbb")
            try self.fixture.start()

            let entries = try await self.fixture.list("/")

            #expect(entries.compactMap { $0["name"] as? String } == ["alpha.txt", "beta.txt", "gamma.txt"])
            #expect(entries.compactMap { $0["path"] as? String } == ["/alpha.txt", "/beta.txt", "/gamma.txt"])
            #expect(entries.compactMap { $0["size"] as? Int } == [3, 5, 9])
        }

        @Test("Listing returns directories with a trailing slash and no size")
        func listReturnsDirectories() async throws {
            try self.fixture.createDirectory("subdir")
            try self.fixture.start()

            let entries = try await self.fixture.list("/")
            let entry = try #require(entries.first)

            #expect(entries.count == 1)
            #expect(entry["name"] as? String == "subdir")
            #expect(entry["path"] as? String == "/subdir/")
            #expect(entry["size"] == nil)
        }

        @Test("Listing a subdirectory returns its contents")
        func listSubdirectory() async throws {
            try self.fixture.createDirectory("sub")
            try self.fixture.writeFile("sub/nested.txt", content: "nested")
            try self.fixture.start()

            let entries = try await self.fixture.list("/sub")

            #expect(entries.compactMap { $0["name"] as? String } == ["nested.txt"])
            #expect(entries.first?["path"] as? String == "/sub/nested.txt")
        }

        @Test("Hidden files are listed only when allowHiddenItems is true", arguments: [false, true])
        func listHonorsAllowHiddenItems(allowHiddenItems: Bool) async throws {
            self.fixture.uploader.allowHiddenItems = allowHiddenItems
            try self.fixture.writeFile("visible.txt", content: "visible")
            try self.fixture.writeFile(".hidden.txt", content: "hidden")
            try self.fixture.start()

            let names = try await Set(self.fixture.list("/").compactMap { $0["name"] as? String })
            let expectedNames: Set<String> = allowHiddenItems ? [".hidden.txt", "visible.txt"] : ["visible.txt"]

            #expect(names == expectedNames)
        }

        @Test("allowedFileExtensions filters files case-insensitively and leaves directories alone")
        func listHonorsAllowedFileExtensions() async throws {
            self.fixture.uploader.allowedFileExtensions = ["txt"]
            try self.fixture.createDirectory("docs.pdf")
            try self.fixture.writeFile("file.txt", content: "allowed")
            try self.fixture.writeFile("upper.TXT", content: "allowed")
            try self.fixture.writeFile("file.pdf", content: "blocked")
            try self.fixture.start()

            let names = try await Set(self.fixture.list("/").compactMap { $0["name"] as? String })

            #expect(names == ["docs.pdf", "file.txt", "upper.TXT"])
        }

        @Test("Listing a nonexistent path returns 404")
        func listNonexistentPathReturns404() async throws {
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.get("/list", path: "/nonexistent")

            #expect(statusCode == 404)
        }
    }

    // MARK: Upload

    @Suite("POST /upload (file upload)", .tags(.fileIO))
    struct Upload {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("Upload saves the file content and answers with JSON")
        func uploadSavesFile() async throws {
            try self.fixture.start()
            let content = Data("Disk content check".utf8)

            let (statusCode, _, response) = try await self.fixture.upload(fileName: "uploaded.txt", content: content)

            #expect(statusCode == 200)
            #expect(response.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(try self.fixture.contents("uploaded.txt") == content)
        }

        @Test("Upload into a subdirectory saves the file there")
        func uploadIntoSubdirectory() async throws {
            try self.fixture.createDirectory("docs")
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.upload(
                fileName: "subfile.txt",
                content: Data("sub".utf8),
                toPath: "/docs"
            )

            #expect(statusCode == 200)
            #expect(try self.fixture.contents("docs/subfile.txt") == Data("sub".utf8))
        }

        @Test("Uploading a duplicate file name keeps the original and renames the new file")
        func uploadDuplicateRenamesNewFile() async throws {
            try self.fixture.writeFile("dup.txt", content: "original")
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.upload(fileName: "dup.txt", content: Data("duplicate".utf8))

            #expect(statusCode == 200)
            #expect(try self.fixture.contents("dup.txt") == Data("original".utf8))
            #expect(try self.fixture.contents("dup (1).txt") == Data("duplicate".utf8))
        }

        @Test("Uploading a hidden file is rejected when allowHiddenItems is false")
        func uploadRejectsHiddenFile() async throws {
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.upload(fileName: ".secret", content: Data("hidden".utf8))

            #expect(statusCode == 403)
            #expect(!self.fixture.fileExists(".secret"))
        }

        @Test(
            "Upload honors allowedFileExtensions",
            arguments: [("image.png", 403), ("notes.md", 200)] as [(String, Int)]
        )
        func uploadHonorsAllowedFileExtensions(fileName: String, expectedStatusCode: Int) async throws {
            self.fixture.uploader.allowedFileExtensions = ["txt", "md"]
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.upload(fileName: fileName, content: Data("data".utf8))

            #expect(statusCode == expectedStatusCode)
            #expect(self.fixture.fileExists(fileName) == (expectedStatusCode == 200))
        }

        @Test("Uploaded file with a Unicode name appears in the listing")
        func uploadUnicodeFileName() async throws {
            try self.fixture.start()
            let fileName = "\u{1F600}emoji.txt"

            let (statusCode, _, _) = try await self.fixture.upload(fileName: fileName, content: Data("unicode".utf8))
            let names = try await self.fixture.list("/").compactMap { $0["name"] as? String }

            #expect(statusCode == 200)
            #expect(names == [fileName])
        }

        @Test("Uploaded file with spaces in its name can be downloaded")
        func uploadFileNameWithSpaces() async throws {
            try self.fixture.start()
            let content = Data("spaces in name".utf8)

            let (uploadStatusCode, _, _) = try await self.fixture.upload(fileName: "my file.txt", content: content)
            let (downloadStatusCode, data, _) = try await self.fixture.get("/download", path: "/my file.txt")

            #expect(uploadStatusCode == 200)
            #expect(downloadStatusCode == 200)
            #expect(data == content)
        }

        @Test("Large binary file survives an upload and download round trip")
        func largeFileRoundTrip() async throws {
            try self.fixture.start()
            let content = Data((0..<(256 * 1024)).map { UInt8(truncatingIfNeeded: $0) })

            let (uploadStatusCode, _, _) = try await self.fixture.upload(fileName: "large.bin", content: content)
            let (downloadStatusCode, data, _) = try await self.fixture.get("/download", path: "/large.bin")

            #expect(uploadStatusCode == 200)
            #expect(downloadStatusCode == 200)
            #expect(data == content)
        }
    }

    // MARK: Delete

    @Suite("POST /delete (file deletion)", .tags(.fileIO))
    struct Delete {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("Deleting a file removes it")
        func deleteRemovesFile() async throws {
            try self.fixture.writeFile("todelete.txt", content: "delete me")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("delete", body: "path=/todelete.txt")

            #expect(statusCode == 200)
            #expect(!self.fixture.fileExists("todelete.txt"))
        }

        @Test("Deleting a directory removes it recursively")
        func deleteRemovesDirectoryRecursively() async throws {
            try self.fixture.createDirectory("removeme")
            try self.fixture.writeFile("removeme/nested.txt", content: "nested")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("delete", body: "path=/removeme")

            #expect(statusCode == 200)
            #expect(!self.fixture.fileExists("removeme"))
        }

        @Test("Deleting a nonexistent file returns 404")
        func deleteNonexistentFileReturns404() async throws {
            try self.fixture.start()

            #expect(try await self.fixture.postForm("delete", body: "path=/ghost.txt") == 404)
        }

        @Test("Deleting a hidden file is rejected when allowHiddenItems is false")
        func deleteRejectsHiddenFile() async throws {
            try self.fixture.writeFile(".hidden", content: "hidden")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("delete", body: "path=/.hidden")

            #expect(statusCode == 403)
            #expect(self.fixture.fileExists(".hidden"))
        }

        @Test("Deleting a file with a disallowed extension is rejected")
        func deleteRejectsDisallowedExtension() async throws {
            self.fixture.uploader.allowedFileExtensions = ["txt"]
            try self.fixture.writeFile("blocked.pdf", content: "pdf")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("delete", body: "path=/blocked.pdf")

            #expect(statusCode == 403)
            #expect(self.fixture.fileExists("blocked.pdf"))
        }
    }

    // MARK: Move

    @Suite("POST /move (file moving/renaming)", .tags(.fileIO))
    struct Move {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("Moving a file renames it")
        func moveRenamesFile() async throws {
            try self.fixture.writeFile("old.txt", content: "movable")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("move", body: "oldPath=/old.txt&newPath=/new.txt")

            #expect(statusCode == 200)
            #expect(!self.fixture.fileExists("old.txt"))
            #expect(try self.fixture.contents("new.txt") == Data("movable".utf8))
        }

        @Test("Moving a file into a subdirectory relocates it")
        func moveIntoSubdirectory() async throws {
            try self.fixture.writeFile("file.txt", content: "mobile")
            try self.fixture.createDirectory("subdir")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm(
                "move",
                body: "oldPath=/file.txt&newPath=/subdir/file.txt"
            )

            #expect(statusCode == 200)
            #expect(!self.fixture.fileExists("file.txt"))
            #expect(self.fixture.fileExists("subdir/file.txt"))
        }

        @Test("Moving a nonexistent source returns 404")
        func moveNonexistentSourceReturns404() async throws {
            try self.fixture.start()

            #expect(try await self.fixture.postForm("move", body: "oldPath=/ghost.txt&newPath=/new.txt") == 404)
        }

        @Test("Moving onto an existing file keeps it and renames the moved file")
        func moveOntoExistingFileRenames() async throws {
            try self.fixture.writeFile("a.txt", content: "source")
            try self.fixture.writeFile("b.txt", content: "existing")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("move", body: "oldPath=/a.txt&newPath=/b.txt")

            #expect(statusCode == 200)
            #expect(!self.fixture.fileExists("a.txt"))
            #expect(try self.fixture.contents("b.txt") == Data("existing".utf8))
            #expect(try self.fixture.contents("b (1).txt") == Data("source".utf8))
        }

        @Test(
            "Moving from or to a hidden name is rejected when allowHiddenItems is false",
            arguments: [
                (".secret", "oldPath=/.secret&newPath=/revealed.txt"),
                ("visible.txt", "oldPath=/visible.txt&newPath=/.hidden"),
            ] as [(String, String)]
        )
        func moveRejectsHiddenNames(existingFile: String, body: String) async throws {
            try self.fixture.writeFile(existingFile, content: "content")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("move", body: body)

            #expect(statusCode == 403)
            #expect(self.fixture.fileExists(existingFile))
        }
    }

    // MARK: Create

    @Suite("POST /create (directory creation)", .tags(.fileIO))
    struct Create {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("Creating a directory adds it to the upload directory")
        func createAddsDirectory() async throws {
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("create", body: "path=/newdir")

            #expect(statusCode == 200)
            #expect(self.fixture.isDirectory("newdir"))
        }

        @Test("Creating an existing directory name creates a renamed directory")
        func createExistingDirectoryRenames() async throws {
            try self.fixture.createDirectory("existing")
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("create", body: "path=/existing")

            #expect(statusCode == 200)
            #expect(self.fixture.isDirectory("existing (1)"))
        }

        @Test("Hidden directories are created only when allowHiddenItems is true", arguments: [false, true])
        func createHonorsAllowHiddenItems(allowHiddenItems: Bool) async throws {
            self.fixture.uploader.allowHiddenItems = allowHiddenItems
            try self.fixture.start()

            let statusCode = try await self.fixture.postForm("create", body: "path=/.dotdir")

            #expect(statusCode == (allowHiddenItems ? 200 : 403))
            #expect(self.fixture.isDirectory(".dotdir") == allowHiddenItems)
        }
    }

    // MARK: Download

    @Suite("GET /download (file download)", .tags(.fileIO))
    struct Download {
        private let fixture: UploaderFixture

        init() throws {
            self.fixture = try UploaderFixture()
        }

        @Test("Download returns the file content as an attachment")
        func downloadReturnsAttachment() async throws {
            try self.fixture.writeFile("dl.txt", content: "Download me!")
            try self.fixture.start()

            let (statusCode, data, response) = try await self.fixture.get("/download", path: "/dl.txt")

            #expect(statusCode == 200)
            #expect(data == Data("Download me!".utf8))
            #expect(
                response.value(forHTTPHeaderField: "Content-Disposition")
                    == "attachment; filename=\"dl.txt\"; filename*=UTF-8''dl.txt"
            )
        }

        @Test("Downloading a nonexistent file returns 404")
        func downloadNonexistentFileReturns404() async throws {
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.get("/download", path: "/nope.txt")

            #expect(statusCode == 404)
        }

        @Test("Downloading a hidden file is rejected when allowHiddenItems is false")
        func downloadRejectsHiddenFile() async throws {
            try self.fixture.writeFile(".secret", content: "hidden")
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.get("/download", path: "/.secret")

            #expect(statusCode == 403)
        }

        @Test("Downloading a file with a disallowed extension is rejected")
        func downloadRejectsDisallowedExtension() async throws {
            self.fixture.uploader.allowedFileExtensions = ["txt"]
            try self.fixture.writeFile("file.exe", content: "blocked")
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.get("/download", path: "/file.exe")

            #expect(statusCode == 403)
        }

        @Test("Downloading a directory returns 400")
        func downloadDirectoryReturns400() async throws {
            try self.fixture.createDirectory("adir")
            try self.fixture.start()

            let (statusCode, _, _) = try await self.fixture.get("/download", path: "/adir")

            #expect(statusCode == 400)
        }
    }
}
