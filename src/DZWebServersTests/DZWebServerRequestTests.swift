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

// MARK: Helpers

/// NSUIntegerMax as bridged into the `Int` fields of `NSRange`.
private let uIntegerMax = Int(bitPattern: UInt.max)

/// The handler runs on a GCD thread, hence `@unchecked Sendable`.
private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: DZWebServerRequest?

    var value: DZWebServerRequest? {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.storedValue
        }
        set {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.storedValue = newValue
        }
    }
}

private func makeRequest(
    method: String = "GET",
    urlString: String = "http://localhost/test",
    headers: [String: String] = [:],
    path: String = "/test",
    query: [String: String]? = nil
)
    -> DZWebServerRequest
{
    DZWebServerRequest(
        method: method,
        url: URL(string: urlString)!,
        headers: headers,
        path: path,
        query: query
    )
}

/// Sends a request to a fresh server and returns the request object the handler received.
/// With `pathRegex` the handler matches that regex, otherwise every path.
private func captureServerRequest(
    method: String = "GET",
    path: String,
    pathRegex: String? = nil,
    requestClass: AnyClass = DZWebServerRequest.self,
    body: Data? = nil,
    headers: [String: String] = [:]
) async throws
    -> DZWebServerRequest
{
    let server = DZWebServer()
    let captured = CapturedRequest()
    let processBlock: DZWebServerProcessBlock = { request in
        captured.value = request
        return DZWebServerDataResponse(text: "OK")
    }
    if let pathRegex {
        server.addHandler(forMethod: method, pathRegex: pathRegex, request: requestClass, processBlock: processBlock)
    } else {
        server.addDefaultHandler(forMethod: method, request: requestClass, processBlock: processBlock)
    }
    try TestSupport.start(server)
    defer { server.stop() }

    let url = try #require(URL(string: "http://localhost:\(server.port)\(path)"))
    let result = try await TestSupport.sendRequest(method: method, url: url, body: body, headers: headers)
    #expect(result.statusCode == 200)
    return try #require(captured.value)
}

// MARK: Root Suite

@Suite("DZWebServerRequest", .serialized, .tags(.request))
struct DZWebServerRequestTests {
    // MARK: Basic Properties

    @Suite("Basic Properties", .serialized, .tags(.properties))
    struct BasicProperties {
        @Test("Initializer stores method, URL, headers, path and query")
        func initializerStoresArguments() throws {
            let url = try #require(URL(string: "http://localhost:8080/api/v1/resource?id=42"))
            let request = DZWebServerRequest(
                method: "POST",
                url: url,
                headers: ["Accept": "application/json", "X-Custom": "value"],
                path: "/api/v1/resource",
                query: ["id": "42"]
            )

            #expect(request.method == "POST")
            #expect(request.url == url)
            #expect(request.headers == ["Accept": "application/json", "X-Custom": "value"])
            #expect(request.path == "/api/v1/resource")
            #expect(request.query == ["id": "42"])
        }

        @Test("Query property is nil when no query parameters are provided")
        func queryIsNilWhenNotProvided() {
            #expect(makeRequest(query: nil).query == nil)
        }
    }

    // MARK: Content Type and Content Length

    /// Content-Length combined with chunked encoding and negative Content-Length are not tested: the implementation
    /// hits DWS_DNOT_REACHED() (abort() in DEBUG), which cannot be caught.
    @Suite("Content Type and Content Length")
    struct ContentTypeAndLength {
        @Test("No body headers result in nil contentType and contentLength of NSUIntegerMax")
        func noContentHeaders() {
            let request = makeRequest()

            #expect(request.contentType == nil)
            #expect(request.contentLength == UInt.max)
        }

        @Test("Content-Type header alone (without body indicator) is ignored")
        func contentTypeAloneIsIgnored() {
            let request = makeRequest(headers: ["Content-Type": "text/plain"])

            #expect(request.contentType == nil)
        }

        @Test("Content-Type with Content-Length sets both properties")
        func contentTypeWithContentLengthSetsProperties() {
            let request = makeRequest(headers: ["Content-Type": "application/json", "Content-Length": "256"])

            #expect(request.contentType == "application/json")
            #expect(request.contentLength == 256)
        }

        @Test("Content-Length without Content-Type defaults contentType to application/octet-stream")
        func contentLengthWithoutContentTypeDefaultsToOctetStream() {
            let request = makeRequest(headers: ["Content-Length": "100"])

            #expect(request.contentType == "application/octet-stream")
            #expect(request.contentLength == 100)
        }

        @Test("Content-Length of zero is valid and counts as a body")
        func zeroContentLengthIsValid() {
            let request = makeRequest(headers: ["Content-Length": "0"])

            #expect(request.contentLength == 0)
            #expect(request.hasBody())
        }

        @Test("Chunked Transfer-Encoding without Content-Type defaults contentType to application/octet-stream")
        func chunkedWithoutContentTypeDefaultsToOctetStream() {
            let request = makeRequest(headers: ["Transfer-Encoding": "chunked"])

            #expect(request.contentType == "application/octet-stream")
        }

