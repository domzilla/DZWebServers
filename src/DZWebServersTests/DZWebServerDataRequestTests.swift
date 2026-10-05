//
//  DZWebServerDataRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

/// Written on the server's GCD thread before the response is sent, read by the test only after the response
/// arrived, hence `@unchecked Sendable`.
private final class RequestCapture: @unchecked Sendable {
    var data: Data?
    var text: String?
    var jsonObject: Any?
    var contentType: String?
    var contentLength: UInt = 0
    var method: String?
    var path: String?
}

/// Starts a server with a `DZWebServerDataRequest` POST handler, sends `body` and returns what the handler saw.
private func captureDataRequest(body: Data, contentType: String) async throws -> RequestCapture {
    let server = DZWebServer()
    let capture = RequestCapture()

    server.addHandler(
        forMethod: "POST",
        path: "/data",
        request: DZWebServerDataRequest.self
    ) { request -> DZWebServerResponse? in
        let dataRequest = request as! DZWebServerDataRequest
        capture.data = dataRequest.data as Data
        // .text and .jsonObject hit DWS_DNOT_REACHED (abort in DEBUG) for non-matching content types.
        if let contentType = dataRequest.contentType {
            if contentType.hasPrefix("text/") {
                capture.text = dataRequest.text
            }
            let mimeType = contentType.components(separatedBy: ";").first ?? contentType
            if ["application/json", "text/json", "text/javascript"].contains(mimeType) {
                capture.jsonObject = dataRequest.jsonObject
            }
        }
        capture.contentType = dataRequest.contentType
        capture.contentLength = dataRequest.contentLength
        capture.method = dataRequest.method
        capture.path = dataRequest.path
        return DZWebServerDataResponse(text: "OK")
    }

    try TestSupport.start(server)
    defer { server.stop() }

    let url = try #require(server.serverURL).appendingPathComponent("data")
    let (statusCode, _, _) = try await TestSupport.sendRequest(
        method: "POST",
        url: url,
        body: body,
        headers: ["Content-Type": contentType]
    )
    #expect(statusCode == 200)
    return capture
}

/// Bytes whose value depends on their position, so truncation, reordering or duplication is detected.
private func patternedData(count: Int) -> Data {
    Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ 13) })
}

@Suite("DZWebServerDataRequest", .serialized, .tags(.request, .integration))
struct DZWebServerDataRequestTests {
    // MARK: Data Property

    @Suite("Data property")
    struct DataProperty {
        @Test("POST data is captured exactly")
        func postDataIsCapturedExactly() async throws {
            let sentData = Data("Hello, DZWebServer!".utf8)
            let capture = try await captureDataRequest(body: sentData, contentType: "application/octet-stream")

            #expect(capture.data == sentData)
        }

        @Test("POST empty body produces empty data")
        func postEmptyBodyProducesEmptyData() async throws {
            let capture = try await captureDataRequest(body: Data(), contentType: "application/octet-stream")

            #expect(capture.data == Data())
        }

        @Test("POST data with all byte values (0x00 to 0xFF) is preserved")
        func postAllByteValuesPreserved() async throws {
            let sentData = Data((0...255).map { UInt8($0) })
            let capture = try await captureDataRequest(body: sentData, contentType: "application/octet-stream")

            #expect(capture.data == sentData)
        }

        @Test("POST data of various sizes is captured without truncation", arguments: [1, 100_000, 2_097_152])
        func postDataOfVariousSizesIsCaptured(size: Int) async throws {
            let sentData = patternedData(count: size)
            let capture = try await captureDataRequest(body: sentData, contentType: "application/octet-stream")

            #expect(capture.data == sentData)
        }

        @Test("contentLength matches the size of the sent data")
        func contentLengthMatchesSentDataSize() async throws {
            let sentData = Data("Measure this".utf8)
            let capture = try await captureDataRequest(body: sentData, contentType: "text/plain")

            #expect(capture.contentLength == UInt(sentData.count))
        }

