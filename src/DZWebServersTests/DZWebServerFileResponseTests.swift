//
//  DZWebServerFileResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Test Helpers

/// Creates a unique temporary directory and returns its path.
/// The caller is responsible for cleaning up via `removeTestDirectory(_:)`.
private func makeTestDirectory() throws -> String {
    let basePath = NSTemporaryDirectory() as NSString
    let dirName = "DZWebServerFileResponseTests-\(UUID().uuidString)"
    let dirPath = basePath.appendingPathComponent(dirName)
    try FileManager.default.createDirectory(
        atPath: dirPath,
        withIntermediateDirectories: true,
        attributes: nil
    )
    return dirPath
}

/// Removes the temporary directory and all its contents.
private func removeTestDirectory(_ path: String) {
    try? FileManager.default.removeItem(atPath: path)
}

/// Writes a file with the given content into the specified directory and returns the full path.
@discardableResult
private func writeTestFile(
    named fileName: String,
    content: Data,
    inDirectory directory: String
) throws
    -> String
{
    let filePath = (directory as NSString).appendingPathComponent(fileName)
    try content.write(to: URL(fileURLWithPath: filePath))
    return filePath
}

/// Generates `count` bytes of repeating ASCII content.
private func makeTestData(byteCount count: Int) -> Data {
    guard count > 0 else { return Data() }
    let pattern: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\n".utf8)
    var bytes = [UInt8](repeating: 0, count: count)
    for i in 0..<count {
        bytes[i] = pattern[i % pattern.count]
    }
    return Data(bytes)
}

// MARK: - Basic File Response

@Suite("DZWebServerFileResponse - Basic File Response", .serialized, .tags(.response, .fileIO, .properties))
struct BasicFileResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Response for existing text file has correct status code 200")
    func responseForExistingTextFileHasStatusCode200() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "hello.txt", content: Data("Hello, world!".utf8), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(response != nil, "Should create a response for a valid text file")
        #expect(response?.statusCode == 200, "Status code should be 200 OK for a full file response")
    }

    @Test("Response for existing text file has non-nil contentType, lastModifiedDate, and eTag")
    func responseForExistingTextFileHasNonNilMetadataProperties() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "hello.txt", content: Data("Hello, world!".utf8), inDirectory: dir)
        let response = try #require(DZWebServerFileResponse(file: path))

        #expect(
            response.contentType.isEmpty == false,
            "contentType should be set for a valid file"
        )
        #expect(
            response.lastModifiedDate.timeIntervalSince1970 > 0,
            "lastModifiedDate should be a valid past/present date"
        )
        #expect(
            response.eTag.isEmpty == false,
            "eTag should be set for a valid file"
        )
    }

    @Test("Response contentLength matches the actual file size")
    func responseContentLengthMatchesActualFileSize() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 512)
        let path = try writeTestFile(named: "data.bin", content: content, inDirectory: dir)
        let response = try #require(DZWebServerFileResponse(file: path))

        #expect(
            response.contentLength == 512,
            "contentLength should equal the file size in bytes"
        )
    }

    @Test("Response hasBody returns true for a valid file")
    func responseHasBodyReturnsTrueForValidFile() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "test.txt", content: Data("content".utf8), inDirectory: dir)
        let response = try #require(DZWebServerFileResponse(file: path))

        #expect(
            response.hasBody() == true,
            "hasBody should return true because contentType is non-nil"
        )
    }

    @Test(
        "Response resolves the correct MIME type for common file extensions",
        arguments: [
            ("page.html", "text/html"),
            ("style.css", "text/css"),
            ("app.js", "text/javascript"),
            ("data.json", "application/json"),
            ("image.png", "image/png"),
            ("photo.jpg", "image/jpeg"),
            ("document.pdf", "application/pdf"),
        ] as [(String, String)]
    )
    func responseResolvesCorrectMIMETypeForCommonFileExtensions(
        fileName: String,
        expectedContentType: String
    ) throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: fileName, content: Data("x".utf8), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(response != nil, "Should create a response for '\(fileName)'")
        #expect(
            response?.contentType == expectedContentType,
            "Content type for '\(fileName)' should be '\(expectedContentType)' but got '\(response?.contentType ?? "nil")'"
        )
    }
}