        @Test("Chunked Transfer-Encoding keeps Content-Type and sets contentLength to NSUIntegerMax")
        func chunkedWithContentType() {
            let request = makeRequest(headers: ["Content-Type": "text/plain", "Transfer-Encoding": "chunked"])

            #expect(request.contentType == "text/plain")
            #expect(request.contentLength == UInt.max)
        }
    }

    // MARK: hasBody

    @Suite("hasBody")
    struct HasBody {
        @Test("hasBody reflects Content-Length or chunked Transfer-Encoding", arguments: [
            ([:], false),
            (["Content-Type": "text/plain"], false),
            (["Content-Length": "42"], true),
            (["Transfer-Encoding": "chunked"], true),
        ] as [([String: String], Bool)])
        func hasBodyReflectsHeaders(headers: [String: String], hasBody: Bool) {
            #expect(makeRequest(headers: headers).hasBody() == hasBody)
        }
    }

    // MARK: If-Modified-Since

    @Suite("If-Modified-Since")
    struct IfModifiedSince {
        @Test("Valid RFC 822 date string parses to the exact date")
        func validRFC822DateParsesCorrectly() throws {
            let request = makeRequest(headers: ["If-Modified-Since": "Sun, 06 Nov 1994 08:49:37 GMT"])

            let date = try #require(request.ifModifiedSince)
            #expect(date.timeIntervalSince1970 == 784_111_777)
        }

        @Test("Absent, invalid or empty header results in nil ifModifiedSince", arguments: [
            nil,
            "not-a-valid-date",
            "",
        ] as [String?])
        func invalidHeaderResultsInNil(value: String?) {
            let headers = value.map { ["If-Modified-Since": $0] } ?? [:]

            #expect(makeRequest(headers: headers).ifModifiedSince == nil)
        }
    }

    // MARK: If-None-Match

    @Suite("If-None-Match")
    struct IfNoneMatch {
        @Test("If-None-Match header value is stored as-is", arguments: ["\"etag-abc123\"", "*", ""])
        func headerIsStoredAsIs(value: String) {
            #expect(makeRequest(headers: ["If-None-Match": value]).ifNoneMatch == value)
        }

        @Test("Absent If-None-Match header results in nil ifNoneMatch")
        func absentHeaderResultsInNil() {
            #expect(makeRequest().ifNoneMatch == nil)
        }
    }

    // MARK: Byte Range

    @Suite("Byte Range")
    struct ByteRange {
        @Test("No Range header results in no byte range of {NSUIntegerMax, 0}")
        func noRangeHeader() {
            let request = makeRequest()

            #expect(!request.hasByteRange())
            #expect(request.byteRange.location == uIntegerMax)
            #expect(request.byteRange.length == 0)
        }

        @Test("Valid single Range header is parsed", arguments: [
            ("bytes=0-99", 0, 100),
            ("bytes=500-999", 500, 500),
            ("bytes=0-0", 0, 1),
            ("bytes=9500-", 9500, uIntegerMax),
            ("bytes=-500", uIntegerMax, 500),
        ])
        func validRangeIsParsed(header: String, location: Int, length: Int) {
            let request = makeRequest(headers: ["Range": header])

            #expect(request.hasByteRange())
            #expect(request.byteRange.location == location)
            #expect(request.byteRange.length == length)
        }

        @Test("Invalid, multi-range, unprefixed or zero-suffix Range header is ignored", arguments: [
            "invalid",
            "bytes=0-99,200-299",
            "0-99",
            "bytes=-0",
        ])
        func invalidRangeIsIgnored(header: String) {
            #expect(!makeRequest(headers: ["Range": header]).hasByteRange())
        }
    }

    // MARK: Accept-Encoding

    @Suite("Accept-Encoding")
    struct AcceptEncoding {
        @Test("acceptsGzipContentEncoding reflects the Accept-Encoding header", arguments: [
            ("gzip, deflate", true),
            ("gzip", true),
            ("br, gzip;q=0.8, deflate", true),
            ("deflate, br", false),
        ])
        func acceptsGzipReflectsHeader(header: String, acceptsGzip: Bool) {
            #expect(makeRequest(headers: ["Accept-Encoding": header]).acceptsGzipContentEncoding == acceptsGzip)
        }

        @Test("No Accept-Encoding header defaults acceptsGzipContentEncoding to true")
        func absentHeaderDefaultsToTrue() {
            #expect(makeRequest().acceptsGzipContentEncoding)
        }
    }

    // MARK: Attributes and Addresses

    @Suite("Attributes and Addresses", .serialized, .tags(.properties))
    struct AttributesAndAddresses {
        @Test("Directly created request has no attributes")
        func directlyCreatedRequestHasNoAttributes() {
            let request = makeRequest()

            #expect(request.attribute(forKey: "com.example.custom-key") == nil)
            #expect(request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures) == nil)
        }