        @Test("method and path match the handled request")
        func methodAndPathMatchHandledRequest() async throws {
            let capture = try await captureDataRequest(body: Data("test".utf8), contentType: "text/plain")

            #expect(capture.method == "POST")
            #expect(capture.path == "/data")
        }

        @Test(
            "contentType and data are preserved for various MIME types",
            arguments: [
                "application/octet-stream",
                "application/json",
                "application/xml",
                "text/plain",
                "image/png",
                "audio/mpeg",
            ]
        )
        func contentTypeAndDataArePreserved(contentType: String) async throws {
            let sentData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            let capture = try await captureDataRequest(body: sentData, contentType: contentType)

            #expect(capture.contentType == contentType)
            #expect(capture.data == sentData)
        }

        @Test("multiple sequential requests to the same handler each capture their own body")
        func multipleSequentialRequestsCaptureCorrectly() async throws {
            let server = DZWebServer()
            let lock = NSLock()
            var capturedValues: [Data] = []

            server.addHandler(
                forMethod: "POST",
                path: "/data",
                request: DZWebServerDataRequest.self
            ) { request -> DZWebServerResponse? in
                let dataRequest = request as! DZWebServerDataRequest
                lock.withLock {
                    capturedValues.append(dataRequest.data as Data)
                }
                return DZWebServerDataResponse(text: "OK")
            }

            try TestSupport.start(server)
            defer { server.stop() }

            let url = try #require(server.serverURL).appendingPathComponent("data")
            let messages = ["first", "second", "third"]
            for message in messages {
                _ = try await TestSupport.sendRequest(
                    method: "POST",
                    url: url,
                    body: Data(message.utf8),
                    headers: ["Content-Type": "text/plain"]
                )
            }

            #expect(lock.withLock { capturedValues } == messages.map { Data($0.utf8) })
        }
    }

    // MARK: Text Property

    @Suite("Text property")
    struct TextProperty {
        @Test(
            "POST with text/ content types decodes the body as text",
            arguments: [
                "text/plain",
                "text/html",
                "text/css",
                "text/csv",
                "text/xml",
                "text/plain; charset=utf-8",
            ]
        )
        func postWithTextContentTypesDecodesText(contentType: String) async throws {
            let sentString = "content for \(contentType)"
            let capture = try await captureDataRequest(body: Data(sentString.utf8), contentType: contentType)

            #expect(capture.text == sentString)
        }

        @Test(
            "POST UTF-8 text with multibyte characters decodes correctly",
            arguments: [
                "Hello \u{1F30D}\u{1F680}\u{2764}\u{FE0F} World",
                "\u{4F60}\u{597D}\u{4E16}\u{754C}",
            ]
        )
        func postUTF8MultibyteTextDecodesCorrectly(sentString: String) async throws {
            let capture = try await captureDataRequest(
                body: Data(sentString.utf8),
                contentType: "text/plain; charset=utf-8"
            )

            #expect(capture.text == sentString)
        }

        @Test("POST with charset=iso-8859-1 decodes using that charset")
        func postTextPlainWithCharsetISO88591DecodesCorrectly() async throws {
            let sentString = "caf\u{00E9}"
            let encodedData = try #require(sentString.data(using: .isoLatin1))
            let capture = try await captureDataRequest(body: encodedData, contentType: "text/plain; charset=iso-8859-1")

            #expect(capture.text == sentString)
        }

        @Test("POST empty text body produces empty text string")
        func postEmptyTextBodyProducesEmptyString() async throws {
            let capture = try await captureDataRequest(body: Data(), contentType: "text/plain")

            #expect(capture.text == "")
        }
    }

    // MARK: JSON Object Property