// NOTE: Non-existent file, empty path, and directory path tests are omitted.
// DZWebServerFileResponse's init triggers DWS_DNOT_REACHED() → abort() in
// DEBUG builds when lstat fails or the path does not point to a regular file.
// These edge cases cannot be tested without crashing the test runner.

// MARK: - Byte Range

@Suite("DZWebServerFileResponse - Byte Range", .serialized, .tags(.response, .fileIO, .properties))
struct ByteRangeResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Partial range from beginning sets status 206 and correct contentLength")
    func partialRangeFromBeginningSetsStatus206AndCorrectContentLength() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 1000)
        let path = try writeTestFile(named: "ranged.bin", content: content, inDirectory: dir)

        // Request bytes 0-99 (100 bytes)
        let range = NSRange(location: 0, length: 100)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(response != nil, "Should create a response for a valid partial range")
        #expect(
            response?.statusCode == 206,
            "Status code should be 206 Partial Content for byte range requests"
        )
        #expect(
            response?.contentLength == 100,
            "contentLength should be 100 for a 100-byte range"
        )
    }

    @Test("Suffix range serves the last N bytes with status 206")
    func suffixRangeServesLastNBytesWithStatus206() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 1000)
        let path = try writeTestFile(named: "suffix.bin", content: content, inDirectory: dir)

        // Request last 100 bytes: NSMakeRange(NSUIntegerMax, 100)
        let range = NSRange(location: Int(bitPattern: UInt.max), length: 100)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(response != nil, "Should create a response for a suffix byte range")
        #expect(
            response?.statusCode == 206,
            "Status code should be 206 Partial Content for suffix range"
        )
        #expect(
            response?.contentLength == 100,
            "contentLength should be 100 for a 100-byte suffix range"
        )
    }

    @Test("Full file range NSMakeRange(NSUIntegerMax, 0) serves entire file with status 200")
    func fullFileRangeServesEntireFileWithStatus200() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 500)
        let path = try writeTestFile(named: "full.bin", content: content, inDirectory: dir)

        // NSMakeRange(NSUIntegerMax, 0) means "full file, no range restriction"
        let range = NSRange(location: Int(bitPattern: UInt.max), length: 0)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(response != nil, "Should create a response for the full file range")
        #expect(
            response?.statusCode == 200,
            "Status code should be 200 OK when serving the full file"
        )
        #expect(
            response?.contentLength == 500,
            "contentLength should equal the full file size"
        )
    }

    @Test("Range exceeding file size is clamped to actual file size")
    func rangeExceedingFileSizeIsClampedToActualFileSize() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 200)
        let path = try writeTestFile(named: "small.bin", content: content, inDirectory: dir)

        // Request bytes 0-999 but file is only 200 bytes
        let range = NSRange(location: 0, length: 1000)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(response != nil, "Should create a response even when range exceeds file size")
        #expect(
            response?.contentLength == 200,
            "contentLength should be clamped to the actual file size of 200 bytes"
        )
        #expect(
            response?.statusCode == 206,
            "Status code should still be 206 for a clamped byte range"
        )
    }

    @Test("Range with offset beyond file size results in zero length and returns nil")
    func rangeWithOffsetBeyondFileSizeReturnsNil() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 100)
        let path = try writeTestFile(named: "tiny.bin", content: content, inDirectory: dir)

        // Offset at file size means length is clamped to 0
        let range = NSRange(location: 100, length: 50)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(
            response == nil,
            "Should return nil when the resolved byte range has zero length"
        )
    }

    @Test("Suffix range larger than file size is clamped to entire file")
    func suffixRangeLargerThanFileSizeIsClampedToEntireFile() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 50)
        let path = try writeTestFile(named: "small2.bin", content: content, inDirectory: dir)

        // Request last 9999 bytes but file is only 50 bytes
        let range = NSRange(location: Int(bitPattern: UInt.max), length: 9999)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(response != nil, "Should create a response for an oversized suffix range")
        #expect(
            response?.contentLength == 50,
            "contentLength should be clamped to the full file size of 50 bytes"
        )
    }
}

