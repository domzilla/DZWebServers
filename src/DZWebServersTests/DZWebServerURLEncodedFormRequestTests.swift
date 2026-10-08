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

// MARK: Helpers

/// The handler runs on a GCD thread, hence `@unchecked Sendable`. Each request is appended before its response is
/// sent, so reads after the response has arrived are ordered.
private final class FormRequestLog: @unchecked Sendable {
    var requests: [DZWebServerURLEncodedFormRequest] = []
}

/// Posts each body in turn to one server at `/form` and returns the parsed requests in order.
private func submitForms(_ bodies: [String]) async throws -> [DZWebServerURLEncodedFormRequest] {
    let server = DZWebServer()
    let log = FormRequestLog()
    server.addHandler(
        forMethod: "POST",
        path: "/form",
        request: DZWebServerURLEncodedFormRequest.self
    ) { request -> DZWebServerResponse? in
        if let formRequest = request as? DZWebServerURLEncodedFormRequest {
            log.requests.append(formRequest)
        }
        return DZWebServerDataResponse(text: "OK")
    }
    try TestSupport.start(server)
    defer { server.stop() }

    let url = try #require(URL(string: "http://localhost:\(server.port)/form"))
    for body in bodies {
        let result = try await TestSupport.sendRequest(
            method: "POST",
            url: url,
            body: Data(body.utf8),
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
        #expect(result.statusCode == 200)
    }
    try #require(log.requests.count == bodies.count)
    return log.requests
}

private func submitForm(_ body: String) async throws -> DZWebServerURLEncodedFormRequest {
    try await submitForms([body])[0]
}

// MARK: Root Suite

@Suite("DZWebServerURLEncodedFormRequest", .serialized, .tags(.request, .encoding, .integration))
struct DZWebServerURLEncodedFormRequestTests {
    // MARK: Class Method

    @Suite("Class method mimeType")
    struct MimeType {
        @Test("mimeType returns application/x-www-form-urlencoded")
        func mimeTypeReturnsCorrectValue() {
            #expect(DZWebServerURLEncodedFormRequest.mimeType() == "application/x-www-form-urlencoded")
        }
    }

    // MARK: Basic Form Parsing

    @Suite("Basic form parsing via integration")
    struct BasicFormParsing {
        @Test("Single key-value pair is parsed")
        func singleKeyValuePairParsedCorrectly() async throws {
            let request = try await submitForm("name=John")

            #expect(request.arguments == ["name": "John"])
        }

        @Test("Multiple key-value pairs are parsed")
        func multipleKeyValuePairsParsedCorrectly() async throws {
            let request = try await submitForm("name=John&age=30&city=Berlin")

            #expect(request.arguments == ["name": "John", "age": "30", "city": "Berlin"])
        }

        @Test("Sequential requests on one server are parsed independently")
        func sequentialRequestsAreIndependent() async throws {
            let requests = try await submitForms(["round=1", "round=2", "round=3&extra=yes"])

            #expect(requests.map(\.arguments) == [
                ["round": "1"],
                ["round": "2"],
                ["round": "3", "extra": "yes"],
            ])
        }
    }

    // MARK: URL Encoding and Decoding

    @Suite("URL encoding and decoding")
    struct URLEncodingDecoding {
        @Test("Encoded keys and values are decoded", arguments: [
            ("greeting=Hello%20World", "greeting", "Hello World"),
            ("greeting=Hello+World", "greeting", "Hello World"),
            ("first+name=John", "first name", "John"),
            ("my%20key=my%20value", "my key", "my value"),
            ("genre=rock%26roll", "genre", "rock&roll"),
            ("equation=a%3Db", "equation", "a=b"),
            ("word=caf%C3%A9", "word", "caf\u{00E9}"),
            ("text=%E4%BD%A0%E5%A5%BD", "text", "\u{4F60}\u{597D}"),
            ("space=%20test", "space", " test"),
            ("at=hello%40world", "at", "hello@world"),
            ("hash=tag%23value", "hash", "tag#value"),
            ("slash=a%2Fb", "slash", "a/b"),
            ("question=what%3F", "question", "what?"),
        ])
        func encodedPairIsDecoded(body: String, key: String, value: String) async throws {
            let request = try await submitForm(body)

            #expect(request.arguments == [key: value])
        }

        @Test("All printable ASCII characters survive percent-encoding")
        func allPrintableASCIIInValue() async throws {
            let printableASCII = String((32...126).map { Character(UnicodeScalar($0)) })
            let encoded = try #require(printableASCII.addingPercentEncoding(withAllowedCharacters: CharacterSet()))

            let request = try await submitForm("chars=\(encoded)")

            #expect(request.arguments["chars"] == printableASCII)
        }
    }

    // MARK: Edge Cases

    @Suite("Edge cases")
    struct EdgeCases {
        @Test("Empty form body results in empty arguments")
        func emptyFormBodyProducesEmptyArguments() async throws {
            let request = try await submitForm("")

            #expect(request.arguments.isEmpty)
        }

        @Test("Key with empty value parses as empty string")
        func keyWithEmptyValue() async throws {
            let request = try await submitForm("key=")

            #expect(request.arguments == ["key": ""])
        }

        @Test("Duplicate keys resolve to the last value")
        func duplicateKeysResolveToLastValue() async throws {
            let request = try await submitForm("color=red&color=blue&color=green")

            #expect(request.arguments == ["color": "green"])
        }

        @Test("Value containing a literal equals sign splits only on the first equals")
        func valueContainingEqualsSignSplitsOnFirstOnly() async throws {
            let request = try await submitForm("equation=x=1+2")

            #expect(request.arguments == ["equation": "x=1 2"])
        }

        @Test("Trailing ampersand does not create an extra entry")
        func trailingAmpersandDoesNotCreateExtraEntry() async throws {
            let request = try await submitForm("a=1&b=2&")

            #expect(request.arguments == ["a": "1", "b": "2"])
        }

        @Test("Leading and consecutive ampersands are skipped", arguments: ["&a=1&b=2", "a=1&&&&b=2"])
        func emptySequencesAreSkipped(body: String) async throws {
            let request = try await submitForm(body)

            #expect(request.arguments == ["a": "1", "b": "2"])
        }

        @Test("Empty key is parsed and does not drop the following pairs")
        func emptyKeyIsParsed() async throws {
            let request = try await submitForm("=value&a=1")

            #expect(request.arguments == ["": "value", "a": "1"])
        }

        @Test("10,000 character value is preserved in full")
        func veryLongValuePreserved() async throws {
            let longValue = String(repeating: "x", count: 10000)

            let request = try await submitForm("big=\(longValue)")

            #expect(request.arguments["big"] == longValue)
        }

        @Test("100 key-value pairs are all preserved")
        func manyKeyValuePairsAllPreserved() async throws {
            let pairs = (0..<100).map { ("key\($0)", "value\($0)") }
            let body = pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "&")

            let request = try await submitForm(body)

            #expect(request.arguments == Dictionary(uniqueKeysWithValues: pairs))
        }
    }

    // MARK: Inherited Properties

    /// `text` is not tested: application/x-www-form-urlencoded is not text/*, and reading `text` then hits
    /// DWS_DNOT_REACHED() (abort() in DEBUG).
    @Suite("Inherited properties from DZWebServerDataRequest")
    struct InheritedProperties {
        @Test("Data request properties reflect the submitted form")
        func dataRequestPropertiesReflectForm() async throws {
            let body = "name=John&age=30"

            let request = try await submitForm(body)

            #expect(request.data == Data(body.utf8))
            #expect(request.contentType == "application/x-www-form-urlencoded")
            #expect(request.contentLength == UInt(body.utf8.count))
            #expect(request.method == "POST")
            #expect(request.path == "/form")
            #expect(request.hasBody())
        }
    }
}
