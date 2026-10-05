//
//  DZWebServerFunctionsTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

/// Builds a date in GMT so the tests don't depend on the machine's time zone.
private func gmtDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0,
    _ second: Int = 0
) throws
    -> Date
{
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "GMT"))
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    return try #require(calendar.date(from: components))
}

@Suite("DZWebServerFunctions", .serialized, .tags(.functions))
struct DZWebServerFunctionsTests {
    // MARK: MIME Type

    @Suite("MIME Type Resolution", .tags(.mimeType))
    struct MIMETypeTests {
        @Test(
            "Returns correct MIME type for common extensions",
            arguments: [
                ("html", "text/html"),
                ("css", "text/css"),
                ("js", "text/javascript"),
                ("json", "application/json"),
                ("txt", "text/plain"),
                ("jpg", "image/jpeg"),
                ("jpeg", "image/jpeg"),
                ("png", "image/png"),
                ("gif", "image/gif"),
                ("pdf", "application/pdf"),
                ("xml", "application/xml"),
                ("zip", "application/zip"),
                ("mp4", "video/mp4"),
                ("svg", "image/svg+xml"),
            ]
        )
        func returnsCorrectMimeTypeForCommonExtensions(ext: String, expected: String) {
            #expect(DZWebServerGetMimeType(forExtension: ext, overrides: nil) == expected)
        }

        @Test(
            "Returns application/octet-stream for unknown or empty extensions",
            arguments: ["xyzzy", "zzz123", "", String(repeating: "a", count: 1000)]
        )
        func returnsOctetStreamForUnknownExtension(ext: String) {
            #expect(DZWebServerGetMimeType(forExtension: ext, overrides: nil) == "application/octet-stream")
        }

        @Test("Extension lookup is case-insensitive", arguments: ["HTML", "Html"])
        func extensionLookupIsCaseInsensitive(ext: String) {
            #expect(DZWebServerGetMimeType(forExtension: ext, overrides: nil) == "text/html")
        }

        @Test("Override dictionary takes precedence over built-in types")
        func overrideTakesPrecedence() {
            let overrides = ["html": "text/x-custom-html", "css": "text/x-custom-css"]

            #expect(DZWebServerGetMimeType(forExtension: "html", overrides: overrides) == "text/x-custom-html")
            #expect(DZWebServerGetMimeType(forExtension: "css", overrides: overrides) == "text/x-custom-css")
        }

        @Test("Override does not affect other extensions")
        func overrideDoesNotAffectOtherExtensions() {
            let overrides = ["html": "text/x-custom-html"]

            #expect(DZWebServerGetMimeType(forExtension: "json", overrides: overrides) == "application/json")
        }

        @Test("Empty overrides dictionary falls back to built-in types")
        func emptyOverridesFallsBackToBuiltInTypes() {
            #expect(DZWebServerGetMimeType(forExtension: "png", overrides: [:]) == "image/png")
        }
    }

    // MARK: URL Encoding

    @Suite("URL Encoding", .tags(.encoding))
    struct URLEncodingTests {
        @Test(
            "Escapes reserved, whitespace and non-ASCII characters",
            arguments: [
                (":", "%3A"),
                ("@", "%40"),
                ("/", "%2F"),
                ("?", "%3F"),
                ("&", "%26"),
                ("=", "%3D"),
                ("+", "%2B"),
                ("hello world", "hello%20world"),
                ("key=value&foo=bar baz", "key%3Dvalue%26foo%3Dbar%20baz"),
                ("cafe\u{0301}", "cafe%CC%81"),
                ("\u{1F600}", "%F0%9F%98%80"),
                ("", ""),
            ]
        )
        func escapesCharacters(input: String, expected: String) {
            #expect(DZWebServerEscapeURLString(input) == expected)
        }

        @Test("Does not escape unreserved ASCII characters")
        func doesNotEscapeUnreservedASCII() {
            let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

            #expect(DZWebServerEscapeURLString(unreserved) == unreserved)
        }
    }

    // MARK: URL Decoding