// MARK: - Attachment

@Suite("DZWebServerFileResponse - Attachment", .serialized, .tags(.response, .properties))
struct AttachmentResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Response with isAttachment true creates successfully")
    func responseWithIsAttachmentTrueCreatesSuccessfully() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "download.zip", content: Data("fake zip".utf8), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path, isAttachment: true)

        #expect(
            response != nil,
            "Should create a response with the attachment disposition flag set"
        )
        #expect(
            response?.statusCode == 200,
            "Attachment response should still have status code 200"
        )
    }

    @Test("Response with isAttachment false creates successfully")
    func responseWithIsAttachmentFalseCreatesSuccessfully() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "inline.txt", content: Data("inline content".utf8), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path, isAttachment: false)

        #expect(
            response != nil,
            "Should create a response without the attachment disposition"
        )
    }

    @Test("Attachment response with byte range combines both features")
    func attachmentResponseWithByteRangeCombinesBothFeatures() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 500)
        let path = try writeTestFile(named: "partial_download.bin", content: content, inDirectory: dir)

        let range = NSRange(location: 0, length: 200)
        let response = DZWebServerFileResponse(file: path, byteRange: range, isAttachment: true)

        #expect(
            response != nil,
            "Should create a response combining byte range and attachment"
        )
        #expect(
            response?.statusCode == 206,
            "Should have status 206 for byte range even with attachment"
        )
        #expect(
            response?.contentLength == 200,
            "contentLength should reflect the byte range"
        )
    }
}

// MARK: - MIME Type Overrides

@Suite("DZWebServerFileResponse - MIME Type Overrides", .serialized, .tags(.response, .properties))
struct MIMETypeOverrideTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Custom MIME type override replaces the default for a given extension")
    func customMIMETypeOverrideReplacesDefaultForExtension() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "data.txt", content: Data("override test".utf8), inDirectory: dir)
        let overrides = ["txt": "application/custom"]

        // Int(bitPattern: UInt.max) produces the bit pattern for NSUIntegerMax
        // which the Obj-C designated initializer uses as the "full file" sentinel.
        // NSNotFound (Int.max) has a different bit pattern and would be misinterpreted.
        let fullRange = NSRange(location: Int(bitPattern: UInt.max), length: 0)
        let response = DZWebServerFileResponse(
            file: path,
            byteRange: fullRange,
            isAttachment: false,
            mimeTypeOverrides: overrides
        )

        #expect(response != nil, "Should create a response with MIME type overrides")
        #expect(
            response?.contentType == "application/custom",
            "contentType should reflect the override 'application/custom'"
        )
    }

    @Test("Nil overrides dictionary uses default MIME type resolution")
    func nilOverridesDictionaryUsesDefaultMIMETypeResolution() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "page.html", content: Data("<html></html>".utf8), inDirectory: dir)

        // Int(bitPattern: UInt.max) produces the bit pattern for NSUIntegerMax
        // which the Obj-C designated initializer uses as the "full file" sentinel.
        // NSNotFound (Int.max) has a different bit pattern and would be misinterpreted.
        let fullRange = NSRange(location: Int(bitPattern: UInt.max), length: 0)
        let response = DZWebServerFileResponse(
            file: path,
            byteRange: fullRange,
            isAttachment: false,
            mimeTypeOverrides: nil
        )

        #expect(response != nil, "Should create a response with nil overrides")
        #expect(
            response?.contentType == "text/html",
            "contentType should use default MIME resolution for .html files"
        )
    }
}

// MARK: - ETag and LastModifiedDate