    @Suite("JSON object property")
    struct JSONObjectProperty {
        @Test("POST JSON dictionary produces NSDictionary")
        func postJSONDictionaryProducesNSDictionary() async throws {
            let dict: [String: Any] = ["name": "Dominic", "active": true, "score": 42]
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            let capture = try await captureDataRequest(body: jsonData, contentType: "application/json")

            let resultDict = try #require(capture.jsonObject as? NSDictionary)
            #expect(resultDict["name"] as? String == "Dominic")
            #expect(resultDict["active"] as? Bool == true)
            #expect(resultDict["score"] as? Int == 42)
        }

        @Test("POST JSON array produces NSArray")
        func postJSONArrayProducesNSArray() async throws {
            let jsonData = Data(#"[1, "two", 3.5, true]"#.utf8)
            let capture = try await captureDataRequest(body: jsonData, contentType: "application/json")

            let resultArray = try #require(capture.jsonObject as? NSArray)
            #expect(resultArray.count == 4)
            #expect(resultArray[0] as? Int == 1)
            #expect(resultArray[1] as? String == "two")
            #expect(resultArray[2] as? Double == 3.5)
            #expect(resultArray[3] as? Bool == true)
        }

        @Test("POST nested JSON object is fully parsed")
        func postNestedJSONObjectIsFullyParsed() async throws {
            let jsonData = Data(#"{"user": {"name": "Dominic", "tags": ["swift", "objc"]}}"#.utf8)
            let capture = try await captureDataRequest(body: jsonData, contentType: "application/json")

            let resultDict = try #require(capture.jsonObject as? NSDictionary)
            let user = try #require(resultDict["user"] as? NSDictionary)
            #expect(user["name"] as? String == "Dominic")
            #expect(user["tags"] as? [String] == ["swift", "objc"])
        }

        @Test("POST empty JSON object produces empty NSDictionary")
        func postEmptyJSONObjectProducesEmptyDictionary() async throws {
            let capture = try await captureDataRequest(body: Data("{}".utf8), contentType: "application/json")

            let resultDict = try #require(capture.jsonObject as? NSDictionary)
            #expect(resultDict.count == 0)
        }

        @Test("POST empty JSON array produces empty NSArray")
        func postEmptyJSONArrayProducesEmptyArray() async throws {
            let capture = try await captureDataRequest(body: Data("[]".utf8), contentType: "application/json")

            let resultArray = try #require(capture.jsonObject as? NSArray)
            #expect(resultArray.count == 0)
        }

        @Test("POST invalid JSON produces nil jsonObject")
        func postInvalidJSONProducesNilJSONObject() async throws {
            let capture = try await captureDataRequest(
                body: Data("this is not json {{{".utf8),
                contentType: "application/json"
            )

            #expect(capture.data == Data("this is not json {{{".utf8))
            #expect(capture.jsonObject == nil)
        }

        @Test("POST JSON with unicode keys and values parses correctly")
        func postJSONWithUnicodeKeysAndValuesParses() async throws {
            let dict: [String: Any] = ["\u{1F600}": "\u{1F30D}", "caf\u{00E9}": "latt\u{00E9}"]
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            let capture = try await captureDataRequest(body: jsonData, contentType: "application/json")

            let resultDict = try #require(capture.jsonObject as? NSDictionary)
            #expect(resultDict["\u{1F600}"] as? String == "\u{1F30D}")
            #expect(resultDict["caf\u{00E9}"] as? String == "latt\u{00E9}")
        }

        @Test(
            "POST JSON with each accepted content type produces jsonObject",
            arguments: [
                "application/json",
                "application/json; charset=utf-8",
                "text/json",
                "text/javascript",
            ]
        )
        func postJSONWithAcceptedContentTypesProducesObject(contentType: String) async throws {
            let jsonData = try JSONSerialization.data(withJSONObject: ["type": contentType])
            let capture = try await captureDataRequest(body: jsonData, contentType: contentType)

            let resultDict = try #require(capture.jsonObject as? NSDictionary)
            #expect(resultDict["type"] as? String == contentType)
        }
    }
}
