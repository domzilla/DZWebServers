//
//  DZWebServerFileResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

// Nonexistent paths, directories and empty paths are not tested: the initializer hits
// DWS_DNOT_REACHED(), which aborts in DEBUG builds.

/// Temporary directory for one test's fixture files, removed when the suite instance is released.
private final class FixtureDirectory {
    let path: String

    init() throws {
        self.path = try TestSupport.makeTemporaryDirectory(prefix: "DZWebServerFileResponseTests")
    }

    deinit {
        try? FileManager.default.removeItem(atPath: self.path)
    }

    func writeFile(named name: String, content: Data) throws -> String {
        let path = (self.path as NSString).appendingPathComponent(name)
        try content.write(to: URL(fileURLWithPath: path))
        return path
    }
}

/// Bytes `0, 1, 2, …` wrapping at 256, so every offset of a range is distinguishable.
private func makeTestData(byteCount: Int) -> Data {
    Data((0..<byteCount).map { UInt8(truncatingIfNeeded: $0) })
}

/// `NSMakeRange(NSUIntegerMax, length)`: the framework's sentinel for "last `length` bytes";
/// a length of 0 means the whole file without a range.
private func suffixRange(length: Int) -> NSRange {
    NSRange(location: Int(bitPattern: UInt.max), length: length)
}

/// `additionalHeaders` is declared in the framework's private header only.
private func additionalHeaders(of response: DZWebServerResponse) -> [String: String] {
    response.value(forKey: "additionalHeaders") as? [String: String] ?? [:]
}

@Suite("DZWebServerFileResponse", .serialized, .tags(.response, .fileIO))
struct DZWebServerFileResponseTests {
    // MARK: Full File

    @Suite("Full file")
    struct FullFile {
        private let directory: FixtureDirectory

        init() throws {
            self.directory = try FixtureDirectory()
        }

        @Test("Full-file response has status 200, file size, MIME type and file metadata")
        func fullFileResponseReflectsFile() throws {
            let path = try self.directory.writeFile(named: "hello.txt", content: makeTestData(byteCount: 512))
            let response = try #require(DZWebServerFileResponse(file: path))

            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let modificationDate = try #require(attributes[.modificationDate] as? Date)

            #expect(response.statusCode == 200)
            #expect(response.contentLength == 512)
            #expect(response.contentType == "text/plain")
            #expect(response.hasBody())
            #expect(abs(response.lastModifiedDate.timeIntervalSince(modificationDate)) < 0.001)
            #expect(!response.eTag.isEmpty)
            #expect(additionalHeaders(of: response)["Content-Range"] == nil)
        }

        @Test(
            "MIME type is resolved from the file extension",
            arguments: [
                ("page.html", "text/html"),
                ("style.css", "text/css"),
                ("app.js", "text/javascript"),
                ("data.json", "application/json"),
                ("image.png", "image/png"),
                ("photo.jpg", "image/jpeg"),
                ("document.pdf", "application/pdf"),
                ("Makefile", "application/octet-stream"),
            ] as [(String, String)]
        )
        func mimeTypeIsResolvedFromExtension(fileName: String, expectedContentType: String) throws {
            let path = try self.directory.writeFile(named: fileName, content: Data("x".utf8))
            let response = try #require(DZWebServerFileResponse(file: path))

            #expect(response.contentType == expectedContentType)
        }

        @Test("MIME type override replaces the built-in type for its extension")
        func mimeTypeOverrideReplacesBuiltInType() throws {
            let path = try self.directory.writeFile(named: "data.txt", content: Data("override".utf8))
            let response = try #require(
                DZWebServerFileResponse(
                    file: path,
                    byteRange: suffixRange(length: 0),
                    isAttachment: false,
                    mimeTypeOverrides: ["txt": "application/custom"]
                )
            )

            #expect(response.contentType == "application/custom")
        }

        @Test("Empty file is served in full with zero length and an empty body")
        func emptyFileIsServedInFull() throws {
            let path = try self.directory.writeFile(named: "empty.dat", content: Data())
            let response = try #require(DZWebServerFileResponse(file: path))

            #expect(response.statusCode == 200)
            #expect(response.contentLength == 0)
            #expect(response.hasBody())
            #expect(try TestSupport.readBody(of: response).isEmpty)
        }

