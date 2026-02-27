//
//  DZWebServerURLEncodedFormRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

// MARK: - Sendable Capture Helper

/// Thread-safe container used to capture request properties inside server handler blocks.
private final class RequestCapture: @unchecked Sendable {
    var arguments: [String: String]?
    var rawData: Data?
    var contentType: String?
    var contentLength: UInt = 0
    var method: String?
    var path: String?
    var hasBody: Bool = false
}

// MARK: - Server Helpers

/// Creates a `DZWebServer` bound to localhost on a random port with the given handler,
/// starts it, and returns the server. The caller is responsible for calling `stop()`.
private func makeFormServer(
    path: String = "/form",
    handler: @escaping (DZWebServerURLEncodedFormRequest) -> DZWebServerResponse?
) throws
    -> DZWebServer
{
    let server = DZWebServer()
    server.addHandler(
        forMethod: "POST",
        path: path,
        request: DZWebServerURLEncodedFormRequest.self
    ) { request in
        let formRequest = request as! DZWebServerURLEncodedFormRequest
        return handler(formRequest)
    }
    let options: [String: Any] = [
        DZWebServerOption_Port: 0,
        DZWebServerOption_BindToLocalhost: true,
    ]
    try server.start(options: options)
    return server
}

/// Sends a POST request with the given URL-encoded body string to the server.
private func sendFormRequest(
    to server: DZWebServer,
    path: String = "/form",
    body: String,
    contentType: String = "application/x-www-form-urlencoded"
) async throws
    -> (Data, HTTPURLResponse)
{
    let baseURL = URL(string: "http://localhost:\(server.port)")!
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body.data(using: .utf8)
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, response as! HTTPURLResponse)
}

// MARK: - Root Suite