    @Suite("URL Decoding", .tags(.encoding))
    struct URLDecodingTests {
        @Test(
            "Unescapes percent-encoded characters",
            arguments: [
                ("%3A", ":"),
                ("%40", "@"),
                ("%2F", "/"),
                ("%2f", "/"),
                ("%3F", "?"),
                ("%26", "&"),
                ("%3D", "="),
                ("%2B", "+"),
                ("%20", " "),
                ("hello%20world%21", "hello world!"),
                ("caf%C3%A9", "caf\u{00E9}"),
                ("hello", "hello"),
                ("", ""),
            ]
        )
        func unescapesPercentEncodedCharacters(input: String, expected: String) {
            #expect(DZWebServerUnescapeURLString(input) == expected)
        }

        @Test(
            "Encode then decode restores the original string",
            arguments: [
                "hello world",
                "foo=bar&baz=qux",
                "https://example.com/path?q=1",
                "",
                "unicode: cafe\u{0301}",
            ]
        )
        func roundTripRestoresOriginal(input: String) throws {
            let encoded = try #require(DZWebServerEscapeURLString(input))

            #expect(DZWebServerUnescapeURLString(encoded) == input)
        }
    }

    // MARK: URL-Encoded Form Parsing

    @Suite("URL-Encoded Form Parsing", .tags(.encoding))
    struct URLEncodedFormParsingTests {
        @Test(
            "Parses form strings into key-value pairs",
            arguments: [
                ("name=John", ["name": "John"]),
                ("name=John&age=30&city=Berlin", ["name": "John", "age": "30", "city": "Berlin"]),
                ("greeting=hello+world", ["greeting": "hello world"]),
                ("my+key=value", ["my key": "value"]),
                ("path=%2Fhome%2Fuser", ["path": "/home/user"]),
                ("%6Eame=John", ["name": "John"]),
                ("", [:]),
                ("key=first&key=second&key=third", ["key": "third"]),
                ("key=", ["key": ""]),
                ("expr=a%3Db", ["expr": "a=b"]),
                ("q=%21%40%23%24%25", ["q": "!@#$%"]),
                (
                    "username=john%40example.com&password=p%40ss%26word&remember=true",
                    ["username": "john@example.com", "password": "p@ss&word", "remember": "true"]
                ),
            ] as [(String, [String: String])]
        )
        func parsesFormString(form: String, expected: [String: String]) {
            #expect(DZWebServerParseURLEncodedForm(form) == expected)
        }
    }

    // MARK: RFC 822 Date

    @Suite("RFC 822 Date Formatting and Parsing", .tags(.dateFormatting))
    struct RFC822DateTests {
        @Test(
            "Formats dates with the correct day of week and time",
            arguments: [
                ((2026, 2, 27, 12, 0, 0), "Fri, 27 Feb 2026 12:00:00 GMT"),
                ((2026, 3, 1, 0, 0, 0), "Sun, 01 Mar 2026 00:00:00 GMT"),
                ((2026, 1, 1, 0, 0, 0), "Thu, 01 Jan 2026 00:00:00 GMT"),
                ((2025, 12, 25, 23, 59, 59), "Thu, 25 Dec 2025 23:59:59 GMT"),
            ]
        )
        func formatsDate(
            components: (Int, Int, Int, Int, Int, Int),
            expected: String
        ) throws {
            let date = try gmtDate(
                components.0,
                components.1,
                components.2,
                components.3,
                components.4,
                components.5
            )

            #expect(DZWebServerFormatRFC822(date) == expected)
        }

        @Test("Parses a valid RFC 822 string")
        func parsesValidRFC822String() throws {
            #expect(try DZWebServerParseRFC822("Fri, 27 Feb 2026 12:00:00 GMT") == gmtDate(2026, 2, 27, 12))
        }

        @Test("Format then parse returns the same date")
        func roundTripFormatParse() throws {
            let date = try gmtDate(2025, 6, 15, 8, 30, 45)

            #expect(DZWebServerParseRFC822(DZWebServerFormatRFC822(date)) == date)
        }

        @Test(
            "Returns nil for invalid RFC 822 strings",
            arguments: ["not a date", "2026-02-27", "27 Feb 2026", "12345", ""]
        )
        func returnsNilForInvalidRFC822Strings(input: String) {
            #expect(DZWebServerParseRFC822(input) == nil)
        }
    }

    // MARK: ISO 8601 Date

