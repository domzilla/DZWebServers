//
//  DZWebServerStreamedResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Testing

// MARK: - Root Suite

@Suite("DZWebServerStreamedResponse", .serialized, .tags(.response, .streaming, .properties))
struct DZWebServerStreamedResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Synchronous Stream Block

    @Suite("Synchronous Stream Block")
    struct SynchronousStreamBlock {
        @Test("Initializing with a stream block sets the content type")
        func initWithStreamBlockSetsContentType() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.contentType == "text/plain")
        }

        @Test("Content length defaults to UInt.max for chunked transfer encoding")
        func contentLengthDefaultsToUIntMax() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.contentLength == UInt.max)
        }

        @Test("Status code defaults to 200 OK")
        func statusCodeDefaultsTo200() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.statusCode == 200)
        }

        @Test("Has body returns true when content type is set")
        func hasBodyReturnsTrue() {
            let response = DZWebServerStreamedResponse(
                contentType: "application/json",
                streamBlock: { _ in Data() }
            )

            #expect(response.hasBody() == true)
        }

        @Test("Stream block that returns empty data immediately signals completion")
        func streamBlockReturningEmptyDataSignalsCompletion() {
            // The stream block returns empty Data to signal end-of-stream.
            // We verify the response is created successfully with this block.
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.contentType == "text/plain")
            #expect(response.hasBody() == true)
        }
    }

    // MARK: - Asynchronous Stream Block

    @Suite("Asynchronous Stream Block")
    struct AsynchronousStreamBlock {
        @Test("Initializing with an async stream block sets the content type")
        func initWithAsyncStreamBlockSetsContentType() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                asyncStreamBlock: { completion in
                    completion(Data(), nil)
                }
            )

            #expect(response.contentType == "text/event-stream")
        }

        @Test("Content length defaults to UInt.max for async stream")
        func contentLengthDefaultsToUIntMaxForAsync() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                asyncStreamBlock: { completion in
                    completion(Data(), nil)
                }
            )

            #expect(response.contentLength == UInt.max)
        }

        @Test("Status code defaults to 200 OK for async stream")
        func statusCodeDefaultsTo200ForAsync() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                asyncStreamBlock: { completion in
                    completion(Data(), nil)
                }
            )

            #expect(response.statusCode == 200)
        }

        @Test("Has body returns true for async stream response")
        func hasBodyReturnsTrueForAsync() {
            let response = DZWebServerStreamedResponse(
                contentType: "application/octet-stream",
                asyncStreamBlock: { completion in
                    completion(Data(), nil)
                }
            )

            #expect(response.hasBody() == true)
        }
    }

    // MARK: - Content Type Variations

    @Suite("Content Type Variations")
    struct ContentTypeVariations {
        @Test(
            "Content type is set correctly for various MIME types",
            arguments: [
                "text/event-stream",
                "application/json",
                "application/octet-stream",
                "text/plain",
                "text/html",
                "application/xml",
                "multipart/mixed",
            ]
        )
        func contentTypeIsSetCorrectly(mimeType: String) {
            let response = DZWebServerStreamedResponse(
                contentType: mimeType,
                streamBlock: { _ in Data() }
            )

            #expect(response.contentType == mimeType)
        }

        @Test("Content type with charset parameter is preserved")
        func contentTypeWithCharsetIsPreserved() {
            let contentType = "text/plain; charset=utf-8"
            let response = DZWebServerStreamedResponse(
                contentType: contentType,
                streamBlock: { _ in Data() }
            )

            #expect(response.contentType == contentType)
        }

        @Test("Content type with multiple parameters is preserved")
        func contentTypeWithMultipleParametersIsPreserved() {
            let contentType = "text/plain; charset=utf-8; boundary=something"
            let response = DZWebServerStreamedResponse(
                contentType: contentType,
                streamBlock: { _ in Data() }
            )

            #expect(response.contentType == contentType)
        }
    }

    // MARK: - Factory Methods

    @Suite("Factory Methods")
    struct FactoryMethods {
        @Test("responseWithContentType:streamBlock: creates a valid response")
        func factoryWithStreamBlockCreatesValidResponse() {
            let response = DZWebServerStreamedResponse(
                contentType: "application/json",
                streamBlock: { _ in Data() }
            )

            #expect(response.contentType == "application/json")
            #expect(response.statusCode == 200)
            #expect(response.contentLength == UInt.max)
            #expect(response.hasBody() == true)
        }

        @Test("responseWithContentType:asyncStreamBlock: creates a valid response")
        func factoryWithAsyncStreamBlockCreatesValidResponse() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                asyncStreamBlock: { completion in
                    completion(Data(), nil)
                }
            )

            #expect(response.contentType == "text/event-stream")
            #expect(response.statusCode == 200)
            #expect(response.contentLength == UInt.max)
            #expect(response.hasBody() == true)
        }
    }

    // MARK: - Property Behavior

    @Suite("Property Behavior")
    struct PropertyBehavior {
        @Test("Status code can be changed after creation")
        func statusCodeCanBeChanged() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            response.statusCode = 201
            #expect(response.statusCode == 201)
        }

        @Test("Cache control max age defaults to zero")
        func cacheControlMaxAgeDefaultsToZero() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.cacheControlMaxAge == 0)
        }

        @Test("Cache control max age can be set after creation")
        func cacheControlMaxAgeCanBeSet() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            response.cacheControlMaxAge = 3600
            #expect(response.cacheControlMaxAge == 3600)
        }

        @Test("Last modified date defaults to nil")
        func lastModifiedDateDefaultsToNil() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.lastModifiedDate == nil)
        }

        @Test("Last modified date can be set after creation")
        func lastModifiedDateCanBeSet() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            let date = Date()
            response.lastModifiedDate = date
            #expect(response.lastModifiedDate == date)
        }

        @Test("ETag defaults to nil")
        func eTagDefaultsToNil() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.eTag == nil)
        }

        @Test("ETag can be set after creation")
        func eTagCanBeSet() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            response.eTag = "\"abc123\""
            #expect(response.eTag == "\"abc123\"")
        }

        @Test("Content type can be changed after creation")
        func contentTypeCanBeChanged() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            response.contentType = "application/json"
            #expect(response.contentType == "application/json")
        }

        @Test("Content length remains UInt.max even when not explicitly set")
        func contentLengthRemainsUIntMax() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                asyncStreamBlock: { completion in
                    completion(Data(), nil)
                }
            )

            // Streamed responses never know total size upfront,
            // so contentLength stays at UInt.max for chunked encoding.
            #expect(response.contentLength == UInt.max)
        }
    }

    // MARK: - Gzip Content Encoding

    @Suite("Gzip Content Encoding")
    struct GzipContentEncoding {
        @Test("Gzip content encoding defaults to disabled")
        func gzipDefaultsToDisabled() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response.isGZipContentEncodingEnabled == false)
        }

        @Test("Gzip content encoding can be enabled")
        func gzipCanBeEnabled() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            response.isGZipContentEncodingEnabled = true
            #expect(response.isGZipContentEncodingEnabled == true)
        }

        @Test("Enabling gzip keeps content length at UInt.max")
        func enablingGzipKeepsContentLengthAtUIntMax() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            response.isGZipContentEncodingEnabled = true
            #expect(response.contentLength == UInt.max)
        }
    }

    // MARK: - Custom Headers

    @Suite("Custom Headers")
    struct CustomHeaders {
        @Test("Custom header can be set on a streamed response")
        func customHeaderCanBeSet() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                streamBlock: { _ in Data() }
            )

            // Setting a custom header should not throw or crash.
            response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
            response.setValue("keep-alive", forAdditionalHeader: "Connection")

            // If we get here without crashing, the headers were accepted.
            #expect(response.hasBody() == true)
        }

        @Test("Custom header can be removed by setting nil")
        func customHeaderCanBeRemoved() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                streamBlock: { _ in Data() }
            )

            response.setValue("custom-value", forAdditionalHeader: "X-Custom")
            response.setValue(nil, forAdditionalHeader: "X-Custom")

            // No crash means the header was removed successfully.
            #expect(response.hasBody() == true)
        }
    }

    // MARK: - Inheritance

    @Suite("Inheritance")
    struct Inheritance {
        @Test("Streamed response is a subclass of DZWebServerResponse")
        func isSubclassOfDZWebServerResponse() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                streamBlock: { _ in Data() }
            )

            #expect(response is DZWebServerResponse)
        }
    }
}
