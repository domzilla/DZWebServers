//
//  DZWebServerRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Helpers

/// Thread-safe box for capturing request properties from handler blocks.
private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: DZWebServerRequest?

    var value: DZWebServerRequest? {
        get { self.lock.lock()
            defer { self.lock.unlock() }
            return self._value
        }
        set { self.lock.lock()
            defer { self.lock.unlock() }
            self._value = newValue
        }
    }
}

/// Creates a minimal `DZWebServerRequest` with the given method, path, query, and headers.
private func makeRequest(
    method: String = "GET",
    urlString: String = "http://localhost/test",
    headers: [String: String] = [:],
    path: String = "/test",
    query: [String: String]? = nil
)
    -> DZWebServerRequest?
{
    guard let url = URL(string: urlString) else { return nil }
    return DZWebServerRequest(
        method: method,
        url: url,
        headers: headers,
        path: path,
        query: query
    )
}

// MARK: - Root Suite

@Suite("DZWebServerRequest", .serialized, .tags(.request))
struct DZWebServerRequestTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Initialization

    @Suite("Initialization")
    struct Initialization {
        @Test("Designated initializer creates a non-nil request with valid inputs")
        func designatedInitializerCreatesNonNilRequest() throws {
            let url = try #require(URL(string: "http://localhost/test?key=value"))
            let headers = ["Accept": "text/html"]
            let query = ["key": "value"]

            let request = DZWebServerRequest(
                method: "GET",
                url: url,
                headers: headers,
                path: "/test",
                query: query
            )

            #expect(request != nil)
        }

        @Test("Initializer with empty headers and nil query creates a valid request")
        func initializerWithEmptyHeadersAndNilQuery() {
            let request = makeRequest(headers: [:], query: nil)

            #expect(request != nil)
        }

        // NOTE: Tests for Content-Length + chunked and negative Content-Length
        // are omitted because the ObjC implementation calls DWS_DNOT_REACHED()
        // (abort() in DEBUG), which cannot be caught in Swift.
    }

    // MARK: - Basic Properties

    @Suite("Basic Properties", .serialized, .tags(.properties))
    struct BasicProperties {
        @Test(
            "Method property matches the method passed to initializer",
            arguments: ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
        )
        func methodPropertyMatchesInitArgument(method: String) {
            let request = makeRequest(method: method)

            #expect(request?.method == method)
        }

        @Test("URL property matches the URL passed to initializer")
        func urlPropertyMatchesInitArgument() throws {
            let url = try #require(URL(string: "http://localhost:8080/api/v1/resource?id=42"))
            let request = DZWebServerRequest(
                method: "GET",
                url: url,
                headers: [:],
                path: "/api/v1/resource",
                query: ["id": "42"]
            )

            #expect(request.url == url)
        }

        @Test("Headers property matches the headers passed to initializer")
        func headersPropertyMatchesInitArgument() {
            let headers = ["Accept": "application/json", "X-Custom": "value"]
            let request = makeRequest(headers: headers)

            #expect(request?.headers["Accept"] == "application/json")
            #expect(request?.headers["X-Custom"] == "value")
        }

        @Test("Path property matches the path passed to initializer")
        func pathPropertyMatchesInitArgument() {
            let request = makeRequest(path: "/api/users/123")

            #expect(request?.path == "/api/users/123")
        }

        @Test("Query property matches the query dictionary passed to initializer")
        func queryPropertyMatchesInitArgument() {
            let query = ["search": "hello", "page": "2"]
            let request = makeRequest(
                urlString: "http://localhost/test?search=hello&page=2",
                query: query
            )

            #expect(request?.query?["search"] == "hello")
            #expect(request?.query?["page"] == "2")
        }

        @Test("Query property is nil when no query parameters are provided")
        func queryIsNilWhenNotProvided() {
            let request = makeRequest(query: nil)

            #expect(request?.query == nil)
        }

        @Test("Empty method string is accepted")
        func emptyMethodStringIsAccepted() {
            let request = makeRequest(method: "")

            #expect(request != nil)
            #expect(request?.method == "")
        }

        @Test("Empty path string is accepted")
        func emptyPathStringIsAccepted() {
            let request = makeRequest(path: "")

            #expect(request != nil)
            #expect(request?.path == "")
        }

        @Test("Query with Unicode keys and values is preserved")
        func queryWithUnicodeIsPreserved() {
            let query = ["\u{00E9}t\u{00E9}": "caf\u{00E9}", "\u{65E5}\u{672C}": "\u{6771}\u{4EAC}"]
            let request = makeRequest(query: query)

            #expect(request?.query?["\u{00E9}t\u{00E9}"] == "caf\u{00E9}")
            #expect(request?.query?["\u{65E5}\u{672C}"] == "\u{6771}\u{4EAC}")
        }

        @Test("Request with very long URL is accepted")
        func requestWithVeryLongURLIsAccepted() throws {
            let longPath = "/" + String(repeating: "a", count: 8000)
            let url = try #require(URL(string: "http://localhost\(longPath)"))
            let request = DZWebServerRequest(
                method: "GET",
                url: url,
                headers: [:],
                path: longPath,
                query: nil
            )

            #expect(request.path == longPath)
        }
    }

    // MARK: - Content Type and Content Length

    @Suite("Content Type and Content Length")
    struct ContentTypeAndLength {
        @Test("No Content-Type and no Content-Length results in nil contentType")
        func noContentHeadersMeansNilContentType() {
            let request = makeRequest(headers: [:])

            #expect(request?.contentType == nil)
        }

        @Test("No Content-Type and no Content-Length results in contentLength equal to UInt.max")
        func noContentHeadersMeansMaxContentLength() {
            let request = makeRequest(headers: [:])

            #expect(request?.contentLength == UInt.max)
        }

        @Test("Content-Type header alone (without body indicator) results in nil contentType")
        func contentTypeAloneIsIgnored() {
            let request = makeRequest(
                headers: ["Content-Type": "text/plain"]
            )

            // Content-Type without Content-Length or chunked is ignored
            #expect(request?.contentType == nil)
        }

        @Test("Content-Type with Content-Length sets both properties correctly")
        func contentTypeWithContentLengthSetsProperties() {
            let request = makeRequest(
                headers: [
                    "Content-Type": "application/json",
                    "Content-Length": "256",
                ]
            )

            #expect(request?.contentType == "application/json")
            #expect(request?.contentLength == 256)
        }

        @Test("Content-Length present without Content-Type defaults contentType to application/octet-stream")
        func contentLengthWithoutContentTypeDefaultsToOctetStream() {
            let request = makeRequest(
                headers: ["Content-Length": "100"]
            )

            #expect(request?.contentType == "application/octet-stream")
            #expect(request?.contentLength == 100)
        }

        @Test("Content-Length of zero is valid and sets hasBody to true")
        func zeroContentLengthIsValid() {
            let request = makeRequest(
                headers: ["Content-Length": "0"]
            )

            #expect(request?.contentLength == 0)
            #expect(request?.hasBody() == true)
        }

        @Test("Chunked Transfer-Encoding without Content-Type defaults contentType to application/octet-stream")
        func chunkedWithoutContentTypeDefaultsToOctetStream() {
            let request = makeRequest(
                headers: ["Transfer-Encoding": "chunked"]
            )

            #expect(request?.contentType == "application/octet-stream")
        }

        @Test("Chunked Transfer-Encoding sets contentLength to UInt.max")
        func chunkedTransferEncodingSetsMaxContentLength() {
            let request = makeRequest(
                headers: [
                    "Content-Type": "text/plain",
                    "Transfer-Encoding": "chunked",
                ]
            )

            #expect(request?.contentLength == UInt.max)
        }

        @Test("Chunked Transfer-Encoding with Content-Type preserves the Content-Type")
        func chunkedWithContentTypePreservesContentType() {
            let request = makeRequest(
                headers: [
                    "Content-Type": "text/plain",
                    "Transfer-Encoding": "chunked",
                ]
            )

            #expect(request?.contentType == "text/plain")
        }
    }

    // MARK: - hasBody

    @Suite("hasBody")
    struct HasBody {
        @Test("Returns false when there are no body indicators")
        func returnsFalseWhenNoBodyIndicators() {
            let request = makeRequest(headers: [:])

            #expect(request?.hasBody() == false)
        }

        @Test("Returns true when Content-Length is present")
        func returnsTrueWhenContentLengthPresent() {
            let request = makeRequest(
                headers: ["Content-Length": "42"]
            )

            #expect(request?.hasBody() == true)
        }

        @Test("Returns true when Transfer-Encoding chunked is present")
        func returnsTrueWhenChunkedPresent() {
            let request = makeRequest(
                headers: ["Transfer-Encoding": "chunked"]
            )

            #expect(request?.hasBody() == true)
        }

        @Test("Returns false when only Content-Type is provided without body indicators")
        func returnsFalseWithOnlyContentType() {
            let request = makeRequest(
                headers: ["Content-Type": "text/plain"]
            )

            #expect(request?.hasBody() == false)
        }
    }

    // MARK: - If-Modified-Since

    @Suite("If-Modified-Since")
    struct IfModifiedSince {
        @Test("Valid RFC 822 date string sets ifModifiedSince to a non-nil date")
        func validRFC822DateSetsIfModifiedSince() {
            let request = makeRequest(
                headers: ["If-Modified-Since": "Sun, 06 Nov 1994 08:49:37 GMT"]
            )

            #expect(request?.ifModifiedSince != nil)
        }

        @Test("Valid RFC 822 date string parses to the correct date")
        func validRFC822DateParsesCorrectly() throws {
            let request = try #require(makeRequest(
                headers: ["If-Modified-Since": "Sun, 06 Nov 1994 08:49:37 GMT"]
            ))

            let date = try #require(request.ifModifiedSince)

            // 1994-11-06 08:49:37 UTC = 784111777 seconds since 1970
            let calendar = Calendar(identifier: .gregorian)
            var components = try calendar.dateComponents(in: #require(TimeZone(identifier: "UTC")), from: date)
            #expect(components.year == 1994)
            #expect(components.month == 11)
            #expect(components.day == 6)
        }

        @Test("Absent If-Modified-Since header results in nil ifModifiedSince")
        func absentHeaderResultsInNil() {
            let request = makeRequest(headers: [:])

            #expect(request?.ifModifiedSince == nil)
        }

        @Test("Invalid date string results in nil ifModifiedSince")
        func invalidDateStringResultsInNil() {
            let request = makeRequest(
                headers: ["If-Modified-Since": "not-a-valid-date"]
            )

            #expect(request?.ifModifiedSince == nil)
        }

        @Test("Empty date string results in nil ifModifiedSince")
        func emptyDateStringResultsInNil() {
            let request = makeRequest(
                headers: ["If-Modified-Since": ""]
            )

            #expect(request?.ifModifiedSince == nil)
        }
    }

    // MARK: - If-None-Match

    @Suite("If-None-Match")
    struct IfNoneMatch {
        @Test("Present If-None-Match header sets ifNoneMatch to the header value")
        func presentHeaderSetsIfNoneMatch() {
            let request = makeRequest(
                headers: ["If-None-Match": "\"etag-abc123\""]
            )

            #expect(request?.ifNoneMatch == "\"etag-abc123\"")
        }

        @Test("Absent If-None-Match header results in nil ifNoneMatch")
        func absentHeaderResultsInNil() {
            let request = makeRequest(headers: [:])

            #expect(request?.ifNoneMatch == nil)
        }

        @Test("Wildcard If-None-Match header is stored as-is")
        func wildcardIsStoredAsIs() {
            let request = makeRequest(
                headers: ["If-None-Match": "*"]
            )

            #expect(request?.ifNoneMatch == "*")
        }

        @Test("Empty If-None-Match header is stored as empty string")
        func emptyHeaderIsStoredAsEmpty() {
            let request = makeRequest(
                headers: ["If-None-Match": ""]
            )

            #expect(request?.ifNoneMatch == "")
        }
    }

    // MARK: - Byte Range

    @Suite("Byte Range")
    struct ByteRange {
        @Test("No Range header results in hasByteRange returning false")
        func noRangeHeaderMeansNoByteRange() {
            let request = makeRequest(headers: [:])

            #expect(request?.hasByteRange() == false)
        }

        @Test("No Range header results in byteRange of {NSUIntegerMax, 0}")
        func noRangeHeaderResultsInDefaultByteRange() throws {
            let request = try #require(makeRequest(headers: [:]))

            #expect(request.byteRange.location == Int(bitPattern: UInt.max))
            #expect(request.byteRange.length == 0)
        }

        @Test("Range 'bytes=0-99' sets byteRange to {0, 100}")
        func rangeFromBeginningToEnd() throws {
            let request = try #require(makeRequest(
                headers: ["Range": "bytes=0-99"]
            ))

            #expect(request.hasByteRange() == true)
            #expect(request.byteRange.location == 0)
            #expect(request.byteRange.length == 100)
        }

        @Test("Range 'bytes=500-999' sets byteRange to {500, 500}")
        func rangeMiddleSegment() throws {
            let request = try #require(makeRequest(
                headers: ["Range": "bytes=500-999"]
            ))

            #expect(request.hasByteRange() == true)
            #expect(request.byteRange.location == 500)
            #expect(request.byteRange.length == 500)
        }

        @Test("Range 'bytes=9500-' sets byteRange to {9500, NSUIntegerMax}")
        func openEndedRange() throws {
            let request = try #require(makeRequest(
                headers: ["Range": "bytes=9500-"]
            ))

            #expect(request.hasByteRange() == true)
            #expect(request.byteRange.location == 9500)
            #expect(request.byteRange.length == Int(bitPattern: UInt.max))
        }

        @Test("Range 'bytes=-500' sets byteRange to {NSUIntegerMax, 500}")
        func suffixRange() throws {
            let request = try #require(makeRequest(
                headers: ["Range": "bytes=-500"]
            ))

            #expect(request.hasByteRange() == true)
            #expect(request.byteRange.location == Int(bitPattern: UInt.max))
            #expect(request.byteRange.length == 500)
        }

        @Test("Range 'bytes=0-0' sets byteRange to {0, 1}")
        func singleByteRange() throws {
            let request = try #require(makeRequest(
                headers: ["Range": "bytes=0-0"]
            ))

            #expect(request.hasByteRange() == true)
            #expect(request.byteRange.location == 0)
            #expect(request.byteRange.length == 1)
        }

        @Test("Invalid Range header results in hasByteRange returning false")
        func invalidRangeHeaderMeansNoByteRange() {
            let request = makeRequest(
                headers: ["Range": "invalid"]
            )

            #expect(request?.hasByteRange() == false)
        }

        @Test("Multi-range header is ignored (hasByteRange returns false)")
        func multiRangeIsIgnored() {
            let request = makeRequest(
                headers: ["Range": "bytes=0-99,200-299"]
            )

            #expect(request?.hasByteRange() == false)
        }

        @Test("Range header without 'bytes=' prefix is ignored")
        func rangeWithoutBytesPrefixIsIgnored() {
            let request = makeRequest(
                headers: ["Range": "0-99"]
            )

            #expect(request?.hasByteRange() == false)
        }

        @Test("Range 'bytes=-0' is treated as invalid (suffix of 0 bytes)")
        func suffixOfZeroBytesIsInvalid() {
            let request = makeRequest(
                headers: ["Range": "bytes=-0"]
            )

            #expect(request?.hasByteRange() == false)
        }
    }

    // MARK: - Accept-Encoding

    @Suite("Accept-Encoding")
    struct AcceptEncoding {
        @Test("Accept-Encoding containing 'gzip' sets acceptsGzipContentEncoding to true")
        func gzipInAcceptEncodingSetsTrue() {
            let request = makeRequest(
                headers: ["Accept-Encoding": "gzip, deflate"]
            )

            #expect(request?.acceptsGzipContentEncoding == true)
        }

        @Test("Accept-Encoding of exactly 'gzip' sets acceptsGzipContentEncoding to true")
        func exactGzipSetsTrue() {
            let request = makeRequest(
                headers: ["Accept-Encoding": "gzip"]
            )

            #expect(request?.acceptsGzipContentEncoding == true)
        }

        @Test("Accept-Encoding without 'gzip' sets acceptsGzipContentEncoding to false")
        func noGzipSetsFalse() {
            let request = makeRequest(
                headers: ["Accept-Encoding": "deflate, br"]
            )

            #expect(request?.acceptsGzipContentEncoding == false)
        }

        @Test("No Accept-Encoding header defaults acceptsGzipContentEncoding to true")
        func absentHeaderDefaultsToTrue() {
            let request = makeRequest(headers: [:])

            #expect(request?.acceptsGzipContentEncoding == true)
        }

        @Test("Accept-Encoding with 'gzip' as part of a list sets acceptsGzipContentEncoding to true")
        func gzipInListSetsTrue() {
            let request = makeRequest(
                headers: ["Accept-Encoding": "br, gzip;q=0.8, deflate"]
            )

            #expect(request?.acceptsGzipContentEncoding == true)
        }
    }

    // MARK: - attributeForKey

    @Suite("attributeForKey")
    struct AttributeForKey {
        @Test("attributeForKey returns nil for a key that has not been set")
        func returnsNilForUnsetKey() throws {
            let request = try #require(makeRequest())

            #expect(request.attribute(forKey: "nonexistent") == nil)
        }

        @Test("DZWebServerRequestAttribute_RegexCaptures returns nil for directly created requests")
        func regexCapturesIsNilForDirectlyCreatedRequests() throws {
            let request = try #require(makeRequest())

            let captures = request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures)
            #expect(captures == nil)
        }

        @Test("attributeForKey returns nil for an arbitrary unknown key")
        func returnsNilForArbitraryKey() throws {
            let request = try #require(makeRequest())

            #expect(request.attribute(forKey: "com.example.custom-key") == nil)
        }
    }

    // MARK: - Address Properties

    @Suite("Address Properties", .serialized, .tags(.properties))
    struct AddressProperties {
        @Test("localAddressData is nil for directly created requests")
        func localAddressDataIsNil() throws {
            let request = try #require(makeRequest())

            #expect(request.localAddressData == nil)
        }

        // NOTE: localAddressString and remoteAddressString cannot be tested
        // on directly created requests because these getters call
        // DZWebServerStringFromSockAddr which calls getnameinfo() on the
        // raw data bytes. When the data is nil (no real connection), this
        // triggers DWS_DNOT_REACHED() → abort() in DEBUG builds.

        @Test("remoteAddressData is nil for directly created requests")
        func remoteAddressDataIsNil() throws {
            let request = try #require(makeRequest())

            #expect(request.remoteAddressData == nil)
        }
    }

    // MARK: - Body Writer Protocol

    @Suite("Body Writer Protocol")
    struct BodyWriterProtocol {
        @Test("Base request open does not throw")
        func openDoesNotThrow() throws {
            let request = try #require(makeRequest())

            try request.open()
        }

        @Test("Base request write does not throw")
        func writeDoesNotThrow() throws {
            let request = try #require(makeRequest())
            try request.open()

            let data = Data([0x01, 0x02, 0x03])
            try request.write(data)
        }

        @Test("Base request close does not throw")
        func closeDoesNotThrow() throws {
            let request = try #require(makeRequest())
            try request.open()

            try request.close()
        }
    }

    // MARK: - Description

    @Suite("Description")
    struct Description {
        @Test("Description contains the HTTP method and path")
        func descriptionContainsMethodAndPath() throws {
            let request = try #require(makeRequest(method: "POST", path: "/api/data"))

            let description = request.description
            #expect(description.contains("POST"))
            #expect(description.contains("/api/data"))
        }

        @Test("Description includes query parameters when present")
        func descriptionIncludesQueryParameters() throws {
            let request = try #require(makeRequest(
                urlString: "http://localhost/search?q=hello&page=1",
                query: ["q": "hello", "page": "1"]
            ))

            let description = request.description
            #expect(description.contains("q = hello"))
            #expect(description.contains("page = 1"))
        }

        @Test("Description includes headers")
        func descriptionIncludesHeaders() throws {
            let request = try #require(makeRequest(
                headers: ["X-Custom-Header": "test-value"]
            ))

            let description = request.description
            #expect(description.contains("X-Custom-Header: test-value"))
        }
    }

    // MARK: - Integration Tests

    @Suite("Integration Tests", .serialized, .tags(.integration))
    struct IntegrationTests {
        @Test("Server delivers request with correct method and path")
        func serverDeliversRequestWithCorrectMethodAndPath() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/hello",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/hello"))
            let (_, response) = try await URLSession.shared.data(from: url)
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 200)

            let request = try #require(captured.value)
            #expect(request.method == "GET")
            #expect(request.path == "/hello")
        }

        @Test("Server delivers request with query parameters")
        func serverDeliversRequestWithQueryParameters() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/search",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/search?q=hello&page=2"))
            _ = try await URLSession.shared.data(from: url)

            let request = try #require(captured.value)
            #expect(request.query?["q"] == "hello")
            #expect(request.query?["page"] == "2")
        }

        @Test("Server delivers request with correct headers")
        func serverDeliversRequestWithCorrectHeaders() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/headers",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/headers"))
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("custom-value", forHTTPHeaderField: "X-Custom-Header")
            _ = try await URLSession.shared.data(for: urlRequest)

            let request = try #require(captured.value)
            #expect(request.headers["X-Custom-Header"] == "custom-value")
        }

        @Test("Server populates local and remote address properties")
        func serverPopulatesAddressProperties() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/address",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/address"))
            _ = try await URLSession.shared.data(from: url)

            let request = try #require(captured.value)
            #expect(request.localAddressData != nil)
            #expect(request.localAddressString != nil)
            #expect(request.remoteAddressData != nil)
            #expect(request.remoteAddressString != nil)
        }

        @Test("Server request with Accept-Encoding gzip sets acceptsGzipContentEncoding to true")
        func serverRequestWithGzipAcceptEncoding() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/gzip",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/gzip"))
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
            _ = try await URLSession.shared.data(for: urlRequest)

            let request = try #require(captured.value)
            #expect(request.acceptsGzipContentEncoding == true)
        }

        @Test("Server request with Range header populates byteRange")
        func serverRequestWithRangeHeader() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/range",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/range"))
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("bytes=0-499", forHTTPHeaderField: "Range")
            _ = try await URLSession.shared.data(for: urlRequest)

            let request = try #require(captured.value)
            #expect(request.hasByteRange() == true)
            #expect(request.byteRange.location == 0)
            #expect(request.byteRange.length == 500)
        }

        @Test("Server request with If-Modified-Since header populates ifModifiedSince")
        func serverRequestWithIfModifiedSince() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/conditional",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/conditional"))
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(
                "Sun, 06 Nov 1994 08:49:37 GMT",
                forHTTPHeaderField: "If-Modified-Since"
            )
            _ = try await URLSession.shared.data(for: urlRequest)

            let request = try #require(captured.value)
            #expect(request.ifModifiedSince != nil)
        }

        @Test("Server request with If-None-Match header populates ifNoneMatch")
        func serverRequestWithIfNoneMatch() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/etag",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/etag"))
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue("\"abc123\"", forHTTPHeaderField: "If-None-Match")
            _ = try await URLSession.shared.data(for: urlRequest)

            let request = try #require(captured.value)
            #expect(request.ifNoneMatch == "\"abc123\"")
        }

        @Test("Regex path handler sets regex captures in attributeForKey")
        func regexPathHandlerSetsRegexCaptures() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                pathRegex: "/users/([0-9]+)/posts/([0-9]+)",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/users/42/posts/7"))
            let (_, response) = try await URLSession.shared.data(from: url)
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 200)

            let request = try #require(captured.value)
            let captures = try #require(
                request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures) as? [String]
            )
            #expect(captures.count == 2)
            #expect(captures[0] == "42")
            #expect(captures[1] == "7")
        }

        @Test("Request URL matches what was sent by the client")
        func requestURLMatchesClientRequest() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/verify-url",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/verify-url?a=1&b=2"))
            _ = try await URLSession.shared.data(from: url)

            let request = try #require(captured.value)
            let requestURL = request.url
            #expect(requestURL.path == "/verify-url")
        }

        @Test(
            "Server delivers requests with bodyless HTTP methods",
            arguments: ["GET", "DELETE"]
        )
        func serverDeliversRequestsWithBodylessMethods(method: String) async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addDefaultHandler(
                forMethod: method,
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/any-path"))
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = method
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 200)

            let request = try #require(captured.value)
            #expect(request.method == method)
        }

        @Test(
            "Server delivers requests with body-bearing HTTP methods",
            arguments: ["POST", "PUT", "PATCH"]
        )
        func serverDeliversRequestsWithBodyMethods(method: String) async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addDefaultHandler(
                forMethod: method,
                request: DZWebServerDataRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/any-path"))
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = method
            urlRequest.httpBody = Data("test-body".utf8)
            urlRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 200)

            let request = try #require(captured.value)
            #expect(request.method == method)
        }

        @Test("Request without query string has empty query dictionary")
        func requestWithoutQueryStringHasEmptyQuery() async throws {
            let server = DZWebServer()
            let captured = CapturedRequest()

            server.addHandler(
                forMethod: "GET",
                path: "/no-query",
                request: DZWebServerRequest.self
            ) { request -> DZWebServerResponse? in
                captured.value = request
                return DZWebServerDataResponse(text: "OK")
            }

            try server.start(options: [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ])
            defer { server.stop() }

            let port = server.port
            let url = try #require(URL(string: "http://localhost:\(port)/no-query"))
            _ = try await URLSession.shared.data(from: url)

            let request = try #require(captured.value)
            #expect(request.query?.isEmpty == true)
        }
    }
}