    @Suite("ISO 8601 Date Formatting and Parsing", .tags(.dateFormatting))
    struct ISO8601DateTests {
        @Test(
            "Formats dates with a +00:00 offset",
            arguments: [
                ((2026, 2, 27, 12, 0, 0), "2026-02-27T12:00:00+00:00"),
                ((2026, 1, 1, 0, 0, 0), "2026-01-01T00:00:00+00:00"),
                ((2026, 12, 31, 23, 59, 59), "2026-12-31T23:59:59+00:00"),
            ]
        )
        func formatsDate(
            components: (Int, Int, Int, Int, Int, Int),
            expected: String
        ) throws {
            let date = try gmtDate(
                components.0,
                components.1,
                components.2,
                components.3,
                components.4,
                components.5
            )

            #expect(DZWebServerFormatISO8601(date) == expected)
        }

        @Test("Parses a valid ISO 8601 string")
        func parsesValidISO8601String() throws {
            #expect(try DZWebServerParseISO8601("2026-02-27T12:00:00+00:00") == gmtDate(2026, 2, 27, 12))
        }

        @Test("Format then parse returns the same date")
        func roundTripFormatParse() throws {
            let date = try gmtDate(2025, 6, 15, 8, 30, 45)

            #expect(DZWebServerParseISO8601(DZWebServerFormatISO8601(date)) == date)
        }

        @Test(
            "Returns nil for invalid or non-+00:00 ISO 8601 strings",
            arguments: [
                "not a date",
                "Fri, 27 Feb 2026 12:00:00 GMT",
                "2026/02/27 12:00:00",
                "2026-02-27",
                "12345",
                "",
                "2026-02-27T12:00:00+05:30",
                "2026-02-27T12:00:00Z",
            ]
        )
        func returnsNilForInvalidISO8601Strings(input: String) {
            #expect(DZWebServerParseISO8601(input) == nil)
        }
    }

    // MARK: Path Normalization

    @Suite("Path Normalization")
    struct PathNormalizationTests {
        @Test(
            "Normalizes paths",
            arguments: [
                ("/a/b/c", "/a/b/c"),
                ("/file.txt", "/file.txt"),
                ("/a/./b", "/a/b"),
                ("/a/./b/./c", "/a/b/c"),
                ("/./a", "/a"),
                ("/a/b/../c", "/a/c"),
                ("/a/b/c/../../d", "/a/d"),
                ("/a/b/../c/../d", "/a/d"),
                ("/a/b/", "/a/b"),
                ("/a//b", "/a/b"),
                ("/a///b", "/a/b"),
                ("//a//b//", "/a/b"),
                ("/", "/"),
                ("", ""),
                ("/a/b/../c/./d/", "/a/c/d"),
                ("a/b/../c", "a/c"),
                ("/a/../..", "/"),
                ("/./././.", "/"),
                ("/../../../..", "/"),
                ("/a%20b/c%2Fd", "/a%20b/c%2Fd"),
            ]
        )
        func normalizesPath(input: String, expected: String) {
            #expect(DZWebServerNormalizePath(input) == expected)
        }

        @Test("Preserves very deep paths")
        func preservesVeryDeepPaths() {
            let deep = "/" + (1...100).map { "dir\($0)" }.joined(separator: "/")

            #expect(DZWebServerNormalizePath(deep) == deep)
        }
    }

    // MARK: Primary IP Address

    @Suite("Primary IP Address")
    struct IPAddressTests {
        @Test(
            "Returns a valid IPv4 address",
            .enabled(if: DZWebServerGetPrimaryIPAddress(false) != nil, "Requires an IPv4 network interface")
        )
        func returnsValidIPv4Address() throws {
            let address = try #require(DZWebServerGetPrimaryIPAddress(false))
            var parsed = in_addr()

            #expect(inet_pton(AF_INET, address, &parsed) == 1, "'\(address)' is not a valid IPv4 address")
        }

        @Test(
            "Returns a valid IPv6 address",
            .enabled(if: DZWebServerGetPrimaryIPAddress(true) != nil, "Requires an IPv6 network interface")
        )
        func returnsValidIPv6Address() throws {
            let address = try #require(DZWebServerGetPrimaryIPAddress(true))
            // Link-local addresses carry a "%interface" scope suffix that inet_pton rejects.
            let host = address.split(separator: "%").first.map(String.init) ?? address
            var parsed = in6_addr()

            #expect(inet_pton(AF_INET6, host, &parsed) == 1, "'\(address)' is not a valid IPv6 address")
        }
    }
}