@Suite("DZWebServerFileResponse - ETag and LastModifiedDate", .serialized, .tags(.response, .properties))
struct ETagAndLastModifiedDateTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("eTag is a non-empty string for a valid file")
    func eTagIsNonEmptyStringForValidFile() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "etag_test.txt", content: Data("etag".utf8), inDirectory: dir)
        let response = try #require(DZWebServerFileResponse(file: path))

        #expect(
            response.eTag.isEmpty == false,
            "eTag should be a non-empty string"
        )
    }

    @Test("lastModifiedDate is set to a recent date for a freshly created file")
    func lastModifiedDateIsRecentForFreshlyCreatedFile() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let beforeCreation = Date()
        let path = try writeTestFile(named: "recent.txt", content: Data("recent".utf8), inDirectory: dir)
        let response = try #require(DZWebServerFileResponse(file: path))

        // The file was just created, so lastModifiedDate should be close to now
        let timeDifference = response.lastModifiedDate.timeIntervalSince(beforeCreation)
        #expect(
            timeDifference >= -1.0 && timeDifference <= 5.0,
            "lastModifiedDate should be within a few seconds of file creation time"
        )
    }

    @Test("Two responses for the same unmodified file have identical eTags")
    func twoResponsesForSameUnmodifiedFileHaveIdenticalETags() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "stable.txt", content: Data("stable content".utf8), inDirectory: dir)
        let response1 = try #require(DZWebServerFileResponse(file: path))
        let response2 = try #require(DZWebServerFileResponse(file: path))

        #expect(
            response1.eTag == response2.eTag,
            "eTags for the same unmodified file should be identical"
        )
    }

    @Test("eTag changes after modifying the file")
    func eTagChangesAfterModifyingTheFile() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "mutable.txt", content: Data("version 1".utf8), inDirectory: dir)
        let response1 = try #require(DZWebServerFileResponse(file: path))
        let eTag1 = response1.eTag

        // Wait briefly so the modification time changes
        Thread.sleep(forTimeInterval: 1.1)

        // Rewrite the file with different content
        try Data("version 2 with more content".utf8).write(to: URL(fileURLWithPath: path))
        let response2 = try #require(DZWebServerFileResponse(file: path))
        let eTag2 = response2.eTag

        #expect(
            eTag1 != eTag2,
            "eTag should change after the file is modified (eTag1: '\(eTag1)', eTag2: '\(eTag2)')"
        )
    }

    @Test("Two responses for the same file have identical lastModifiedDate values")
    func twoResponsesForSameFileHaveIdenticalLastModifiedDates() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "consistent.txt", content: Data("consistent".utf8), inDirectory: dir)
        let response1 = try #require(DZWebServerFileResponse(file: path))
        let response2 = try #require(DZWebServerFileResponse(file: path))

        #expect(
            response1.lastModifiedDate == response2.lastModifiedDate,
            "lastModifiedDate should be identical for the same unmodified file"
        )
    }
}

// MARK: - Factory Methods

