//
//  DZWebServerResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

@Suite("DZWebServerResponse", .serialized, .tags(.response))
struct DZWebServerResponseTests {
    // MARK: Initialization

    @Suite("Initialization", .tags(.properties))
    struct Initialization {
        @Test("init produces an empty 200 response with unknown length and no caching metadata")
        func initSetsDefaults() {
            let response = DZWebServerResponse()

            #expect(response.statusCode == 200)
            #expect(response.contentType == nil)
            #expect(response.contentLength == UInt.max)
            #expect(response.cacheControlMaxAge == 0)
            #expect(response.lastModifiedDate == nil)
            #expect(response.eTag == nil)
            #expect(!response.isGZipContentEncodingEnabled)
            #expect(!response.hasBody())
        }

        @Test("init(statusCode:) sets only the status code", arguments: [0, 201, 301, 404, 500])
        func initWithStatusCode(statusCode: Int) {
            let response = DZWebServerResponse(statusCode: statusCode)

            #expect(response.statusCode == statusCode)
            #expect(response.contentType == nil)
            #expect(response.contentLength == UInt.max)
            #expect(response.cacheControlMaxAge == 0)
            #expect(!response.hasBody())
        }
    }

    // MARK: Has Body

    @Suite("hasBody")
    struct HasBody {
        @Test("hasBody follows whether a content type is set")
        func hasBodyFollowsContentType() {
            let response = DZWebServerResponse()

            response.contentType = "application/json"
            #expect(response.hasBody())

            response.contentType = nil
            #expect(!response.hasBody())
        }

        @Test("An empty content type still counts as a body")
        func emptyContentTypeCountsAsBody() {
            let response = DZWebServerResponse()
            response.contentType = ""

            #expect(response.hasBody())
        }
    }

    // MARK: Redirect

    @Suite("Redirect")
    struct Redirect {
        @Test(
            "Redirect uses 301 when permanent and 307 otherwise",
            arguments: [(true, 301), (false, 307)]
        )
        func redirectStatusCode(isPermanent: Bool, expectedStatusCode: Int) throws {
            let url = try #require(URL(string: "https://example.com/new-location"))
            let response = DZWebServerResponse(redirect: url, permanent: isPermanent)

            #expect(response.statusCode == expectedStatusCode)
            #expect(!response.hasBody())
        }

        @Test(
            "Redirect puts the absolute URL in the Location header",
            arguments: [
                "https://example.com",
                "https://example.com/path/to/resource",
                "https://example.com/search?q=hello&lang=en",
                "https://example.com/path#fragment",
                "http://localhost:8080/api",
            ]
        )
        func redirectSetsLocationHeader(urlString: String) throws {
            let url = try #require(URL(string: urlString))
            let response = DZWebServerResponse(redirect: url, permanent: false)

            #expect(response.description.contains("Location: \(urlString)"))
        }
    }

    // MARK: Additional Headers

    @Suite("Additional Headers")
    struct AdditionalHeaders {
        @Test("Multiple custom headers are all recorded")
        func multipleCustomHeadersAreRecorded() {
            let response = DZWebServerResponse()
            response.setValue("value-a", forAdditionalHeader: "X-Header-A")
            response.setValue("value-b", forAdditionalHeader: "X-Header-B")

            let description = response.description
            #expect(description.contains("X-Header-A: value-a"))
            #expect(description.contains("X-Header-B: value-b"))
        }

        @Test("Setting a header value to nil removes the header")
        func settingNilRemovesHeader() {
            let response = DZWebServerResponse()
            response.setValue("initial-value", forAdditionalHeader: "X-Remove-Me")
            #expect(response.description.contains("X-Remove-Me: initial-value"))

            response.setValue(nil, forAdditionalHeader: "X-Remove-Me")
            #expect(!response.description.contains("X-Remove-Me"))
        }

        @Test("Setting an existing header again replaces its value")
        func overwritingHeaderReplacesValue() {
            let response = DZWebServerResponse()
            response.setValue("old-value", forAdditionalHeader: "X-Overwrite")
            response.setValue("new-value", forAdditionalHeader: "X-Overwrite")

            let description = response.description
            #expect(description.contains("X-Overwrite: new-value"))
            #expect(!description.contains("X-Overwrite: old-value"))
        }
    }

    // MARK: Description

    @Suite("Description")
    struct Description {
        @Test("Default description lists only status code and cache age")
        func defaultDescription() {
            let response = DZWebServerResponse()

            #expect(response.description == "Status Code = 200\nCache Control Max Age = 0")
        }

        @Test("Description lists every set property")
        func descriptionListsSetProperties() {
            let date = Date(timeIntervalSince1970: 0)
            let response = DZWebServerResponse()
            response.contentType = "text/html"
            response.contentLength = 512
            response.cacheControlMaxAge = 7200
            response.lastModifiedDate = date
            response.eTag = "\"my-etag\""

            let description = response.description
            #expect(description.contains("Content Type = text/html"))
            #expect(description.contains("Content Length = 512"))
            #expect(description.contains("Cache Control Max Age = 7200"))
            #expect(description.contains("Last Modified Date = \(date as NSDate)"))
            #expect(description.contains("ETag = \"my-etag\""))
        }
    }

    // MARK: Body Reader

    @Suite("Body Reader")
    struct BodyReader {
        @Test("Base response opens, reads empty data and closes")
        func baseResponseReadsEmptyBody() throws {
            let response = DZWebServerResponse()

            try response.open()
            let data = try response.readData()
            response.close()

            #expect(data.isEmpty)
        }
    }
}
