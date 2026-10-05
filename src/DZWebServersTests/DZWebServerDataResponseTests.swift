//
//  DZWebServerDataResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

@Suite("DZWebServerDataResponse", .serialized, .tags(.response))
struct DZWebServerDataResponseTests {
    // MARK: Data Response

    @Suite("Data response")
    struct DataResponse {
        @Test("initWithData sets content type, length, status code and serves the data as body")
        func initWithDataSetsMetadataAndBody() throws {
            let data = Data((0...255).map { UInt8($0) })
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentType == "application/octet-stream")
            #expect(response.contentLength == 256)
            #expect(response.statusCode == 200)
            #expect(response.hasBody())
            #expect(try TestSupport.readBody(of: response) == data)
        }

        @Test("empty data still has a body with contentLength zero")
        func emptyDataHasEmptyBody() throws {
            let response = DZWebServerDataResponse(data: Data(), contentType: "application/octet-stream")

            #expect(response.contentLength == 0)
            #expect(response.hasBody())
            #expect(try TestSupport.readBody(of: response).isEmpty)
        }

        @Test("large data is served completely")
        func largeDataIsServedCompletely() throws {
            let data = Data((0..<1_048_576).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ 13) })
            let response = DZWebServerDataResponse(data: data, contentType: "application/octet-stream")

            #expect(response.contentLength == UInt(data.count))
            #expect(try TestSupport.readBody(of: response) == data)
        }
    }

    // MARK: Text Response

    @Suite("Text response")
    struct TextResponse {
        @Test(
            "initWithText serves UTF-8 bytes with a text/plain content type",
            arguments: [
                "Hello, world!",
                "",
                "Hej v\u{00E4}rlden! \u{1F30D}",
                "\u{4F60}\u{597D}\u{4E16}\u{754C}",
            ]
        )
        func initWithTextServesUTF8Bytes(text: String) throws {
            let response = try #require(DZWebServerDataResponse(text: text))

            #expect(response.contentType == "text/plain; charset=utf-8")
            #expect(response.contentLength == UInt(text.utf8.count))
            #expect(response.statusCode == 200)
            #expect(try TestSupport.readBody(of: response) == Data(text.utf8))
        }
    }

    // MARK: HTML Response

    @Suite("HTML response")
    struct HTMLResponse {
        @Test(
            "initWithHTML serves the HTML unchanged as UTF-8 with a text/html content type",
            arguments: [
                "<html><body><p>Hello</p></body></html>",
                "",
                "<p>&amp; &lt; &gt; &quot;</p>",
                "<p>\u{00E9}\u{00E8}\u{00EA}</p>",
            ]
        )
        func initWithHTMLServesHTMLUnchanged(html: String) throws {
            let response = try #require(DZWebServerDataResponse(html: html))

            #expect(response.contentType == "text/html; charset=utf-8")
            #expect(response.contentLength == UInt(html.utf8.count))
            #expect(response.statusCode == 200)
            #expect(try TestSupport.readBody(of: response) == Data(html.utf8))
        }
    }

    // MARK: HTML Template Response

    @Suite("HTML template response")
    struct HTMLTemplateResponse {
        @Test(
            "initWithHTMLTemplate substitutes %variables% and leaves unknown placeholders as-is",
            arguments: [
                (
                    "<h1>%title%</h1><p>%body%</p>",
                    ["title": "Welcome", "body": "Hello, world!"],
                    "<h1>Welcome</h1><p>Hello, world!</p>"
                ),
                ("<p>No placeholders here</p>", [:], "<p>No placeholders here</p>"),
                ("<h1>%title%</h1><p>%missing%</p>", ["title": "Found"], "<h1>Found</h1><p>%missing%</p>"),
                ("<p>%name% said hello to %name%</p>", ["name": "Alice"], "<p>Alice said hello to Alice</p>"),
                ("<p>%greeting%</p>", ["greeting": "\u{1F44B} Hola"], "<p>\u{1F44B} Hola</p>"),
            ] as [(String, [String: String], String)]
        )
        func initWithHTMLTemplateSubstitutesVariables(
            template: String,
            variables: [String: String],
            expectedHTML: String
        ) throws {
            let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebServerDataResponseTests")
            defer { try? FileManager.default.removeItem(atPath: directory) }
            let templatePath = (directory as NSString).appendingPathComponent("template.html")
            try template.write(toFile: templatePath, atomically: true, encoding: .utf8)

            let response = try #require(DZWebServerDataResponse(htmlTemplate: templatePath, variables: variables))

            #expect(response.contentType == "text/html; charset=utf-8")
            #expect(try TestSupport.readBody(of: response) == Data(expectedHTML.utf8))
        }
    }

    // MARK: JSON Response

    @Suite("JSON response")
    struct JSONResponse {
        @Test("initWithJSONObject serves the serialized dictionary as application/json")
        func initWithJSONObjectServesSerializedDictionary() throws {
            let response = try #require(DZWebServerDataResponse(jsonObject: ["key": "value"]))

            #expect(response.contentType == "application/json")
            #expect(response.statusCode == 200)
            let body = try TestSupport.readBody(of: response)
            #expect(response.contentLength == UInt(body.count))
            let object = try JSONSerialization.jsonObject(with: body) as? [String: String]
            #expect(object == ["key": "value"])
        }

        @Test("initWithJSONObject serializes nested objects")
        func initWithJSONObjectSerializesNestedObjects() throws {
            let nested: [String: Any] = ["user": ["name": "Dominic", "tags": ["swift", "objc"]]]
            let response = try #require(DZWebServerDataResponse(jsonObject: nested))

            let object = try #require(try JSONSerialization
                .jsonObject(with: TestSupport.readBody(of: response)) as? NSDictionary)
            #expect(object == nested as NSDictionary)
        }

        @Test("initWithJSONObject serializes arrays", arguments: [[], [1, 2, 3]] as [[Int]])
        func initWithJSONObjectSerializesArrays(array: [Int]) throws {
            let response = try #require(DZWebServerDataResponse(jsonObject: array))

            let object = try JSONSerialization.jsonObject(with: TestSupport.readBody(of: response)) as? [Int]
            #expect(object == array)
        }

        @Test("initWithJSONObject serializes an empty dictionary to {}")
        func initWithJSONObjectSerializesEmptyDictionary() throws {
            let response = try #require(DZWebServerDataResponse(jsonObject: [String: Any]()))

            #expect(try TestSupport.readBody(of: response) == Data("{}".utf8))
        }

        @Test(
            "initWithJSONObject with a custom content type uses the provided type",
            arguments: [
                "application/vnd.api+json",
                "application/ld+json",
                "application/problem+json",
            ]
        )
        func initWithJSONObjectUsesCustomContentType(contentType: String) throws {
            let response = try #require(DZWebServerDataResponse(jsonObject: ["status": "ok"], contentType: contentType))

            #expect(response.contentType == contentType)
            #expect(try TestSupport.readBody(of: response) == Data(#"{"status":"ok"}"#.utf8))
        }
    }
}