@Suite("DZWebServerFileResponse - Factory Methods", .serialized, .tags(.response, .properties))
struct FactoryMethodTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("responseWithFile creates the same response as initWithFile")
    func responseWithFileCreatesSameResponseAsInitWithFile() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "factory.txt", content: Data("factory test".utf8), inDirectory: dir)
        let factoryResponse = DZWebServerFileResponse(file: path)
        let initResponse = DZWebServerFileResponse(file: path)

        #expect(factoryResponse != nil, "Factory method should create a response")
        #expect(initResponse != nil, "Init method should create a response")
        #expect(factoryResponse?.contentType == initResponse?.contentType)
        #expect(factoryResponse?.contentLength == initResponse?.contentLength)
        #expect(factoryResponse?.statusCode == initResponse?.statusCode)
        #expect(factoryResponse?.eTag == initResponse?.eTag)
    }

    @Test("responseWithFile isAttachment creates the same response as initWithFile isAttachment")
    func responseWithFileIsAttachmentMatchesInitEquivalent() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "attach.txt", content: Data("attachment".utf8), inDirectory: dir)
        let factoryResponse = DZWebServerFileResponse(file: path, isAttachment: true)
        let initResponse = DZWebServerFileResponse(file: path, isAttachment: true)

        #expect(factoryResponse != nil, "Factory method should create an attachment response")
        #expect(initResponse != nil, "Init method should create an attachment response")
        #expect(factoryResponse?.contentType == initResponse?.contentType)
        #expect(factoryResponse?.contentLength == initResponse?.contentLength)
    }

    @Test("responseWithFile byteRange creates the same response as initWithFile byteRange")
    func responseWithFileByteRangeMatchesInitEquivalent() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 500)
        let path = try writeTestFile(named: "ranged_factory.bin", content: content, inDirectory: dir)
        let range = NSRange(location: 10, length: 100)

        let factoryResponse = DZWebServerFileResponse(file: path, byteRange: range)
        let initResponse = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(factoryResponse != nil, "Factory method should create a byte range response")
        #expect(initResponse != nil, "Init method should create a byte range response")
        #expect(factoryResponse?.statusCode == initResponse?.statusCode)
        #expect(factoryResponse?.contentLength == initResponse?.contentLength)
    }

    @Test("responseWithFile byteRange isAttachment creates the same response as the designated initializer")
    func responseWithFileByteRangeIsAttachmentMatchesDesignatedInit() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 300)
        let path = try writeTestFile(named: "combo_factory.bin", content: content, inDirectory: dir)
        let range = NSRange(location: 0, length: 150)

        let factoryResponse = DZWebServerFileResponse(
            file: path,
            byteRange: range,
            isAttachment: true,
            mimeTypeOverrides: nil
        )
        let initResponse = DZWebServerFileResponse(
            file: path,
            byteRange: range,
            isAttachment: true,
            mimeTypeOverrides: nil
        )

        #expect(factoryResponse != nil, "Factory method should create a combined response")
        #expect(initResponse != nil, "Designated initializer should create a combined response")
        #expect(factoryResponse?.statusCode == initResponse?.statusCode)
        #expect(factoryResponse?.contentLength == initResponse?.contentLength)
        #expect(factoryResponse?.contentType == initResponse?.contentType)
    }

    // NOTE: Factory method with non-existent file test omitted.
    // DZWebServerFileResponse triggers DWS_DNOT_REACHED() (abort) in DEBUG
    // when lstat fails on a non-existent path.
}

// MARK: - Edge Cases

