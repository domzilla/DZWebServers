//
//  DZWebServerDataRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Request Capture

/// Thread-safe container for capturing request properties from a server handler.
/// The handler runs on a GCD thread, so we need `@unchecked Sendable` to safely
/// pass this into the closure and read from the test thread after the request completes.
private final class RequestCapture: @unchecked Sendable {
    var data: Data?
    var text: String?
    var jsonObject: Any?
    var contentType: String?
    var contentLength: UInt = 0
    var method: String?
    var path: String?
}

// MARK: - Helper

/// Creates a started `DZWebServer` bound to localhost on a random port, registers
/// a POST handler at the given path that captures request properties, and returns
/// the server, its base URL, and the capture object.
///
/// The caller is responsible for calling `server.stop()` when done.
private func makeServerCapturingDataRequest(
    path: String = "/data"
) throws
    -> (server: DZWebServer, baseURL: URL, capture: RequestCapture)
{
    let server = DZWebServer()
    let capture = RequestCapture()

    server.addHandler(
        forMethod: "POST",
        path: path,
        request: DZWebServerDataRequest.self
    ) { request -> DZWebServerResponse? in
        let dataRequest = request as! DZWebServerDataRequest
        capture.data = dataRequest.data as Data
        // Only access .text when the content type is text/*
        // (DWS_DNOT_REACHED / abort() in DEBUG otherwise)
        if let ct = dataRequest.contentType, ct.hasPrefix("text/") {
            capture.text = dataRequest.text
        }
        // Only access .jsonObject when the content type is JSON
        // (DWS_DNOT_REACHED / abort() in DEBUG otherwise)
        if let ct = dataRequest.contentType {
            let mimeType = ct.components(separatedBy: ";").first ?? ct
            if mimeType == "application/json" || mimeType == "text/json" || mimeType == "text/javascript" {
                capture.jsonObject = dataRequest.jsonObject
            }
        }
        capture.contentType = dataRequest.contentType
        capture.contentLength = dataRequest.contentLength
        capture.method = dataRequest.method
        capture.path = dataRequest.path
        return DZWebServerDataResponse(text: "OK")
    }

    let options: [String: Any] = [
        DZWebServerOption_Port: 0,
        DZWebServerOption_BindToLocalhost: true,
    ]
    try server.start(options: options)

    let baseURL = URL(string: "http://localhost:\(server.port)")!
    return (server, baseURL, capture)
}

/// Sends a POST request to the given URL with the specified body and content type,
/// waits for the response, and returns the response data.
@discardableResult
private func sendPOST(
    to url: URL,
    body: Data,
    contentType: String
) async throws
    -> Data
{
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")

    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}

// MARK: - Test Suite

