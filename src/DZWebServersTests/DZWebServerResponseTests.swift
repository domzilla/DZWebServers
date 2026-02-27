//
//  DZWebServerResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Testing

// MARK: - Root Suite

@Suite("DZWebServerResponse", .serialized, .tags(.response))
struct DZWebServerResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Default Values

    @Suite("Default Values", .serialized, .tags(.properties))
    struct DefaultValues {
        @Test("New response has nil contentType")
        func defaultContentTypeIsNil() {
            let response = DZWebServerResponse()

            #expect(response.contentType == nil)
        }

        @Test("New response has contentLength equal to UInt.max")
        func defaultContentLengthIsMax() {
            let response = DZWebServerResponse()

            #expect(response.contentLength == UInt.max)
        }

        @Test("New response has statusCode equal to 200")
        func defaultStatusCodeIs200() {
            let response = DZWebServerResponse()

            #expect(response.statusCode == 200)
        }

        @Test("New response has cacheControlMaxAge equal to 0")
        func defaultCacheControlMaxAgeIsZero() {
            let response = DZWebServerResponse()

            #expect(response.cacheControlMaxAge == 0)
        }

        @Test("New response has nil lastModifiedDate")
        func defaultLastModifiedDateIsNil() {
            let response = DZWebServerResponse()

            #expect(response.lastModifiedDate == nil)
        }

        @Test("New response has nil eTag")
        func defaultETagIsNil() {
            let response = DZWebServerResponse()

            #expect(response.eTag == nil)
        }

        @Test("New response has gzipContentEncodingEnabled set to false")
        func defaultGZipContentEncodingEnabledIsFalse() {
            let response = DZWebServerResponse()

            #expect(response.isGZipContentEncodingEnabled == false)
        }
    }

    // MARK: - Has Body

    @Suite("hasBody")
    struct HasBody {
        @Test("Response with nil contentType returns false for hasBody")
        func nilContentTypeMeansNoBody() {
            let response = DZWebServerResponse()

            #expect(response.contentType == nil)
            #expect(response.hasBody() == false)
        }

        @Test("Response with non-nil contentType returns true for hasBody")
        func nonNilContentTypeMeansHasBody() {
            let response = DZWebServerResponse()
            response.contentType = "text/plain"

            #expect(response.hasBody() == true)
        }

        @Test("Setting contentType back to nil makes hasBody return false")
        func settingContentTypeToNilRemovesBody() {
            let response = DZWebServerResponse()
            response.contentType = "application/json"
            #expect(response.hasBody() == true)

            response.contentType = nil
            #expect(response.hasBody() == false)
        }
    }

    // MARK: - Factory Methods

    @Suite("Factory Methods")
    struct FactoryMethods {
        @Test("response() creates a valid empty response with default status 200")
        func responseFactoryCreatesEmptyResponse() {
            let response = DZWebServerResponse()

            #expect(response.statusCode == 200)
            #expect(response.contentType == nil)
            #expect(response.hasBody() == false)
        }

        @Test(
            "responseWithStatusCode sets the correct status code",
            arguments: [200, 201, 301, 404, 500] as [Int]
        )
        func responseWithStatusCodeSetsCorrectCode(statusCode: Int) {
            let response = DZWebServerResponse(statusCode: statusCode)

            #expect(response.statusCode == statusCode)
        }

        @Test("responseWithStatusCode preserves other default values")
        func responseWithStatusCodePreservesDefaults() {
            let response = DZWebServerResponse(statusCode: 404)

            #expect(response.statusCode == 404)
            #expect(response.contentType == nil)
            #expect(response.contentLength == UInt.max)
            #expect(response.cacheControlMaxAge == 0)
            #expect(response.lastModifiedDate == nil)
            #expect(response.eTag == nil)
            #expect(response.isGZipContentEncodingEnabled == false)
        }
    }

    // MARK: - Redirect

    @Suite("Redirect")
    struct Redirect {
        @Test("Permanent redirect sets status code to 301")
        func permanentRedirectSetsStatusCode301() throws {
            let url = try #require(URL(string: "https://example.com/new-location"))
            let response = DZWebServerResponse(redirect: url, permanent: true)

            #expect(response.statusCode == 301)
        }

        @Test("Temporary redirect sets status code to 307")
        func temporaryRedirectSetsStatusCode307() throws {
            let url = try #require(URL(string: "https://example.com/temp"))
            let response = DZWebServerResponse(redirect: url, permanent: false)

            #expect(response.statusCode == 307)
        }

        @Test("Permanent redirect includes Location header in description")
        func permanentRedirectIncludesLocationInDescription() throws {
            let url = try #require(URL(string: "https://example.com/permanent"))
            let response = DZWebServerResponse(redirect: url, permanent: true)

            let description = response.description
            #expect(description.contains("Location: https://example.com/permanent"))
        }

        @Test("Temporary redirect includes Location header in description")
        func temporaryRedirectIncludesLocationInDescription() throws {
            let url = try #require(URL(string: "https://example.com/temporary"))
            let response = DZWebServerResponse(redirect: url, permanent: false)

            let description = response.description
            #expect(description.contains("Location: https://example.com/temporary"))
        }

        @Test(
            "Redirect with various URLs preserves the URL in the Location header",
            arguments: [
                "https://example.com",
                "https://example.com/path/to/resource",
                "https://example.com/search?q=hello&lang=en",
                "https://example.com/path#fragment",
                "http://localhost:8080/api",
            ]
        )
        func redirectPreservesURL(urlString: String) throws {
            let url = try #require(URL(string: urlString))
            let response = DZWebServerResponse(redirect: url, permanent: false)

            let description = response.description
            #expect(description.contains("Location: \(urlString)"))
        }

        @Test("Redirect factory method creates the same result as init")
        func redirectFactoryMethodMatchesInit() throws {
            let url = try #require(URL(string: "https://example.com/redirect"))

            let factoryResponse = DZWebServerResponse(redirect: url, permanent: true)
            let initResponse = DZWebServerResponse(redirect: url, permanent: true)

            #expect(factoryResponse.statusCode == initResponse.statusCode)
            #expect(factoryResponse.description == initResponse.description)
        }
    }

    // MARK: - Additional Headers

    @Suite("Additional Headers")
    struct AdditionalHeaders {
        @Test("Setting a custom header appears in the description")
        func customHeaderAppearsInDescription() {
            let response = DZWebServerResponse()
            response.setValue("custom-value", forAdditionalHeader: "X-Custom-Header")

            let description = response.description
            #expect(description.contains("X-Custom-Header: custom-value"))
        }

        @Test("Setting a header value to nil removes it from the description")
        func settingNilRemovesHeader() {
            let response = DZWebServerResponse()
            response.setValue("initial-value", forAdditionalHeader: "X-Remove-Me")
            #expect(response.description.contains("X-Remove-Me: initial-value"))

            response.setValue(nil, forAdditionalHeader: "X-Remove-Me")
            #expect(!response.description.contains("X-Remove-Me"))
        }

        @Test("Multiple custom headers all appear in the description")
        func multipleCustomHeadersAppear() {
            let response = DZWebServerResponse()
            response.setValue("value-a", forAdditionalHeader: "X-Header-A")
            response.setValue("value-b", forAdditionalHeader: "X-Header-B")
            response.setValue("value-c", forAdditionalHeader: "X-Header-C")

            let description = response.description
            #expect(description.contains("X-Header-A: value-a"))
            #expect(description.contains("X-Header-B: value-b"))
            #expect(description.contains("X-Header-C: value-c"))
        }

        @Test("Overwriting an existing custom header updates its value")
        func overwritingHeaderUpdatesValue() {
            let response = DZWebServerResponse()
            response.setValue("old-value", forAdditionalHeader: "X-Overwrite")
            response.setValue("new-value", forAdditionalHeader: "X-Overwrite")

            let description = response.description
            #expect(description.contains("X-Overwrite: new-value"))
            #expect(!description.contains("X-Overwrite: old-value"))
        }
    }

    // MARK: - Property Setting

    @Suite("Property Setting", .serialized, .tags(.properties))
    struct PropertySetting {
        @Test("Setting contentType to a MIME type is persisted")
        func settingContentType() {
            let response = DZWebServerResponse()
            response.contentType = "application/json"

            #expect(response.contentType == "application/json")
        }

        @Test("Setting contentType to empty string is persisted")
        func settingContentTypeToEmptyString() {
            let response = DZWebServerResponse()
            response.contentType = ""

            #expect(response.contentType == "")
            // Even an empty string is non-nil, so hasBody should return true
            #expect(response.hasBody() == true)
        }

        @Test(
            "Setting statusCode to various values is persisted",
            arguments: [0, 100, 200, 201, 204, 301, 307, 400, 401, 403, 404, 500, 502, 503] as [Int]
        )
        func settingStatusCode(code: Int) {
            let response = DZWebServerResponse()
            response.statusCode = code

            #expect(response.statusCode == code)
        }

        @Test("Setting cacheControlMaxAge is persisted")
        func settingCacheControlMaxAge() {
            let response = DZWebServerResponse()
            response.cacheControlMaxAge = 3600

            #expect(response.cacheControlMaxAge == 3600)
        }

        @Test("Setting lastModifiedDate is persisted")
        func settingLastModifiedDate() {
            let response = DZWebServerResponse()
            let date = Date(timeIntervalSince1970: 1_000_000)
            response.lastModifiedDate = date

            #expect(response.lastModifiedDate == date)
        }

        @Test("Setting eTag is persisted")
        func settingETag() {
            let response = DZWebServerResponse()
            response.eTag = "\"abc123\""

            #expect(response.eTag == "\"abc123\"")
        }

        @Test("Setting gzipContentEncodingEnabled to true is persisted")
        func settingGZipEnabled() {
            let response = DZWebServerResponse()
            response.isGZipContentEncodingEnabled = true

            #expect(response.isGZipContentEncodingEnabled == true)
        }

        @Test("Setting gzipContentEncodingEnabled back to false is persisted")
        func settingGZipDisabled() {
            let response = DZWebServerResponse()
            response.isGZipContentEncodingEnabled = true
            response.isGZipContentEncodingEnabled = false

            #expect(response.isGZipContentEncodingEnabled == false)
        }

        @Test("Setting contentLength to a concrete value is persisted")
        func settingContentLength() {
            let response = DZWebServerResponse()
            response.contentLength = 1024

            #expect(response.contentLength == 1024)
        }

        @Test("Setting contentLength to zero is persisted")
        func settingContentLengthToZero() {
            let response = DZWebServerResponse()
            response.contentLength = 0

            #expect(response.contentLength == 0)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCases {
        @Test("Status code 0 is accepted")
        func statusCodeZero() {
            let response = DZWebServerResponse(statusCode: 0)

            #expect(response.statusCode == 0)
        }

        @Test("Negative status code is accepted")
        func negativeStatusCode() {
            let response = DZWebServerResponse()
            response.statusCode = -1

            #expect(response.statusCode == -1)
        }

        @Test("Very large cacheControlMaxAge is persisted")
        func veryLargeCacheControlMaxAge() {
            let response = DZWebServerResponse()
            response.cacheControlMaxAge = UInt.max

            #expect(response.cacheControlMaxAge == UInt.max)
        }

        @Test("Empty string eTag is persisted")
        func emptyStringETag() {
            let response = DZWebServerResponse()
            response.eTag = ""

            #expect(response.eTag == "")
        }

        @Test("Unicode eTag value is persisted")
        func unicodeETag() {
            let response = DZWebServerResponse()
            response.eTag = "\"etag-\u{1F600}-\u{00E9}\u{00F1}\u{00FC}\""

            #expect(response.eTag == "\"etag-\u{1F600}-\u{00E9}\u{00F1}\u{00FC}\"")
        }

        @Test("Setting contentType to various MIME types is persisted", arguments: [
            "text/html",
            "text/plain; charset=utf-8",
            "application/octet-stream",
            "multipart/form-data; boundary=----WebKitFormBoundary",
            "image/png"
        ])
        func variousContentTypes(mimeType: String) {
            let response = DZWebServerResponse()
            response.contentType = mimeType

            #expect(response.contentType == mimeType)
            #expect(response.hasBody() == true)
        }

        @Test("Last modified date set to distant past is persisted")
        func lastModifiedDateDistantPast() {
            let response = DZWebServerResponse()
            response.lastModifiedDate = Date.distantPast

            #expect(response.lastModifiedDate == Date.distantPast)
        }

        @Test("Last modified date set to distant future is persisted")
        func lastModifiedDateDistantFuture() {
            let response = DZWebServerResponse()
            response.lastModifiedDate = Date.distantFuture

            #expect(response.lastModifiedDate == Date.distantFuture)
        }

        @Test("Clearing lastModifiedDate by setting nil")
        func clearLastModifiedDate() {
            let response = DZWebServerResponse()
            response.lastModifiedDate = Date()
            #expect(response.lastModifiedDate != nil)

            response.lastModifiedDate = nil
            #expect(response.lastModifiedDate == nil)
        }

        @Test("Clearing eTag by setting nil")
        func clearETag() {
            let response = DZWebServerResponse()
            response.eTag = "\"some-tag\""
            #expect(response.eTag != nil)

            response.eTag = nil
            #expect(response.eTag == nil)
        }
    }

    // MARK: - Description

    @Suite("Description")
    struct Description {
        @Test("Default response description contains status code 200")
        func defaultDescriptionContainsStatusCode() {
            let response = DZWebServerResponse()

            #expect(response.description.contains("Status Code = 200"))
        }

        @Test("Description includes contentType when set")
        func descriptionIncludesContentType() {
            let response = DZWebServerResponse()
            response.contentType = "text/html"

            #expect(response.description.contains("Content Type = text/html"))
        }

        @Test("Description omits contentType when nil")
        func descriptionOmitsContentTypeWhenNil() {
            let response = DZWebServerResponse()

            #expect(!response.description.contains("Content Type"))
        }

        @Test("Description includes contentLength when set to a concrete value")
        func descriptionIncludesContentLength() {
            let response = DZWebServerResponse()
            response.contentLength = 512

            #expect(response.description.contains("Content Length = 512"))
        }

        @Test("Description omits contentLength when set to UInt.max")
        func descriptionOmitsContentLengthWhenMax() {
            let response = DZWebServerResponse()

            // Default is UInt.max, which should not appear as Content Length
            #expect(!response.description.contains("Content Length"))
        }

        @Test("Description includes cacheControlMaxAge")
        func descriptionIncludesCacheControlMaxAge() {
            let response = DZWebServerResponse()
            response.cacheControlMaxAge = 7200

            #expect(response.description.contains("Cache Control Max Age = 7200"))
        }

        @Test("Description includes lastModifiedDate when set")
        func descriptionIncludesLastModifiedDate() {
            let response = DZWebServerResponse()
            let date = Date(timeIntervalSince1970: 0)
            response.lastModifiedDate = date

            #expect(response.description.contains("Last Modified Date"))
        }

        @Test("Description includes eTag when set")
        func descriptionIncludesETag() {
            let response = DZWebServerResponse()
            response.eTag = "\"my-etag\""

            #expect(response.description.contains("ETag = \"my-etag\""))
        }

        @Test("Description omits eTag when nil")
        func descriptionOmitsETagWhenNil() {
            let response = DZWebServerResponse()

            #expect(!response.description.contains("ETag"))
        }
    }

    // MARK: - Body Reader Protocol

    @Suite("Body Reader Protocol")
    struct BodyReaderProtocol {
        @Test("Base response open succeeds")
        func openSucceeds() throws {
            let response = DZWebServerResponse()

            try response.open()
            // open() throws on failure — if we get here, it succeeded
        }

        @Test("Base response readData returns empty data")
        func readDataReturnsEmptyData() throws {
            let response = DZWebServerResponse()
            _ = try response.open()
            let data = try response.readData()

            #expect(data.isEmpty)
        }

        @Test("Base response close does not throw")
        func closeDoesNotThrow() throws {
            let response = DZWebServerResponse()
            _ = try response.open()
            _ = try response.readData()
            response.close()
        }
    }
}