@Suite("DZWebServerFileResponse - Edge Cases", .serialized, .tags(.response, .fileIO, .properties))
struct EdgeCaseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Response for a file with unicode characters in the name")
    func responseForFileWithUnicodeCharactersInName() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(
            named: "\u{1F4C4}document\u{00E9}.txt",
            content: Data("unicode name".utf8),
            inDirectory: dir
        )
        let response = DZWebServerFileResponse(file: path)

        #expect(
            response != nil,
            "Should create a response for a file with unicode characters in its name"
        )
        #expect(
            response?.contentLength == 12,
            "contentLength should match the file content size"
        )
    }

    @Test("Response for a file with spaces in the name")
    func responseForFileWithSpacesInName() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(
            named: "my document file.txt",
            content: Data("spaces in name".utf8),
            inDirectory: dir
        )
        let response = DZWebServerFileResponse(file: path)

        #expect(
            response != nil,
            "Should create a response for a file with spaces in its name"
        )
    }

    @Test("Response for an empty file (0 bytes) succeeds with contentLength zero")
    func responseForEmptyFileSucceedsWithContentLengthZero() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "empty.txt", content: Data(), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(
            response != nil,
            "Should create a response for a zero-byte file"
        )
        #expect(
            response?.contentLength == 0,
            "contentLength should be 0 for an empty file"
        )
        #expect(
            response?.statusCode == 200,
            "Status code should be 200 for an empty file served in full"
        )
    }

    @Test("Response for a file with no extension uses application/octet-stream")
    func responseForFileWithNoExtensionUsesOctetStream() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "Makefile", content: Data("all: build".utf8), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(
            response != nil,
            "Should create a response for a file with no extension"
        )
        #expect(
            response?.contentType == "application/octet-stream",
            "contentType should default to 'application/octet-stream' for files without an extension"
        )
    }

    @Test("Response for a file with a very long name")
    func responseForFileWithVeryLongName() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let longName = String(repeating: "a", count: 200) + ".txt"
        let path = try writeTestFile(named: longName, content: Data("long name".utf8), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(
            response != nil,
            "Should create a response for a file with a very long name"
        )
    }

    @Test("Byte range on empty file returns nil because resolved range is zero length")
    func byteRangeOnEmptyFileReturnsNil() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "empty_ranged.bin", content: Data(), inDirectory: dir)
        let range = NSRange(location: 0, length: 100)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(
            response == nil,
            "Should return nil because the byte range resolves to zero bytes on an empty file"
        )
    }

    @Test("Suffix range on empty file returns nil")
    func suffixRangeOnEmptyFileReturnsNil() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "empty_suffix.bin", content: Data(), inDirectory: dir)
        let range = NSRange(location: Int(bitPattern: UInt.max), length: 100)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(
            response == nil,
            "Should return nil because suffix range on an empty file resolves to zero bytes"
        )
    }

    @Test("Response for a single-byte file has contentLength of 1")
    func responseForSingleByteFileHasContentLengthOf1() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "one_byte.bin", content: Data([0x42]), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(response != nil, "Should create a response for a 1-byte file")
        #expect(response?.contentLength == 1, "contentLength should be 1")
    }

    @Test("Byte range requesting exactly the full file via explicit offset and length produces status 206")
    func byteRangeRequestingExactlyFullFileProducesStatus206() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 256)
        let path = try writeTestFile(named: "exact_range.bin", content: content, inDirectory: dir)

        // Request exactly the entire file as a byte range
        let range = NSRange(location: 0, length: 256)
        let response = DZWebServerFileResponse(file: path, byteRange: range)

        #expect(response != nil, "Should create a response for a range covering the full file")
        #expect(
            response?.statusCode == 206,
            "Status code should be 206 even when the range covers the entire file"
        )
        #expect(
            response?.contentLength == 256,
            "contentLength should be the full file size"
        )
    }

    @Test("Response preserves hasBody true even when file is empty")
    func responsePreservesHasBodyTrueEvenWhenFileIsEmpty() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let path = try writeTestFile(named: "empty_body.dat", content: Data(), inDirectory: dir)
        let response = DZWebServerFileResponse(file: path)

        #expect(response != nil, "Should create a response for an empty file")
        #expect(
            response?.hasBody() == true,
            "hasBody should return true because contentType is set even for empty files"
        )
    }
}

// MARK: - Body Reader Protocol

@Suite("DZWebServerFileResponse - Body Reader", .serialized, .tags(.response, .fileIO))
struct BodyReaderTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Open, readData, and close lifecycle completes without error for a valid file")
    func openReadCloseLifecycleCompletesWithoutError() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        let content = makeTestData(byteCount: 128)
        let path = try writeTestFile(named: "readable.bin", content: content, inDirectory: dir)
        let response = try #require(DZWebServerFileResponse(file: path))

        // Open
        try response.open()

        // Read all data
        var allData = Data()
        while true {
            let chunk = try response.readData()
            if chunk.isEmpty {
                break
            }
            allData.append(chunk)
        }

        // Close
        response.close()

        #expect(
            allData.count == 128,
            "Total data read should equal the file size"
        )
        #expect(
            allData == content,
            "Data read should match the original file content"
        )
    }

    @Test("Reading a byte range returns only the requested portion of the file")
    func readingByteRangeReturnsOnlyRequestedPortion() throws {
        let dir = try makeTestDirectory()
        defer { removeTestDirectory(dir) }

        // Create a file with known sequential content
        let content = makeTestData(byteCount: 1000)
        let path = try writeTestFile(named: "range_read.bin", content: content, inDirectory: dir)

        // Request bytes 100-199 (100 bytes)
        let range = NSRange(location: 100, length: 100)
        let response = try #require(DZWebServerFileResponse(file: path, byteRange: range))

        try response.open()

        var allData = Data()
        while true {
            let chunk = try response.readData()
            if chunk.isEmpty {
                break
            }
            allData.append(chunk)
        }

        response.close()

        let expectedSlice = content[100..<200]
        #expect(
            allData.count == 100,
            "Should read exactly 100 bytes for the specified range"
        )
        #expect(
            allData == Data(expectedSlice),
            "Data read should match the expected byte range of the original content"
        )
    }
}
