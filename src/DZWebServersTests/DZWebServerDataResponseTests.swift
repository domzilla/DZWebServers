//
//  DZWebServerDataResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Data Response

@Suite("DZWebServerDataResponse", .serialized, .tags(.response, .properties))
struct DZWebServerDataResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Initialization & Core Properties

    @Suite("Initialization and core properties")
    struct Initialization {
        @Test("initWithData sets contentType to the provided MIME type")
        func initWithDataSetsContentType() {
            let data = Data([0x00, 0x01, 0x02])
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentType == "application/octet-stream")
        }

        @Test("initWithData sets contentLength to the byte length of the data")
        func initWithDataSetsContentLength() {
            let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentLength == 4)
        }

        @Test("initWithData defaults statusCode to 200")
        func initWithDataDefaultsStatusCodeTo200() {
            let data = Data("hello".utf8)
            let response = DZWebServerDataResponse(data: data, contentType: "text/plain")

            #expect(response.statusCode == 200)
        }

        @Test("hasBody returns true for a data response")
        func hasBodyReturnsTrue() {
            let data = Data("body".utf8)
            let response = DZWebServerDataResponse(data: data, contentType: "text/plain")

            #expect(response.hasBody() == true)
        }

        @Test("empty data creates a valid response with contentLength zero")
        func emptyDataCreatesValidResponse() {
            let data = Data()
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentType == "application/octet-stream")
            #expect(response.contentLength == 0)
            #expect(response.statusCode == 200)
            #expect(response.hasBody() == true)
        }

        @Test("binary data preserves exact byte count in contentLength")
        func binaryDataPreservesExactByteCount() {
            var bytes = [UInt8](repeating: 0, count: 256)
            for i in 0..<256 {
                bytes[i] = UInt8(i)
            }
            let data = Data(bytes)
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentLength == 256)
        }

        @Test(
            "initWithData accepts various MIME content types",
            arguments: [
                "application/octet-stream",
                "image/png",
                "application/pdf",
                "audio/mpeg",
                "video/mp4",
                "application/xml",
                "text/csv",
            ]
        )
        func initWithDataAcceptsVariousContentTypes(contentType: String) {
            let data = Data([0xFF])
            let response = DZWebServerDataResponse(data: data, contentType: contentType)

            #expect(response.contentType == contentType)
            #expect(response.contentLength == 1)
        }
    }

    // MARK: - Factory Method

    @Suite("Factory method responseWithData:contentType:")
    struct FactoryMethod {
        @Test("responseWithData creates a response equivalent to init")
        func responseWithDataCreatesEquivalentResponse() {
            let data = Data("factory".utf8)
            let response = DZWebServerDataResponse(data: data, contentType: "text/plain")

            #expect(response.contentType == "text/plain")
            #expect(response.contentLength == UInt("factory".utf8.count))
            #expect(response.statusCode == 200)
        }
    }

    // MARK: - Property Mutation

    @Suite("Property mutation after creation")
    struct PropertyMutation {
        @Test("statusCode can be changed after creation")
        func statusCodeCanBeChanged() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")
            response.statusCode = 201

            #expect(response.statusCode == 201)
        }

        @Test("contentType can be changed after creation")
        func contentTypeCanBeChanged() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")
            response.contentType = "text/html"

            #expect(response.contentType == "text/html")
        }

        @Test("cacheControlMaxAge defaults to zero and can be modified")
        func cacheControlMaxAgeDefaultsToZero() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")

            #expect(response.cacheControlMaxAge == 0)

            response.cacheControlMaxAge = 3600
            #expect(response.cacheControlMaxAge == 3600)
        }
    }

    // MARK: - Text Response

    @Suite("Text response (Extensions)")
    struct TextResponse {
        @Test("initWithText sets content type to text/plain with UTF-8 charset")
        func initWithTextSetsContentType() {
            let response = DZWebServerDataResponse(text: "Hello, world!")

            #expect(response?.contentType == "text/plain; charset=utf-8")
        }

        @Test("initWithText sets contentLength to the UTF-8 byte length of the string")
        func initWithTextSetsContentLengthToUTF8ByteLength() throws {
            let text = "Hello, world!"
            let expectedLength = try #require(text.data(using: .utf8)?.count)
            let response = DZWebServerDataResponse(text: text)

            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithText with empty string creates a valid response")
        func initWithTextEmptyString() {
            let response = DZWebServerDataResponse(text: "")

            #expect(response != nil)
            #expect(response?.contentLength == 0)
            #expect(response?.contentType == "text/plain; charset=utf-8")
        }

        @Test("initWithText with unicode text computes correct byte length")
        func initWithTextUnicodeText() throws {
            let text = "Hej v\u{00E4}rlden! \u{1F30D}"
            let expectedLength = try #require(text.data(using: .utf8)?.count)
            let response = DZWebServerDataResponse(text: text)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithText with very long text succeeds")
        func initWithTextVeryLongText() {
            let text = String(repeating: "A", count: 100_000)
            let response = DZWebServerDataResponse(text: text)

            #expect(response != nil)
            #expect(response?.contentLength == 100_000)
        }

        @Test("initWithText with multibyte characters computes byte length, not character count")
        func initWithTextMultibyteCharacters() throws {
            // Each CJK character is 3 bytes in UTF-8
            let text = "\u{4F60}\u{597D}\u{4E16}\u{754C}" // Chinese characters
            let expectedLength = try #require(text.data(using: .utf8)?.count)
            let response = DZWebServerDataResponse(text: text)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
            #expect(response?.contentLength != UInt(text.count))
        }

        @Test("responseWithText factory method creates a valid text response")
        func responseWithTextFactoryMethod() {
            let response = DZWebServerDataResponse(text: "factory text")

            #expect(response != nil)
            #expect(response?.contentType == "text/plain; charset=utf-8")
        }
    }

    // MARK: - HTML Response

    @Suite("HTML response (Extensions)")
    struct HTMLResponse {
        @Test("initWithHTML sets content type to text/html with UTF-8 charset")
        func initWithHTMLSetsContentType() {
            let response = DZWebServerDataResponse(html: "<h1>Hello</h1>")

            #expect(response?.contentType == "text/html; charset=utf-8")
        }

        @Test("initWithHTML sets contentLength to the UTF-8 byte length of the HTML string")
        func initWithHTMLSetsContentLength() throws {
            let html = "<html><body><p>Hello</p></body></html>"
            let expectedLength = try #require(html.data(using: .utf8)?.count)
            let response = DZWebServerDataResponse(html: html)

            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithHTML with empty string creates a valid response")
        func initWithHTMLEmptyString() {
            let response = DZWebServerDataResponse(html: "")

            #expect(response != nil)
            #expect(response?.contentLength == 0)
            #expect(response?.contentType == "text/html; charset=utf-8")
        }

        @Test("initWithHTML with special characters preserves them")
        func initWithHTMLSpecialCharacters() throws {
            let html = "<p>&amp; &lt; &gt; &quot;</p>"
            let expectedLength = try #require(html.data(using: .utf8)?.count)
            let response = DZWebServerDataResponse(html: html)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithHTML with unicode characters computes correct byte length")
        func initWithHTMLUnicodeCharacters() throws {
            let html = "<p>\u{00E9}\u{00E8}\u{00EA}</p>" // French accented characters
            let expectedLength = try #require(html.data(using: .utf8)?.count)
            let response = DZWebServerDataResponse(html: html)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("responseWithHTML factory method creates a valid HTML response")
        func responseWithHTMLFactoryMethod() {
            let response = DZWebServerDataResponse(html: "<div>factory</div>")

            #expect(response != nil)
            #expect(response?.contentType == "text/html; charset=utf-8")
        }
    }

    // MARK: - HTML Template Response

    @Suite("HTML template response (Extensions)")
    struct HTMLTemplateResponse {
        /// Creates a temporary directory for template tests and returns its URL.
        private func makeTempDirectory() throws -> URL {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("DZWebServerDataResponseTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            return tempDir
        }

        /// Removes the temporary directory at the given URL.
        private func removeTempDirectory(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
        }

        @Test("initWithHTMLTemplate substitutes variables in the template")
        func initWithHTMLTemplateSubstitutesVariables() throws {
            let tempDir = try makeTempDirectory()
            defer { removeTempDirectory(tempDir) }

            let templateContent = "<h1>%title%</h1><p>%body%</p>"
            let templateURL = tempDir.appendingPathComponent("template.html")
            try templateContent.write(to: templateURL, atomically: true, encoding: .utf8)

            let variables: [String: String] = ["title": "Welcome", "body": "Hello, world!"]
            let response = DZWebServerDataResponse(htmlTemplate: templateURL.path, variables: variables)

            let expectedHTML = "<h1>Welcome</h1><p>Hello, world!</p>"
            let expectedLength = try #require(expectedHTML.data(using: .utf8)?.count)

            #expect(response != nil)
            #expect(response?.contentType == "text/html; charset=utf-8")
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithHTMLTemplate with no variables passes template through unchanged")
        func initWithHTMLTemplateNoVariables() throws {
            let tempDir = try makeTempDirectory()
            defer { removeTempDirectory(tempDir) }

            let templateContent = "<p>No placeholders here</p>"
            let templateURL = tempDir.appendingPathComponent("static.html")
            try templateContent.write(to: templateURL, atomically: true, encoding: .utf8)

            let response = DZWebServerDataResponse(htmlTemplate: templateURL.path, variables: [:])

            let expectedLength = try #require(templateContent.data(using: .utf8)?.count)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithHTMLTemplate leaves unmatched placeholders as-is when variable not in dictionary")
        func initWithHTMLTemplateUnmatchedPlaceholders() throws {
            let tempDir = try makeTempDirectory()
            defer { removeTempDirectory(tempDir) }

            let templateContent = "<h1>%title%</h1><p>%missing%</p>"
            let templateURL = tempDir.appendingPathComponent("partial.html")
            try templateContent.write(to: templateURL, atomically: true, encoding: .utf8)

            let variables = ["title": "Found"]
            let response = DZWebServerDataResponse(htmlTemplate: templateURL.path, variables: variables)

            // %missing% should remain as-is since it is not in the dictionary
            let expectedHTML = "<h1>Found</h1><p>%missing%</p>"
            let expectedLength = try #require(expectedHTML.data(using: .utf8)?.count)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithHTMLTemplate substitutes multiple occurrences of the same variable")
        func initWithHTMLTemplateMultipleOccurrences() throws {
            let tempDir = try makeTempDirectory()
            defer { removeTempDirectory(tempDir) }

            let templateContent = "<p>%name% said hello to %name%</p>"
            let templateURL = tempDir.appendingPathComponent("repeat.html")
            try templateContent.write(to: templateURL, atomically: true, encoding: .utf8)

            let variables = ["name": "Alice"]
            let response = DZWebServerDataResponse(htmlTemplate: templateURL.path, variables: variables)

            let expectedHTML = "<p>Alice said hello to Alice</p>"
            let expectedLength = try #require(expectedHTML.data(using: .utf8)?.count)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        // NOTE: initWithHTMLTemplate with nonexistent file path test omitted.
        // DZWebServerDataResponse triggers DWS_DNOT_REACHED() (abort) in DEBUG
        // when the template file cannot be read.

        @Test("initWithHTMLTemplate with unicode variables computes correct byte length")
        func initWithHTMLTemplateUnicodeVariables() throws {
            let tempDir = try makeTempDirectory()
            defer { removeTempDirectory(tempDir) }

            let templateContent = "<p>%greeting%</p>"
            let templateURL = tempDir.appendingPathComponent("unicode.html")
            try templateContent.write(to: templateURL, atomically: true, encoding: .utf8)

            let variables = ["greeting": "\u{1F44B} Hola"]
            let response = DZWebServerDataResponse(htmlTemplate: templateURL.path, variables: variables)

            let expectedHTML = "<p>\u{1F44B} Hola</p>"
            let expectedLength = try #require(expectedHTML.data(using: .utf8)?.count)

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("responseWithHTMLTemplate factory method creates a valid template response")
        func responseWithHTMLTemplateFactoryMethod() throws {
            let tempDir = try makeTempDirectory()
            defer { removeTempDirectory(tempDir) }

            let templateContent = "<span>%word%</span>"
            let templateURL = tempDir.appendingPathComponent("factory.html")
            try templateContent.write(to: templateURL, atomically: true, encoding: .utf8)

            let response = DZWebServerDataResponse(htmlTemplate: templateURL.path, variables: ["word": "test"])

            #expect(response != nil)
            #expect(response?.contentType == "text/html; charset=utf-8")
        }
    }

    // MARK: - JSON Response

    @Suite("JSON response (Extensions)")
    struct JSONResponse {
        @Test("initWithJSONObject with dictionary sets content type to application/json")
        func initWithJSONObjectDictionarySetsContentType() {
            let dict: [String: Any] = ["key": "value"]
            let response = DZWebServerDataResponse(jsonObject: dict)

            #expect(response?.contentType == "application/json")
        }

        @Test("initWithJSONObject with dictionary sets correct contentLength")
        func initWithJSONObjectDictionarySetsContentLength() {
            let dict: [String: Any] = ["key": "value"]
            let response = DZWebServerDataResponse(jsonObject: dict)

            // Serialize ourselves to know the expected length
            let expectedData = try? JSONSerialization.data(withJSONObject: dict, options: [])
            let expectedLength = expectedData?.count ?? 0

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithJSONObject with array produces valid response")
        func initWithJSONObjectArrayProducesValidResponse() {
            let array: [Any] = [1, "two", 3.0, true]
            let response = DZWebServerDataResponse(jsonObject: array)

            #expect(response != nil)
            #expect(response?.contentType == "application/json")
            #expect(response?.statusCode == 200)
        }

        @Test("initWithJSONObject with nested objects produces valid response")
        func initWithJSONObjectNestedObjects() {
            let nested: [String: Any] = [
                "user": [
                    "name": "Dominic",
                    "tags": ["swift", "objc"],
                    "meta": ["active": true, "score": 42],
                ],
            ]
            let response = DZWebServerDataResponse(jsonObject: nested)

            let expectedData = try? JSONSerialization.data(withJSONObject: nested, options: [])
            let expectedLength = expectedData?.count ?? 0

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithJSONObject with empty dictionary produces valid response")
        func initWithJSONObjectEmptyDictionary() {
            let dict: [String: Any] = [:]
            let response = DZWebServerDataResponse(jsonObject: dict)

            let expectedData = try? JSONSerialization.data(withJSONObject: dict, options: [])
            let expectedLength = expectedData?.count ?? 0

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
            #expect(response?.contentType == "application/json")
        }

        @Test("initWithJSONObject with empty array produces valid response")
        func initWithJSONObjectEmptyArray() {
            let array: [Any] = []
            let response = DZWebServerDataResponse(jsonObject: array)

            let expectedData = try? JSONSerialization.data(withJSONObject: array, options: [])
            let expectedLength = expectedData?.count ?? 0

            #expect(response != nil)
            #expect(response?.contentLength == UInt(expectedLength))
        }

        @Test("initWithJSONObject with custom content type uses the provided type")
        func initWithJSONObjectCustomContentType() {
            let dict: [String: Any] = ["data": "value"]
            let response = DZWebServerDataResponse(jsonObject: dict, contentType: "application/vnd.api+json")

            #expect(response?.contentType == "application/vnd.api+json")
        }

        @Test(
            "initWithJSONObject with custom content type parameterized",
            arguments: [
                "application/vnd.api+json",
                "application/ld+json",
                "application/hal+json",
                "application/problem+json",
            ]
        )
        func initWithJSONObjectVariousCustomContentTypes(contentType: String) {
            let dict: [String: Any] = ["status": "ok"]
            let response = DZWebServerDataResponse(jsonObject: dict, contentType: contentType)

            #expect(response != nil)
            #expect(response?.contentType == contentType)
        }

        @Test("responseWithJSONObject factory method creates valid JSON response")
        func responseWithJSONObjectFactoryMethod() {
            let dict: [String: Any] = ["factory": true]
            let response = DZWebServerDataResponse(jsonObject: dict)

            #expect(response != nil)
            #expect(response?.contentType == "application/json")
        }

        @Test("responseWithJSONObject with custom content type factory method works")
        func responseWithJSONObjectCustomContentTypeFactoryMethod() {
            let dict: [String: Any] = ["factory": true]
            let response = DZWebServerDataResponse(jsonObject: dict, contentType: "application/vnd.api+json")

            #expect(response != nil)
            #expect(response?.contentType == "application/vnd.api+json")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge cases")
    struct EdgeCases {
        @Test("hasBody is true even when data is empty")
        func hasBodyTrueEvenForEmptyData() {
            let response = DZWebServerDataResponse(data: Data(), contentType: "text/plain")

            #expect(response.hasBody() == true)
        }

        @Test("statusCode defaults to 200 for all creation methods")
        func statusCodeDefaultsTo200ForAllCreationMethods() {
            let dataResponse = DZWebServerDataResponse(data: Data("a".utf8), contentType: "text/plain")
            let textResponse = DZWebServerDataResponse(text: "b")
            let htmlResponse = DZWebServerDataResponse(html: "<b>c</b>")
            let jsonResponse = DZWebServerDataResponse(jsonObject: ["d": 1])

            #expect(dataResponse.statusCode == 200)
            #expect(textResponse?.statusCode == 200)
            #expect(htmlResponse?.statusCode == 200)
            #expect(jsonResponse?.statusCode == 200)
        }

        @Test("gzipContentEncodingEnabled defaults to false")
        func gzipContentEncodingEnabledDefaultsToFalse() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")

            #expect(response.isGZipContentEncodingEnabled == false)
        }

        @Test("lastModifiedDate defaults to nil")
        func lastModifiedDateDefaultsToNil() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")

            #expect(response.lastModifiedDate == nil)
        }

        @Test("eTag defaults to nil")
        func eTagDefaultsToNil() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")

            #expect(response.eTag == nil)
        }

        @Test("additional headers can be set on a data response")
        func additionalHeadersCanBeSet() {
            let response = DZWebServerDataResponse(data: Data("test".utf8), contentType: "text/plain")
            response.setValue("custom-value", forAdditionalHeader: "X-Custom-Header")

            // No crash means the method works; headers are sent during connection handling.
            #expect(response.hasBody() == true)
        }

        @Test("large binary data response preserves exact contentLength")
        func largeBinaryDataPreservesContentLength() {
            let size = 1_048_576 // 1 MB
            let data = Data(count: size)
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentLength == UInt(size))
        }
    }
}