@Suite("DZWebServerDataRequest", .serialized, .tags(.request))
struct DZWebServerDataRequestTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Data Property (Integration)

    @Suite("Data property via integration", .serialized, .tags(.integration))
    struct DataProperty {
        @Test("POST plain data is captured exactly")
        func postPlainDataIsCapturedExactly() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentData = Data("Hello, DZWebServer!".utf8)
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data == sentData)
        }

        @Test("POST empty body produces empty data")
        func postEmptyBodyProducesEmptyData() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(),
                contentType: "application/octet-stream"
            )

            #expect(capture.data != nil)
            #expect(capture.data?.isEmpty == true)
        }

        @Test("POST large data (1 MB) is captured completely")
        func postLargeDataIsCapturedCompletely() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let size = 1_048_576
            var bytes = [UInt8](repeating: 0, count: size)
            for i in 0..<size {
                bytes[i] = UInt8(i % 256)
            }
            let sentData = Data(bytes)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data?.count == size)
            #expect(capture.data == sentData)
        }

        @Test("POST binary data preserves exact bytes")
        func postBinaryDataPreservesExactBytes() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            var bytes = [UInt8](repeating: 0, count: 256)
            for i in 0..<256 {
                bytes[i] = UInt8(i)
            }
            let sentData = Data(bytes)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data == sentData)
        }

        @Test(
            "POST data with various sizes is captured correctly",
            arguments: [1, 10, 100, 1000, 10000, 100_000]
        )
        func postDataWithVariousSizesIsCapturedCorrectly(size: Int) async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentData = Data(repeating: 0xAB, count: size)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data?.count == size)
            #expect(capture.data == sentData)
        }

        @Test("contentLength matches the size of the sent data")
        func contentLengthMatchesSentDataSize() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentData = Data("Measure this".utf8)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "text/plain"
            )

            #expect(capture.contentLength == UInt(sentData.count))
        }

        @Test("request method is POST")
        func requestMethodIsPOST() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data("test".utf8),
                contentType: "text/plain"
            )

            #expect(capture.method == "POST")
        }

        @Test("request path matches the handler path")
        func requestPathMatchesHandlerPath() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data("test".utf8),
                contentType: "text/plain"
            )

            #expect(capture.path == "/data")
        }
    }

    // MARK: - Text Property (Integration)

    @Suite("Text property via integration", .serialized, .tags(.integration))
    struct TextProperty {
        @Test("POST with text/plain content type produces non-nil text matching the sent string")
        func postTextPlainProducesMatchingText() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentString = "Hello, text!"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(sentString.utf8),
                contentType: "text/plain"
            )

            #expect(capture.text != nil)
            #expect(capture.text == sentString)
        }

        @Test("POST with text/html content type produces non-nil text")
        func postTextHTMLProducesNonNilText() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let html = "<h1>Hello</h1>"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(html.utf8),
                contentType: "text/html"
            )

            #expect(capture.text != nil)
            #expect(capture.text == html)
        }

        @Test("POST with text/plain and charset=utf-8 decodes correctly")
        func postTextPlainWithCharsetUTF8DecodesCorrectly() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentString = "UTF-8 encoded text"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(sentString.utf8),
                contentType: "text/plain; charset=utf-8"
            )

            #expect(capture.text != nil)
            #expect(capture.text == sentString)
        }

        @Test("POST UTF-8 text with emoji decodes correctly")
        func postUTF8TextWithEmojiDecodesCorrectly() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentString = "Hello \u{1F30D}\u{1F680}\u{2764}\u{FE0F} World"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(sentString.utf8),
                contentType: "text/plain; charset=utf-8"
            )

            #expect(capture.text != nil)
            #expect(capture.text == sentString)
        }

        @Test("POST with text/plain and charset=iso-8859-1 decodes correctly")
        func postTextPlainWithCharsetISO88591DecodesCorrectly() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let encoding = String.Encoding.isoLatin1
            let sentString = "caf\u{00E9}"
            guard let encodedData = sentString.data(using: encoding) else {
                Issue.record("Failed to encode string as ISO-8859-1")
                return
            }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: encodedData,
                contentType: "text/plain; charset=iso-8859-1"
            )

            #expect(capture.text != nil)
            #expect(capture.text == sentString)
        }

        @Test("POST with text/css produces non-nil text")
        func postTextCSSProducesNonNilText() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let css = "body { color: red; }"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(css.utf8),
                contentType: "text/css"
            )

            #expect(capture.text != nil)
            #expect(capture.text == css)
        }

        @Test("POST empty text body with text/plain produces empty text string")
        func postEmptyTextBodyProducesEmptyString() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(),
                contentType: "text/plain"
            )

            #expect(capture.text != nil)
            #expect(capture.text == "")
        }

        @Test(
            "POST with various text/ subtypes produces non-nil text",
            arguments: [
                "text/plain",
                "text/html",
                "text/css",
                "text/csv",
                "text/xml",
            ]
        )
        func postWithVariousTextSubtypesProducesNonNilText(contentType: String) async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentString = "content for \(contentType)"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(sentString.utf8),
                contentType: contentType
            )

            #expect(capture.text != nil)
            #expect(capture.text == sentString)
        }

        @Test("POST with multibyte CJK characters decodes correctly")
        func postMultibyteCJKCharactersDecodesCorrectly() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentString = "\u{4F60}\u{597D}\u{4E16}\u{754C}"
            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data(sentString.utf8),
                contentType: "text/plain; charset=utf-8"
            )

            #expect(capture.text != nil)
            #expect(capture.text == sentString)
        }
    }

    // MARK: - JSON Object Property (Integration)

    @Suite("JSON object property via integration", .serialized, .tags(.integration))
    struct JSONObjectProperty {
        @Test("POST JSON dictionary with application/json produces NSDictionary")
        func postJSONDictionaryProducesNSDictionary() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let dict: [String: Any] = ["name": "Dominic", "active": true, "score": 42]
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "application/json"
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            #expect(resultDict != nil)
            #expect(resultDict?["name"] as? String == "Dominic")
            #expect(resultDict?["active"] as? Bool == true)
            #expect(resultDict?["score"] as? Int == 42)
        }

        @Test("POST JSON array with application/json produces NSArray")
        func postJSONArrayProducesNSArray() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let array: [Any] = [1, "two", 3.0, true]
            let jsonData = try JSONSerialization.data(withJSONObject: array, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "application/json"
            )

            #expect(capture.jsonObject != nil)

            let resultArray = capture.jsonObject as? NSArray
            #expect(resultArray != nil)
            #expect(resultArray?.count == 4)
        }

        @Test("POST with text/json content type produces valid jsonObject")
        func postTextJSONProducesValidJSONObject() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let dict: [String: Any] = ["key": "value"]
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "text/json"
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            #expect(resultDict?["key"] as? String == "value")
        }

        @Test("POST with text/javascript content type produces valid jsonObject")
        func postTextJavascriptProducesValidJSONObject() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let dict: [String: Any] = ["js": true]
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "text/javascript"
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            #expect(resultDict?["js"] as? Bool == true)
        }

        @Test("POST nested JSON object is fully parsed")
        func postNestedJSONObjectIsFullyParsed() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let nested: [String: Any] = [
                "user": [
                    "name": "Dominic",
                    "tags": ["swift", "objc"],
                    "meta": ["active": true, "score": 42],
                ] as [String: Any],
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: nested, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "application/json"
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            let user = resultDict?["user"] as? NSDictionary
            #expect(user?["name"] as? String == "Dominic")

            let tags = user?["tags"] as? NSArray
            #expect(tags?.count == 2)
            #expect(tags?[0] as? String == "swift")
            #expect(tags?[1] as? String == "objc")
        }

        @Test("POST empty JSON object produces empty NSDictionary")
        func postEmptyJSONObjectProducesEmptyDictionary() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let jsonData = Data("{}".utf8)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "application/json"
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            #expect(resultDict != nil)
            #expect(resultDict?.count == 0)
        }

        @Test("POST empty JSON array produces empty NSArray")
        func postEmptyJSONArrayProducesEmptyArray() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let jsonData = Data("[]".utf8)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "application/json"
            )

            #expect(capture.jsonObject != nil)

            let resultArray = capture.jsonObject as? NSArray
            #expect(resultArray != nil)
            #expect(resultArray?.count == 0)
        }

        @Test("POST invalid JSON with application/json produces nil jsonObject")
        func postInvalidJSONProducesNilJSONObject() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let invalidJSON = Data("this is not json {{{".utf8)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: invalidJSON,
                contentType: "application/json"
            )

            #expect(capture.jsonObject == nil)
        }

        @Test("POST JSON with unicode keys and values parses correctly")
        func postJSONWithUnicodeKeysAndValuesParses() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let dict: [String: Any] = ["\u{1F600}": "\u{1F30D}", "caf\u{00E9}": "latt\u{00E9}"]
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: "application/json"
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            #expect(resultDict?["\u{1F600}"] as? String == "\u{1F30D}")
            #expect(resultDict?["caf\u{00E9}"] as? String == "latt\u{00E9}")
        }

        @Test(
            "POST JSON with accepted content types produces valid jsonObject",
            arguments: [
                "application/json",
                "text/json",
                "text/javascript",
            ]
        )
        func postJSONWithAcceptedContentTypesProducesValidObject(contentType: String) async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let dict: [String: Any] = ["type": contentType]
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: jsonData,
                contentType: contentType
            )

            #expect(capture.jsonObject != nil)

            let resultDict = capture.jsonObject as? NSDictionary
            #expect(resultDict?["type"] as? String == contentType)
        }
    }

    // MARK: - Edge Cases (Integration)

    @Suite("Edge cases via integration", .serialized, .tags(.integration))
    struct EdgeCases {
        @Test("multiple sequential requests to the same handler each capture correctly")
        func multipleSequentialRequestsCaptureCorrectly() async throws {
            let server = DZWebServer()
            var capturedValues: [Data] = []
            let lock = NSLock()

            server.addHandler(
                forMethod: "POST",
                path: "/data",
                request: DZWebServerDataRequest.self
            ) { request -> DZWebServerResponse? in
                let dataRequest = request as! DZWebServerDataRequest
                lock.lock()
                capturedValues.append(dataRequest.data as Data)
                lock.unlock()
                return DZWebServerDataResponse(text: "OK")
            }

            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            defer { server.stop() }

            let baseURL = try #require(URL(string: "http://localhost:\(server.port)"))

            let messages = ["first", "second", "third"]
            for message in messages {
                try await sendPOST(
                    to: baseURL.appendingPathComponent("/data"),
                    body: Data(message.utf8),
                    contentType: "text/plain"
                )
            }

            #expect(capturedValues.count == 3)
            #expect(capturedValues[0] == Data("first".utf8))
            #expect(capturedValues[1] == Data("second".utf8))
            #expect(capturedValues[2] == Data("third".utf8))
        }

        @Test("POST binary data with null bytes is preserved")
        func postBinaryDataWithNullBytesIsPreserved() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentData = Data([0x00, 0x01, 0x00, 0xFF, 0x00, 0xFE])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data == sentData)
            #expect(capture.data?.count == 6)
        }

        @Test("POST data with all byte values (0x00 to 0xFF) is preserved")
        func postAllByteValuesPreserved() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            var bytes = [UInt8]()
            for i in 0...255 {
                bytes.append(UInt8(i))
            }
            let sentData = Data(bytes)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data == sentData)
            #expect(capture.data?.count == 256)
        }

        @Test("data property returns non-nil Data even for non-text content types")
        func dataPropertyReturnsNonNilForNonTextContentTypes() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: pngHeader,
                contentType: "image/png"
            )

            #expect(capture.data != nil)
            #expect(capture.data == pngHeader)
        }

        @Test("POST very large data (2 MB) is captured without truncation")
        func postVeryLargeDataIsCapturedWithoutTruncation() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let size = 2_097_152
            var bytes = [UInt8](repeating: 0, count: size)
            for i in 0..<size {
                bytes[i] = UInt8(truncatingIfNeeded: i &* 7 &+ 13)
            }
            let sentData = Data(bytes)

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data?.count == size)
            #expect(capture.data == sentData)
        }

        @Test("contentType on the request matches the Content-Type header sent by the client")
        func contentTypeMatchesSentHeader() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data("test".utf8),
                contentType: "application/xml"
            )

            #expect(capture.contentType == "application/xml")
        }

        @Test(
            "contentType is preserved for various MIME types",
            arguments: [
                "application/octet-stream",
                "application/json",
                "text/plain",
                "text/html",
                "text/css",
                "image/png",
                "audio/mpeg",
            ]
        )
        func contentTypeIsPreservedForVariousMIMETypes(contentType: String) async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: Data("x".utf8),
                contentType: contentType
            )

            #expect(capture.contentType == contentType)
        }

        @Test("POST single byte body is captured")
        func postSingleByteBodyIsCaptured() async throws {
            let (server, baseURL, capture) = try makeServerCapturingDataRequest()
            defer { server.stop() }

            let sentData = Data([0x42])

            try await sendPOST(
                to: baseURL.appendingPathComponent("/data"),
                body: sentData,
                contentType: "application/octet-stream"
            )

            #expect(capture.data == sentData)
            #expect(capture.data?.count == 1)
        }
    }
}
