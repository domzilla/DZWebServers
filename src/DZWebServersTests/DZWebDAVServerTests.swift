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

/// A running DAV server serving a fresh temporary directory.
private struct DAVFixture {
    let server: DZWebDAVServer
    let baseURL: URL
    let directory: String

    func url(_ path: String) -> URL {
        self.baseURL.appendingPathComponent(path)
    }

    func diskPath(_ path: String) -> String {
        (self.directory as NSString).appendingPathComponent(path)
    }

    func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: self.diskPath(path))
    }

    func contents(_ path: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: self.diskPath(path)))
    }

    func writeFile(_ path: String, _ content: String) throws {
        let fullPath = self.diskPath(path)
        try FileManager.default.createDirectory(
            atPath: (fullPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: URL(fileURLWithPath: fullPath))
    }

    func createDirectory(_ path: String) throws {
        try FileManager.default.createDirectory(atPath: self.diskPath(path), withIntermediateDirectories: true)
    }

    func send(
        _ method: String,
        _ path: String = "",
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws
        -> (statusCode: Int, data: Data, response: HTTPURLResponse)
    {
        try await TestSupport.sendRequest(method: method, url: self.url(path), body: body, headers: headers)
    }

    func propfind(_ path: String = "", depth: String) async throws -> (statusCode: Int, xml: String) {
        let result = try await self.send("PROPFIND", path, headers: ["Depth": depth])
        return (result.statusCode, String(decoding: result.data, as: UTF8.self))
    }

    /// Sends COPY or MOVE with a Destination header pointing at `destination` on the same server.
    func transfer(
        _ method: String,
        from source: String,
        to destination: String,
        overwrite: String? = nil
    ) async throws
        -> Int
    {
        var headers = ["Destination": self.url(destination).absoluteString]
        headers["Overwrite"] = overwrite
        return try await self.send(method, source, headers: headers).statusCode
    }
}

/// Starts a DAV server on a fresh temporary directory, then stops it and removes the directory once `body` returns.
private func withDAVServer(
    configure: (DZWebDAVServer) -> Void = { _ in },
    _ body: (DAVFixture) async throws -> Void
) async throws {
    let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebDAVServerTests")
    defer { try? FileManager.default.removeItem(atPath: directory) }

    let server = DZWebDAVServer(uploadDirectory: directory)
    configure(server)
    try TestSupport.start(server)
    defer { server.stop() }

    let baseURL = try #require(server.serverURL)
    try await body(DAVFixture(server: server, baseURL: baseURL, directory: directory))
}

@Suite("DZWebDAVServer", .serialized, .tags(.webDAV))
struct DZWebDAVServerTests {
    // MARK: Initialization

    @Suite("Initialization", .serialized, .tags(.properties))
    struct Initialization {
        @Test("init stores the upload directory and starts with no extension filter and hidden items denied")
        func initSetsDefaults() throws {
            let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebDAVServerTests")
            defer { try? FileManager.default.removeItem(atPath: directory) }

            let server = DZWebDAVServer(uploadDirectory: directory)

            #expect(server.uploadDirectory == directory)
            #expect(server.allowedFileExtensions == nil)
            #expect(!server.allowHiddenItems)
        }

        @Test("Server starts on an ephemeral port and stops cleanly")
        func serverStartsAndStops() async throws {
            var startedServer: DZWebDAVServer?
            try await withDAVServer { fixture in
                startedServer = fixture.server
                #expect(fixture.server.isRunning)
                #expect(fixture.server.port > 0)
            }

            let server = try #require(startedServer)
            #expect(!server.isRunning)
        }
    }

    // MARK: OPTIONS

    @Suite("OPTIONS", .serialized, .tags(.integration))
    struct OPTIONSTests {
        @Test(
            "OPTIONS advertises class 1, plus class 2 for the macOS Finder",
            arguments: [("curl/8.0", "1"), ("WebDAVFS/3.0", "1, 2"), ("WebDAVLib/1.3", "1, 2")]
        )
        func optionsAdvertisesDAVClasses(userAgent: String, expectedDAVHeader: String) async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("OPTIONS", headers: ["User-Agent": userAgent])

                #expect(result.statusCode == 200)
                #expect(result.response.value(forHTTPHeaderField: "DAV") == expectedDAVHeader)
            }
        }
    }

    // MARK: GET

    @Suite("GET (Download)", .serialized, .tags(.integration, .fileIO))
    struct GETTests {
        @Test("GET an existing file returns 200 with its content and MIME type")
        func getExistingFile() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("page.html", "<html></html>")

                let result = try await fixture.send("GET", "page.html")

                #expect(result.statusCode == 200)
                #expect(result.data == Data("<html></html>".utf8))
                #expect(result.response.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("text/html") == true)
            }
        }

        @Test("GET a non-existent file returns 404")
        func getNonExistentFileReturns404() async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("GET", "does_not_exist.txt")

                #expect(result.statusCode == 404)
            }
        }

        @Test("GET a directory returns 200 with an empty body")
        func getDirectoryReturnsEmptyBody() async throws {
            try await withDAVServer { fixture in
                try fixture.createDirectory("subdir")

                let result = try await fixture.send("GET", "subdir")

                #expect(result.statusCode == 200)
                #expect(result.data.isEmpty)
            }
        }
    }

    // MARK: PUT

    @Suite("PUT (Upload)", .serialized, .tags(.integration, .fileIO))
    struct PUTTests {
        @Test("PUT a new file returns 201 and writes the body to disk")
        func putNewFile() async throws {
            try await withDAVServer { fixture in
                let body = Data("Hello, WebDAV!".utf8)

                let result = try await fixture.send("PUT", "hello.txt", body: body)

                #expect(result.statusCode == 201)
                #expect(try fixture.contents("hello.txt") == body)
            }
        }

        @Test("PUT over an existing file returns 204 and replaces its content")
        func putOverwritesExistingFile() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("versioned.txt", "v1")

                let second = try await fixture.send("PUT", "versioned.txt", body: Data("v2".utf8))
                let third = try await fixture.send("PUT", "versioned.txt", body: Data("v3".utf8))

                #expect(second.statusCode == 204)
                #expect(third.statusCode == 204)
                #expect(try fixture.contents("versioned.txt") == Data("v3".utf8))
            }
        }

        @Test("PUT into an existing subdirectory writes the file there")
        func putInSubdirectory() async throws {
            try await withDAVServer { fixture in
                try fixture.createDirectory("docs")
                let body = Data("In a subdirectory".utf8)

                let result = try await fixture.send("PUT", "docs/readme.txt", body: body)

                #expect(result.statusCode == 201)
                #expect(try fixture.contents("docs/readme.txt") == body)
            }
        }

        @Test("PUT into a non-existent parent directory returns 409 Conflict")
        func putMissingParentReturns409() async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("PUT", "nonexistent/dir/file.txt", body: Data("data".utf8))

                #expect(result.statusCode == 409)
                #expect(!fixture.fileExists("nonexistent"))
            }
        }
    }

    // MARK: DELETE

    @Suite("DELETE", .serialized, .tags(.integration, .fileIO))
    struct DELETETests {
        @Test("DELETE an existing file returns 204 and removes it from disk")
        func deleteExistingFile() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("deleteme.txt", "delete this")

                let result = try await fixture.send("DELETE", "deleteme.txt")

                #expect(result.statusCode == 204)
                #expect(!fixture.fileExists("deleteme.txt"))
            }
        }

        @Test("DELETE a non-existent file returns 404")
        func deleteNonExistentFileReturns404() async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("DELETE", "ghost.txt")

                #expect(result.statusCode == 404)
            }
        }

        @Test("DELETE a directory removes it recursively")
        func deleteDirectoryRemovesContents() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("folder/inside.txt", "nested")

                let result = try await fixture.send("DELETE", "folder")

                #expect(result.statusCode == 204)
                #expect(!fixture.fileExists("folder"))
            }
        }
    }

    // MARK: MKCOL

    @Suite("MKCOL (Create Directory)", .serialized, .tags(.integration, .fileIO))
    struct MKCOLTests {
        @Test("MKCOL creates a new directory and returns 201")
        func mkcolCreatesDirectory() async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("MKCOL", "newdir")

                #expect(result.statusCode == 201)
                var isDirectory: ObjCBool = false
                #expect(FileManager.default.fileExists(atPath: fixture.diskPath("newdir"), isDirectory: &isDirectory))
                #expect(isDirectory.boolValue)
            }
        }

        @Test("MKCOL on an existing directory returns 405 Method Not Allowed (RFC 4918 9.3.1)")
        func mkcolOnExistingDirectoryReturns405() async throws {
            try await withDAVServer { fixture in
                try fixture.createDirectory("existing")

                let result = try await fixture.send("MKCOL", "existing")

                #expect(result.statusCode == 405)
            }
        }

        @Test("MKCOL with a missing parent directory returns 409 Conflict")
        func mkcolMissingParentReturns409() async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("MKCOL", "parent/child")

                #expect(result.statusCode == 409)
            }
        }
    }

    // MARK: COPY

    @Suite("COPY", .serialized, .tags(.integration, .fileIO))
    struct COPYTests {
        @Test("COPY a file creates the destination and keeps the source")
        func copyFile() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("original.txt", "copy me")

                let statusCode = try await fixture.transfer("COPY", from: "original.txt", to: "copy.txt")

                #expect(statusCode == 201)
                #expect(try fixture.contents("original.txt") == Data("copy me".utf8))
                #expect(try fixture.contents("copy.txt") == Data("copy me".utf8))
            }
        }

        @Test("COPY a directory duplicates it recursively")
        func copyDirectoryRecursively() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("srcdir/nested.txt", "nested content")

                let statusCode = try await fixture.transfer("COPY", from: "srcdir", to: "dstdir")

                #expect(statusCode == 201)
                #expect(try fixture.contents("dstdir/nested.txt") == Data("nested content".utf8))
                #expect(fixture.fileExists("srcdir/nested.txt"))
            }
        }

        @Test("COPY without a Destination header returns 400")
        func copyWithoutDestinationReturns400() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("source.txt", "data")

                let result = try await fixture.send("COPY", "source.txt")

                #expect(result.statusCode == 400)
            }
        }

        @Test("COPY with Overwrite: F onto an existing destination returns 412 and keeps the destination")
        func copyOverwriteFalseReturns412() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("src.txt", "source")
                try fixture.writeFile("dst.txt", "existing")

                let statusCode = try await fixture.transfer("COPY", from: "src.txt", to: "dst.txt", overwrite: "F")

                #expect(statusCode == 412)
                #expect(try fixture.contents("dst.txt") == Data("existing".utf8))
            }
        }

        @Test("COPY onto an existing destination without Overwrite: F replaces it and returns 204 (RFC 4918 9.8.4)")
        func copyOverwritesExistingDestination() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("src.txt", "source")
                try fixture.writeFile("dst.txt", "existing")

                let statusCode = try await fixture.transfer("COPY", from: "src.txt", to: "dst.txt", overwrite: "T")

                #expect(statusCode == 204)
                #expect(try fixture.contents("dst.txt") == Data("source".utf8))
            }
        }
    }

    // MARK: MOVE

    @Suite("MOVE", .serialized, .tags(.integration, .fileIO))
    struct MOVETests {
        @Test("MOVE a file relocates it")
        func moveFile() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("moveme.txt", "move content")

                let statusCode = try await fixture.transfer("MOVE", from: "moveme.txt", to: "moved.txt")

                #expect(statusCode == 201)
                #expect(!fixture.fileExists("moveme.txt"))
                #expect(try fixture.contents("moved.txt") == Data("move content".utf8))
            }
        }

        @Test("MOVE a directory relocates it with all contents")
        func moveDirectory() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("move_src/inside.txt", "nested data")

                let statusCode = try await fixture.transfer("MOVE", from: "move_src", to: "move_dst")

                #expect(statusCode == 201)
                #expect(!fixture.fileExists("move_src"))
                #expect(try fixture.contents("move_dst/inside.txt") == Data("nested data".utf8))
            }
        }

        @Test("MOVE without a Destination header returns 400")
        func moveWithoutDestinationReturns400() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("orphan.txt", "data")

                let result = try await fixture.send("MOVE", "orphan.txt", headers: ["Overwrite": "T"])

                #expect(result.statusCode == 400)
                #expect(fixture.fileExists("orphan.txt"))
            }
        }

        @Test(
            "MOVE onto an existing destination without Overwrite: T returns 412",
            arguments: [nil, "F"] as [String?]
        )
        func moveWithoutOverwriteReturns412(overwrite: String?) async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("src_move.txt", "source")
                try fixture.writeFile("dst_move.txt", "dest")

                let statusCode = try await fixture.transfer(
                    "MOVE",
                    from: "src_move.txt",
                    to: "dst_move.txt",
                    overwrite: overwrite
                )

                #expect(statusCode == 412)
                #expect(try fixture.contents("dst_move.txt") == Data("dest".utf8))
            }
        }

        @Test("MOVE onto an existing destination with Overwrite: T replaces it and returns 204")
        func moveWithOverwriteReturns204() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("from.txt", "new data")
                try fixture.writeFile("to.txt", "old data")

                let statusCode = try await fixture.transfer("MOVE", from: "from.txt", to: "to.txt", overwrite: "T")

                #expect(statusCode == 204)
                #expect(!fixture.fileExists("from.txt"))
                #expect(try fixture.contents("to.txt") == Data("new data".utf8))
            }
        }
    }

    // MARK: COPY and MOVE Sources

    @Suite("COPY and MOVE Sources", .serialized, .tags(.integration))
    struct TransferSources {
        @Test("COPY or MOVE of a non-existent source returns 404", arguments: ["COPY", "MOVE"])
        func missingSourceReturns404(method: String) async throws {
            try await withDAVServer { fixture in
                let statusCode = try await fixture.transfer(method, from: "ghost.txt", to: "copy.txt")

                #expect(statusCode == 404)
                #expect(!fixture.fileExists("copy.txt"))
            }
        }
    }

    // MARK: PROPFIND

    @Suite("PROPFIND", .serialized, .tags(.integration))
    struct PROPFINDTests {
        @Test("PROPFIND Depth: 0 on the root returns only the root collection as multistatus XML")
        func propfindDepth0ReturnsOnlyRoot() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("child.txt", "child")

                let result = try await fixture.send("PROPFIND", headers: ["Depth": "0"])
                let xml = String(decoding: result.data, as: UTF8.self)

                #expect(result.statusCode == 207)
                #expect(result.response.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/xml") == true)
                #expect(xml.contains("<D:multistatus xmlns:D=\"DAV:\">"))
                #expect(xml.contains("<D:href>/</D:href>"))
                #expect(xml.contains("<D:resourcetype><D:collection/></D:resourcetype>"))
                #expect(!xml.contains("child.txt"))
            }
        }

        @Test("PROPFIND Depth: 1 lists the root's files and subdirectories")
        func propfindDepth1ListsChildren() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("file1.txt", "one")
                try fixture.writeFile("file2.txt", "two")
                try fixture.createDirectory("subdir")

                let (statusCode, xml) = try await fixture.propfind(depth: "1")

                #expect(statusCode == 207)
                #expect(xml.contains("<D:href>/file1.txt</D:href>"))
                #expect(xml.contains("<D:href>/file2.txt</D:href>"))
                #expect(xml.contains("<D:href>/subdir</D:href>"))
            }
        }

        @Test("PROPFIND reports file size, modification date and a non-collection resource type for files")
        func propfindReportsFileProperties() async throws {
            try await withDAVServer { fixture in
                try fixture.writeFile("sized.txt", "twelve bytes")

                let (statusCode, xml) = try await fixture.propfind("sized.txt", depth: "0")

                #expect(statusCode == 207)
                #expect(xml.contains("<D:getcontentlength>12</D:getcontentlength>"))
                #expect(xml.contains("<D:getlastmodified>"))
                #expect(xml.contains("<D:creationdate>"))
                #expect(xml.contains("<D:resourcetype/>"))
            }
        }

        @Test("PROPFIND on a non-existent resource returns 404")
        func propfindNonExistentReturns404() async throws {
            try await withDAVServer { fixture in
                let (statusCode, _) = try await fixture.propfind("nonexistent.txt", depth: "0")

                #expect(statusCode == 404)
            }
        }

        @Test("PROPFIND without a Depth header returns 400")
        func propfindWithoutDepthReturns400() async throws {
            try await withDAVServer { fixture in
                let result = try await fixture.send("PROPFIND")

                #expect(result.statusCode == 400)
            }
        }
    }

    // MARK: File Extensions Filter

    @Suite("File Extensions Filter", .serialized, .tags(.integration, .fileIO))
    struct FileExtensionsFilter {
        private static func allowTextFilesOnly(_ server: DZWebDAVServer) {
            server.allowedFileExtensions = ["txt"]
        }

        @Test("PUT of an allowed extension succeeds, case-insensitively", arguments: ["allowed.txt", "uppercase.TXT"])
        func putAllowedExtensionSucceeds(fileName: String) async throws {
            try await withDAVServer(configure: Self.allowTextFilesOnly) { fixture in
                let result = try await fixture.send("PUT", fileName, body: Data("text".utf8))

                #expect(result.statusCode == 201)
                #expect(fixture.fileExists(fileName))
            }
        }

        @Test(
            "PUT of a disallowed extension returns 403",
            arguments: ["blocked.jpg", "blocked.png", "blocked.exe", "blocked.pdf", "blocked.zip"]
        )
        func putDisallowedExtensionReturns403(fileName: String) async throws {
            try await withDAVServer(configure: Self.allowTextFilesOnly) { fixture in
                let result = try await fixture.send("PUT", fileName, body: Data("test".utf8))

                #expect(result.statusCode == 403)
                #expect(!fixture.fileExists(fileName))
            }
        }

        @Test("GET and DELETE of a disallowed extension return 403", arguments: ["GET", "DELETE"])
        func accessDisallowedExtensionReturns403(method: String) async throws {
            try await withDAVServer(configure: Self.allowTextFilesOnly) { fixture in
                try fixture.writeFile("secret.pdf", "pdf data")

                let result = try await fixture.send(method, "secret.pdf")

                #expect(result.statusCode == 403)
                #expect(fixture.fileExists("secret.pdf"))
            }
        }

        @Test("PROPFIND Depth: 1 omits files with a disallowed extension")
        func propfindOmitsDisallowedExtensions() async throws {
            try await withDAVServer(configure: Self.allowTextFilesOnly) { fixture in
                try fixture.writeFile("listed.txt", "text")
                try fixture.writeFile("unlisted.pdf", "pdf")

                let (_, xml) = try await fixture.propfind(depth: "1")

                #expect(xml.contains("listed.txt"))
                #expect(!xml.contains("unlisted.pdf"))
            }
        }

        @Test("MKCOL is not affected by the extension filter")
        func mkcolIgnoresExtensionFilter() async throws {
            try await withDAVServer(configure: Self.allowTextFilesOnly) { fixture in
                let result = try await fixture.send("MKCOL", "my.folder")

                #expect(result.statusCode == 201)
            }
        }

        @Test("COPY or MOVE to a disallowed extension returns 403", arguments: ["COPY", "MOVE"])
        func transferToDisallowedExtensionReturns403(method: String) async throws {
            try await withDAVServer(configure: Self.allowTextFilesOnly) { fixture in
                try fixture.writeFile("source.txt", "data")

                let statusCode = try await fixture.transfer(method, from: "source.txt", to: "renamed.exe")

                #expect(statusCode == 403)
                #expect(!fixture.fileExists("renamed.exe"))
            }
        }
    }

    // MARK: Hidden Items

    @Suite("Hidden Items", .serialized, .tags(.integration, .fileIO))
    struct HiddenItems {
        @Test("PUT of a hidden file is allowed only with allowHiddenItems", arguments: [(false, 403), (true, 201)])
        func putHiddenFile(isAllowed: Bool, expectedStatusCode: Int) async throws {
            try await withDAVServer(configure: { $0.allowHiddenItems = isAllowed }) { fixture in
                let result = try await fixture.send("PUT", ".hidden", body: Data("hidden content".utf8))

                #expect(result.statusCode == expectedStatusCode)
                #expect(fixture.fileExists(".hidden") == isAllowed)
            }
        }

        @Test("GET of a hidden file is allowed only with allowHiddenItems", arguments: [(false, 403), (true, 200)])
        func getHiddenFile(isAllowed: Bool, expectedStatusCode: Int) async throws {
            try await withDAVServer(configure: { $0.allowHiddenItems = isAllowed }) { fixture in
                try fixture.writeFile(".secret", "secret data")

                let result = try await fixture.send("GET", ".secret")

                #expect(result.statusCode == expectedStatusCode)
                if isAllowed {
                    #expect(result.data == Data("secret data".utf8))
                }
            }
        }

        @Test("MKCOL and DELETE of hidden items return 403 without allowHiddenItems", arguments: ["MKCOL", "DELETE"])
        func modifyHiddenItemDenied(method: String) async throws {
            try await withDAVServer { fixture in
                if method == "DELETE" {
                    try fixture.writeFile(".hidden_item", "data")
                }

                let result = try await fixture.send(method, ".hidden_item")

                #expect(result.statusCode == 403)
                #expect(fixture.fileExists(".hidden_item") == (method == "DELETE"))
            }
        }

        @Test("PROPFIND Depth: 1 lists hidden items only with allowHiddenItems", arguments: [false, true])
        func propfindHiddenItems(isAllowed: Bool) async throws {
            try await withDAVServer(configure: { $0.allowHiddenItems = isAllowed }) { fixture in
                try fixture.writeFile("visible.txt", "visible")
                try fixture.writeFile(".dotfile", "hidden")

                let (statusCode, xml) = try await fixture.propfind(depth: "1")

                #expect(statusCode == 207)
                #expect(xml.contains("visible.txt"))
                #expect(xml.contains(".dotfile") == isAllowed)
            }
        }
    }

    // MARK: Round-Trip

    @Suite("Round-Trip", .serialized, .tags(.integration, .fileIO))
    struct RoundTrip {
        @Test(
            "PUT then GET preserves content for names needing percent-encoding",
            arguments: [
                "caf\u{00E9}-\u{00FC}ber.txt",
                "\u{65E5}\u{672C}\u{8A9E}\u{30C6}\u{30B9}\u{30C8}.txt",
                "my document.txt",
                "report (final) & summary.txt",
            ]
        )
        func putThenGetWithEncodedName(fileName: String) async throws {
            try await withDAVServer { fixture in
                let content = Data("content of \(fileName)".utf8)

                let putResult = try await fixture.send("PUT", fileName, body: content)
                let getResult = try await fixture.send("GET", fileName)

                #expect(putResult.statusCode == 201)
                #expect(fixture.fileExists(fileName))
                #expect(getResult.statusCode == 200)
                #expect(getResult.data == content)
            }
        }

        @Test("PUT then GET preserves empty and large bodies", arguments: [0, 100 * 1024])
        func putThenGetPreservesBody(byteCount: Int) async throws {
            try await withDAVServer { fixture in
                let content = Data((0..<byteCount).map { UInt8($0 % 256) })

                let putResult = try await fixture.send("PUT", "payload.bin", body: content)
                let getResult = try await fixture.send("GET", "payload.bin")

                #expect(putResult.statusCode == 201)
                #expect(try fixture.contents("payload.bin") == content)
                #expect(getResult.statusCode == 200)
                #expect(getResult.data == content)
            }
        }

        @Test("Nested MKCOL calls then PUT and PROPFIND in the deepest directory")
        func nestedDirectories() async throws {
            try await withDAVServer { fixture in
                for path in ["level1", "level1/level2", "level1/level2/level3"] {
                    let result = try await fixture.send("MKCOL", path)
                    #expect(result.statusCode == 201, "MKCOL \(path)")
                }

                let putResult = try await fixture.send("PUT", "level1/level2/level3/deep.txt", body: Data("deep".utf8))
                let getResult = try await fixture.send("GET", "level1/level2/level3/deep.txt")
                let (statusCode, xml) = try await fixture.propfind("level1/level2/level3", depth: "1")

                #expect(putResult.statusCode == 201)
                #expect(getResult.data == Data("deep".utf8))
                #expect(statusCode == 207)
                #expect(xml.contains("<D:href>/level1/level2/level3/deep.txt</D:href>"))
            }
        }
    }
}