@Suite("DZWebServerURLEncodedFormRequest", .serialized, .tags(.request, .encoding, .integration))
struct DZWebServerURLEncodedFormRequestTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Class Method

    @Suite("Class method mimeType")
    struct MimeType {
        @Test("mimeType returns application/x-www-form-urlencoded")
        func mimeTypeReturnsCorrectValue() {
            let mimeType = DZWebServerURLEncodedFormRequest.mimeType()

            #expect(mimeType == "application/x-www-form-urlencoded")
        }

        @Test("mimeType returns a non-empty string")
        func mimeTypeReturnsNonEmptyString() {
            let mimeType = DZWebServerURLEncodedFormRequest.mimeType()

            #expect(!mimeType.isEmpty)
        }

        @Test("mimeType is stable across repeated calls")
        func mimeTypeIsStable() {
            let first = DZWebServerURLEncodedFormRequest.mimeType()
            let second = DZWebServerURLEncodedFormRequest.mimeType()

            #expect(first == second)
        }
    }

    // MARK: - Basic Form Parsing

    @Suite("Basic form parsing via integration")
    struct BasicFormParsing {
        @Test("Single key-value pair is parsed into arguments with one entry")
        func singleKeyValuePairParsedCorrectly() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let (_, response) = try await sendFormRequest(to: server, body: "name=John")

            #expect(response.statusCode == 200)
            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?["name"] == "John")
        }

        @Test("Multiple key-value pairs are parsed into arguments with correct count")
        func multipleKeyValuePairsParsedCorrectly() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let (_, response) = try await sendFormRequest(to: server, body: "name=John&age=30&city=Berlin")

            #expect(response.statusCode == 200)
            #expect(capture.arguments?.count == 3)
            #expect(capture.arguments?["name"] == "John")
            #expect(capture.arguments?["age"] == "30")
            #expect(capture.arguments?["city"] == "Berlin")
        }

        @Test("Keys and values are correctly paired in the arguments dictionary")
        func keysAndValuesCorrectlyPaired() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "first=Alice&last=Smith")

            #expect(capture.arguments?["first"] == "Alice")
            #expect(capture.arguments?["last"] == "Smith")
            // Ensure keys are not swapped
            #expect(capture.arguments?["first"] != "Smith")
            #expect(capture.arguments?["last"] != "Alice")
        }
    }

    // MARK: - URL Encoding / Decoding

    @Suite("URL encoding and decoding")
    struct URLEncodingDecoding {
        @Test("Percent-encoded values are properly decoded")
        func percentEncodedValuesDecoded() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // "Hello World" encoded as "Hello%20World"
            _ = try await sendFormRequest(to: server, body: "greeting=Hello%20World")

            #expect(capture.arguments?["greeting"] == "Hello World")
        }

        @Test("Plus sign is decoded to space in values")
        func plusSignDecodedToSpace() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "greeting=Hello+World")

            #expect(capture.arguments?["greeting"] == "Hello World")
        }

        @Test("Plus sign is decoded to space in keys")
        func plusSignDecodedToSpaceInKeys() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "first+name=John")

            #expect(capture.arguments?["first name"] == "John")
        }

        @Test("Encoded ampersand %26 in a value does not split the pair")
        func encodedAmpersandInValueDoesNotSplit() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // "rock&roll" encoded as "rock%26roll"
            _ = try await sendFormRequest(to: server, body: "genre=rock%26roll")

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?["genre"] == "rock&roll")
        }

        @Test("Encoded equals sign %3D in a value does not split the pair")
        func encodedEqualsInValueDoesNotSplit() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // "a=b" encoded as "a%3Db"
            _ = try await sendFormRequest(to: server, body: "equation=a%3Db")

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?["equation"] == "a=b")
        }

        @Test("Percent-encoded Unicode characters are properly decoded")
        func percentEncodedUnicodeDecoded() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // "cafe" with accent: "caf%C3%A9"
            _ = try await sendFormRequest(to: server, body: "word=caf%C3%A9")

            #expect(capture.arguments?["word"] == "caf\u{00E9}")
        }

        @Test("CJK characters encoded as percent sequences are properly decoded")
        func cjkCharactersDecoded() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // Chinese character for "hello" (nihao): %E4%BD%A0%E5%A5%BD
            _ = try await sendFormRequest(to: server, body: "text=%E4%BD%A0%E5%A5%BD")

            #expect(capture.arguments?["text"] == "\u{4F60}\u{597D}")
        }

        @Test(
            "Various percent-encoded special characters are decoded correctly",
            arguments: [
                ("space=%20test", "space", " test"),
                ("at=hello%40world", "at", "hello@world"),
                ("hash=tag%23value", "hash", "tag#value"),
                ("slash=a%2Fb", "slash", "a/b"),
                ("question=what%3F", "question", "what?"),
            ]
        )
        func variousEncodedSpecialCharactersDecoded(body: String, key: String, expected: String) async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: body)

            #expect(capture.arguments?[key] == expected)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge cases")
    struct EdgeCases {
        @Test("Empty form body results in empty arguments dictionary")
        func emptyFormBodyProducesEmptyArguments() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let (_, response) = try await sendFormRequest(to: server, body: "")

            #expect(response.statusCode == 200)
            #expect(capture.arguments != nil)
            #expect(capture.arguments?.isEmpty == true)
        }

        @Test("Key with empty value parses correctly")
        func keyWithEmptyValue() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "key=")

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?["key"] == "")
        }

        @Test("Empty key with a value is not parsed (parser cannot handle empty keys)")
        func emptyKeyWithValue() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "=value")

            // NSScanner's scanUpToString:@"=" returns NO when the very first
            // character is "=", so the parser breaks immediately with an empty dict.
            #expect(capture.arguments?.isEmpty == true)
        }

        @Test("Duplicate keys resolve to the last value")
        func duplicateKeysResolveToLastValue() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "color=red&color=blue&color=green")

            #expect(capture.arguments?.count == 1)
            #expect(capture.arguments?["color"] == "green")
        }

        @Test("Key with spaces encoded as plus signs is decoded correctly")
        func keyWithSpacesEncodedAsPlus() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "my+key=my+value")

            #expect(capture.arguments?["my key"] == "my value")
        }

        @Test("Key with spaces encoded as %20 is decoded correctly")
        func keyWithSpacesEncodedAsPercent20() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "my%20key=my%20value")

            #expect(capture.arguments?["my key"] == "my value")
        }

        @Test("Very long value is preserved in full")
        func veryLongValuePreserved() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let longValue = String(repeating: "x", count: 10000)
            let (_, response) = try await sendFormRequest(to: server, body: "big=\(longValue)")

            #expect(response.statusCode == 200)
            #expect(capture.arguments?["big"] == longValue)
            #expect(capture.arguments?["big"]?.count == 10000)
        }

        @Test("Many key-value pairs are all preserved")
        func manyKeyValuePairsAllPreserved() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let count = 100
            let body = (0..<count).map { "key\($0)=value\($0)" }.joined(separator: "&")
            let (_, response) = try await sendFormRequest(to: server, body: body)

            #expect(response.statusCode == 200)
            #expect(capture.arguments?.count == count)
            for i in 0..<count {
                #expect(capture.arguments?["key\(i)"] == "value\(i)")
            }
        }

        @Test("Trailing ampersand does not create an extra entry")
        func trailingAmpersandDoesNotCreateExtraEntry() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "a=1&b=2&")

            #expect(capture.arguments?["a"] == "1")
            #expect(capture.arguments?["b"] == "2")
        }

        @Test("Leading ampersand is included in the first key by the NSScanner-based parser")
        func leadingAmpersandIncludedInFirstKey() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "&a=1&b=2")

            // The NSScanner-based parser does not skip a leading &;
            // it includes it in the first key. Subsequent & delimiters
            // between pairs are consumed normally.
            #expect(capture.arguments?.count == 2)
            #expect(capture.arguments?["&a"] == "1")
            #expect(capture.arguments?["b"] == "2")
        }

        @Test("Consecutive ampersands are included in subsequent keys by the parser")
        func consecutiveAmpersandsIncludedInKeys() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "a=1&&&&b=2")

            // The NSScanner-based parser does not skip consecutive & delimiters;
            // they are included in the next key.
            #expect(capture.arguments?.count == 2)
            #expect(capture.arguments?["a"] == "1")
            #expect(capture.arguments?["&&&b"] == "2")
        }

        @Test("Value containing literal equals sign splits only on first equals")
        func valueContainingEqualsSignSplitsOnFirstOnly() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // "equation=x=1+2" should parse as key="equation", value="x=1+2"
            _ = try await sendFormRequest(to: server, body: "equation=x=1+2")

            #expect(capture.arguments?["equation"] == "x=1 2")
        }

        @Test("Numeric-only keys and values are parsed as strings")
        func numericKeysAndValues() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "123=456")

            #expect(capture.arguments?["123"] == "456")
        }
    }

    // MARK: - Inherited Properties

    @Suite("Inherited properties from DZWebServerDataRequest")
    struct InheritedProperties {
        @Test("data property contains the raw form body bytes")
        func dataPropertyContainsRawFormBody() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.rawData = request.data as Data
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let bodyString = "name=John&age=30"
            _ = try await sendFormRequest(to: server, body: bodyString)

            let expectedData = bodyString.data(using: .utf8)
            #expect(capture.rawData == expectedData)
        }

        @Test("contentType property reflects the form-urlencoded MIME type")
        func contentTypeReflectsFormURLEncoded() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.contentType = request.contentType
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "key=value")

            #expect(capture.contentType == "application/x-www-form-urlencoded")
        }

        @Test("method property is POST for form submissions")
        func methodPropertyIsPOST() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.method = request.method
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "key=value")

            #expect(capture.method == "POST")
        }

        @Test("path property matches the registered handler path")
        func pathPropertyMatchesHandlerPath() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer(path: "/submit") { request in
                capture.path = request.path
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, path: "submit", body: "key=value")

            #expect(capture.path == "/submit")
        }

        @Test("hasBody returns true for a form request with a body")
        func hasBodyReturnsTrueForFormRequest() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.hasBody = request.hasBody()
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            _ = try await sendFormRequest(to: server, body: "key=value")

            #expect(capture.hasBody == true)
        }

        @Test("contentLength matches the byte length of the form body")
        func contentLengthMatchesByteLength() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.contentLength = request.contentLength
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let bodyString = "name=John&age=30"
            let expectedLength = try #require(bodyString.data(using: .utf8)?.count)
            _ = try await sendFormRequest(to: server, body: bodyString)

            #expect(capture.contentLength == UInt(expectedLength))
        }

        // NOTE: .text property cannot be tested here because
        // "application/x-www-form-urlencoded" does not have a "text/" prefix,
        // and accessing .text on a non-text content type triggers
        // DWS_DNOT_REACHED() → abort() in DEBUG builds.
    }

    // MARK: - Server Round-Trip Integration

    @Suite("Server round-trip integration")
    struct ServerRoundTrip {
        @Test("Server responds with 200 for a valid form POST")
        func serverRespondsWithOKForValidFormPost() async throws {
            let server = try makeFormServer { _ in
                DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            let (data, response) = try await sendFormRequest(to: server, body: "status=active")

            #expect(response.statusCode == 200)
            let responseText = String(data: data, encoding: .utf8)
            #expect(responseText == "OK")
        }

        @Test("Handler can echo back form arguments as JSON")
        func handlerCanEchoBackFormArgumentsAsJSON() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/echo",
                request: DZWebServerURLEncodedFormRequest.self
            ) { request in
                let formRequest = request as! DZWebServerURLEncodedFormRequest
                return DZWebServerDataResponse(jsonObject: formRequest.arguments)
            }
            let options: [String: Any] = [
                DZWebServerOption_Port: 0,
                DZWebServerOption_BindToLocalhost: true,
            ]
            try server.start(options: options)
            defer { server.stop() }

            let (data, response) = try await sendFormRequest(to: server, path: "echo", body: "color=blue&size=large")

            #expect(response.statusCode == 200)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
            #expect(json?["color"] == "blue")
            #expect(json?["size"] == "large")
        }

        @Test("Multiple sequential requests are handled independently")
        func multipleSequentialRequestsAreIndependent() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // First request
            let (_, response1) = try await sendFormRequest(to: server, body: "round=1")
            #expect(response1.statusCode == 200)
            #expect(capture.arguments?["round"] == "1")

            // Second request with different data
            let (_, response2) = try await sendFormRequest(to: server, body: "round=2")
            #expect(response2.statusCode == 200)
            #expect(capture.arguments?["round"] == "2")

            // Third request with multiple fields
            let (_, response3) = try await sendFormRequest(to: server, body: "round=3&extra=yes")
            #expect(response3.statusCode == 200)
            #expect(capture.arguments?["round"] == "3")
            #expect(capture.arguments?["extra"] == "yes")
        }

        @Test("Form with all printable ASCII characters as a value parses correctly")
        func allPrintableASCIIInValue() async throws {
            let capture = RequestCapture()
            let server = try makeFormServer { request in
                capture.arguments = request.arguments as? [String: String]
                return DZWebServerDataResponse(text: "OK")
            }
            defer { server.stop() }

            // Build a percent-encoded string of all printable ASCII (32..126)
            let printableASCII = String((32...126).map { Character(UnicodeScalar($0)) })
            let encoded = try #require(printableASCII.addingPercentEncoding(withAllowedCharacters: CharacterSet()))
            let (_, response) = try await sendFormRequest(to: server, body: "chars=\(encoded)")

            #expect(response.statusCode == 200)
            #expect(capture.arguments?["chars"] == printableASCII)
        }
    }
}