        @Test(
            "Files with special characters in their names are served",
            arguments: [
                "\u{1F4C4}document\u{00E9}.txt",
                "my document file.txt",
                String(repeating: "a", count: 200) + ".txt",
            ]
        )
        func specialFileNamesAreServed(fileName: String) throws {
            let content = Data("special name".utf8)
            let path = try self.directory.writeFile(named: fileName, content: content)
            let response = try #require(DZWebServerFileResponse(file: path))

            #expect(response.contentLength == UInt(content.count))
            #expect(try TestSupport.readBody(of: response) == content)
        }
    }

    // MARK: Byte Range

    @Suite("Byte range")
    struct ByteRange {
        private let directory: FixtureDirectory

        init() throws {
            self.directory = try FixtureDirectory()
        }

        @Test(
            "Byte range is clamped to the file and served as 206 with a Content-Range header",
            arguments: [
                (1000, NSRange(location: 0, length: 100), 100, "bytes 0-99/1000"),
                (1000, suffixRange(length: 100), 100, "bytes 900-999/1000"),
                (200, NSRange(location: 0, length: 1000), 200, "bytes 0-199/200"),
                (50, suffixRange(length: 9999), 50, "bytes 0-49/50"),
                (256, NSRange(location: 0, length: 256), 256, "bytes 0-255/256"),
            ] as [(Int, NSRange, UInt, String)]
        )
        func byteRangeIsServedAsPartialContent(
            fileSize: Int,
            range: NSRange,
            expectedLength: UInt,
            expectedContentRange: String
        ) throws {
            let path = try self.directory.writeFile(named: "ranged.bin", content: makeTestData(byteCount: fileSize))
            let response = try #require(DZWebServerFileResponse(file: path, byteRange: range))

            #expect(response.statusCode == 206)
            #expect(response.contentLength == expectedLength)
            #expect(additionalHeaders(of: response)["Content-Range"] == expectedContentRange)
        }

        @Test("Whole-file sentinel range serves the full file as 200 without Content-Range")
        func wholeFileSentinelServesFullFile() throws {
            let path = try self.directory.writeFile(named: "full.bin", content: makeTestData(byteCount: 500))
            let response = try #require(DZWebServerFileResponse(file: path, byteRange: suffixRange(length: 0)))

            #expect(response.statusCode == 200)
            #expect(response.contentLength == 500)
            #expect(additionalHeaders(of: response)["Content-Range"] == nil)
        }

        @Test(
            "Byte range resolving to zero bytes returns nil",
            arguments: [
                (100, NSRange(location: 100, length: 50)),
                (0, NSRange(location: 0, length: 100)),
                (0, suffixRange(length: 100)),
            ] as [(Int, NSRange)]
        )
        func zeroLengthRangeReturnsNil(fileSize: Int, range: NSRange) throws {
            let path = try self.directory.writeFile(named: "small.bin", content: makeTestData(byteCount: fileSize))

            #expect(DZWebServerFileResponse(file: path, byteRange: range) == nil)
        }
    }

    // MARK: Attachment

    @Suite("Attachment")
    struct Attachment {
        private let directory: FixtureDirectory

        init() throws {
            self.directory = try FixtureDirectory()
        }

        @Test("Attachment response sets a Content-Disposition header with the file name")
        func attachmentSetsContentDisposition() throws {
            let path = try self.directory.writeFile(named: "download.zip", content: Data("zip".utf8))
            let response = try #require(DZWebServerFileResponse(file: path, isAttachment: true))

            #expect(response.statusCode == 200)
            #expect(
                additionalHeaders(of: response)["Content-Disposition"]
                    == "attachment; filename=\"download.zip\"; filename*=UTF-8''download.zip"
            )
        }

        @Test("Inline response has no Content-Disposition header")
        func inlineResponseHasNoContentDisposition() throws {
            let path = try self.directory.writeFile(named: "inline.txt", content: Data("inline".utf8))
            let response = try #require(DZWebServerFileResponse(file: path, isAttachment: false))

            #expect(additionalHeaders(of: response)["Content-Disposition"] == nil)
        }

        @Test("Attachment with a non-ASCII file name percent-encodes it in filename*")
        func attachmentPercentEncodesNonASCIIFileName() throws {
            let path = try self.directory.writeFile(named: "r\u{00E9}sum\u{00E9}.txt", content: Data("cv".utf8))
            let response = try #require(DZWebServerFileResponse(file: path, isAttachment: true))

            #expect(
                additionalHeaders(of: response)["Content-Disposition"]
                    == "attachment; filename=\"r\u{00E9}sum\u{00E9}.txt\"; filename*=UTF-8''r%C3%A9sum%C3%A9.txt"
            )
        }

        @Test("Attachment with a byte range sets both Content-Disposition and Content-Range")
        func attachmentWithByteRangeSetsBothHeaders() throws {
            let path = try self.directory.writeFile(named: "partial.bin", content: makeTestData(byteCount: 500))
            let response = try #require(
                DZWebServerFileResponse(
                    file: path,
                    byteRange: NSRange(location: 0, length: 200),
                    isAttachment: true,
                    mimeTypeOverrides: nil
                )
            )
            let headers = additionalHeaders(of: response)

            #expect(response.statusCode == 206)
            #expect(response.contentLength == 200)
            #expect(headers["Content-Range"] == "bytes 0-199/500")
            #expect(headers["Content-Disposition"]?.hasPrefix("attachment; filename=\"partial.bin\"") == true)
        }
    }

    // MARK: ETag

    @Suite("ETag")
    struct ETag {
        private let directory: FixtureDirectory

        init() throws {
            self.directory = try FixtureDirectory()
        }

        @Test("Responses for the same unmodified file have identical eTag and lastModifiedDate")
        func unmodifiedFileHasStableValidators() throws {
            let path = try self.directory.writeFile(named: "stable.txt", content: Data("stable".utf8))
            let first = try #require(DZWebServerFileResponse(file: path))
            let second = try #require(DZWebServerFileResponse(file: path))

            #expect(first.eTag == second.eTag)
            #expect(first.lastModifiedDate == second.lastModifiedDate)
        }

        @Test("eTag and lastModifiedDate change when the file's modification date changes")
        func modifiedFileChangesValidators() throws {
            let path = try self.directory.writeFile(named: "mutable.txt", content: Data("version 1".utf8))
            let original = try #require(DZWebServerFileResponse(file: path))

            let newModificationDate = original.lastModifiedDate.addingTimeInterval(-3600)
            try FileManager.default.setAttributes([.modificationDate: newModificationDate], ofItemAtPath: path)
            let modified = try #require(DZWebServerFileResponse(file: path))

            #expect(modified.eTag != original.eTag)
            #expect(abs(modified.lastModifiedDate.timeIntervalSince(newModificationDate)) < 0.001)
        }
    }

    // MARK: Body Reader

    @Suite("Body reader")
    struct BodyReader {
        private let directory: FixtureDirectory

        init() throws {
            self.directory = try FixtureDirectory()
        }

        @Test("Reading a file larger than the read buffer returns its full content")
        func readingReturnsFullContent() throws {
            // Larger than the framework's 32 KiB read buffer, so several chunks are read.
            let content = makeTestData(byteCount: 100_000)
            let path = try self.directory.writeFile(named: "readable.bin", content: content)
            let response = try #require(DZWebServerFileResponse(file: path))

            #expect(try TestSupport.readBody(of: response) == content)
        }

        @Test("Reading a byte range returns only the requested bytes")
        func readingByteRangeReturnsRequestedBytes() throws {
            let content = makeTestData(byteCount: 1000)
            let path = try self.directory.writeFile(named: "range.bin", content: content)
            let response = try #require(
                DZWebServerFileResponse(file: path, byteRange: NSRange(location: 100, length: 100))
            )

            #expect(try TestSupport.readBody(of: response) == content.subdata(in: 100..<200))
        }
    }
}