        /// localAddressString and remoteAddressString are not tested here: without address data they hit
        /// DWS_DNOT_REACHED() (abort() in DEBUG).
        @Test("Directly created request has nil address data")
        func directlyCreatedRequestHasNilAddressData() {
            let request = makeRequest()

            #expect(request.localAddressData == nil)
            #expect(request.remoteAddressData == nil)
        }
    }

    // MARK: Body Writer Protocol

    @Suite("Body Writer Protocol")
    struct BodyWriterProtocol {
        @Test("Base request accepts open, write and close without error")
        func baseRequestAcceptsBody() throws {
            let request = makeRequest()

            try request.open()
            try request.write(Data([0x01, 0x02, 0x03]))
            try request.close()
        }
    }

    // MARK: Description

    @Suite("Description")
    struct Description {
        @Test("Description contains the HTTP method and path")
        func descriptionContainsMethodAndPath() {
            let description = makeRequest(method: "POST", path: "/api/data").description

            #expect(description.contains("POST"))
            #expect(description.contains("/api/data"))
        }

        @Test("Description includes query parameters when present")
        func descriptionIncludesQueryParameters() {
            let description = makeRequest(
                urlString: "http://localhost/search?q=hello&page=1",
                query: ["q": "hello", "page": "1"]
            ).description

            #expect(description.contains("q = hello"))
            #expect(description.contains("page = 1"))
        }

        @Test("Description includes headers")
        func descriptionIncludesHeaders() {
            let description = makeRequest(headers: ["X-Custom-Header": "test-value"]).description

            #expect(description.contains("X-Custom-Header: test-value"))
        }
    }

    // MARK: Integration Tests

    @Suite("Integration Tests", .serialized, .tags(.integration))
    struct IntegrationTests {
        @Test("Server delivers request with URL, path and query parameters")
        func serverDeliversURLPathAndQuery() async throws {
            let request = try await captureServerRequest(path: "/search?q=hello&page=2")

            #expect(request.method == "GET")
            #expect(request.path == "/search")
            #expect(request.url.path == "/search")
            #expect(request.url.query == "q=hello&page=2")
            #expect(request.query == ["q": "hello", "page": "2"])
        }

        @Test("Request without query string has empty query dictionary")
        func requestWithoutQueryStringHasEmptyQuery() async throws {
            let request = try await captureServerRequest(path: "/no-query")

            #expect(request.query?.isEmpty == true)
        }

        @Test("Server populates local and remote address properties")
        func serverPopulatesAddressProperties() async throws {
            let request = try await captureServerRequest(path: "/address")

            #expect(request.localAddressData != nil)
            #expect(request.remoteAddressData != nil)
            let localAddress = try #require(request.localAddressString)
            let remoteAddress = try #require(request.remoteAddressString)
            #expect(!localAddress.isEmpty)
            #expect(!remoteAddress.isEmpty)
        }

        @Test("Server parses conditional, range and encoding headers")
        func serverParsesRequestHeaders() async throws {
            let request = try await captureServerRequest(
                path: "/headers",
                headers: [
                    "X-Custom-Header": "custom-value",
                    "Accept-Encoding": "gzip, deflate",
                    "Range": "bytes=0-499",
                    "If-Modified-Since": "Sun, 06 Nov 1994 08:49:37 GMT",
                    "If-None-Match": "\"abc123\"",
                ]
            )

            #expect(request.headers["X-Custom-Header"] == "custom-value")
            #expect(request.acceptsGzipContentEncoding)
            #expect(request.hasByteRange())
            #expect(request.byteRange.location == 0)
            #expect(request.byteRange.length == 500)
            #expect(request.ifModifiedSince?.timeIntervalSince1970 == 784_111_777)
            #expect(request.ifNoneMatch == "\"abc123\"")
        }

        @Test("Regex path handler sets regex captures attribute")
        func regexPathHandlerSetsRegexCaptures() async throws {
            let request = try await captureServerRequest(
                path: "/users/42/posts/7",
                pathRegex: "/users/([0-9]+)/posts/([0-9]+)"
            )

            let captures = request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures) as? [String]
            #expect(captures == ["42", "7"])
        }

        @Test("Server delivers requests with bodyless HTTP methods", arguments: ["GET", "DELETE"])
        func serverDeliversRequestsWithBodylessMethods(method: String) async throws {
            let request = try await captureServerRequest(method: method, path: "/any-path")

            #expect(request.method == method)
        }

        @Test("Server delivers requests with body-bearing HTTP methods", arguments: ["POST", "PUT", "PATCH"])
        func serverDeliversRequestsWithBodyMethods(method: String) async throws {
            let request = try await captureServerRequest(
                method: method,
                path: "/any-path",
                requestClass: DZWebServerDataRequest.self,
                body: Data("test-body".utf8),
                headers: ["Content-Type": "text/plain"]
            )

            let dataRequest = try #require(request as? DZWebServerDataRequest)
            #expect(dataRequest.method == method)
            #expect(dataRequest.contentType == "text/plain")
            #expect(dataRequest.data == Data("test-body".utf8))
        }
    }
}
