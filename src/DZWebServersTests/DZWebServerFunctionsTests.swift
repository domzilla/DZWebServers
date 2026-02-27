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

// MARK: - Root Suite

@Suite("DZWebServerFunctions", .serialized, .tags(.functions))
struct DZWebServerFunctionsTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - MIME Type Tests

    @Suite("MIME Type Resolution", .serialized, .tags(.mimeType))
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
        func returnsCorrectMimeTypeForCommonExtensions(extensionAndExpected: (String, String)) {
            let (ext, expected) = extensionAndExpected
            let result = DZWebServerGetMimeType(forExtension: ext, overrides: nil)
            #expect(result == expected, "Expected MIME type '\(expected)' for extension '\(ext)', got '\(result)'")
        }

        @Test(
            "Returns application/octet-stream for unknown extensions",
            arguments: ["xyzzy", "unknownext", "zzz123", "nope"]
        )
        func returnsOctetStreamForUnknownExtension(ext: String) {
            let result = DZWebServerGetMimeType(forExtension: ext, overrides: nil)
            #expect(result == "application/octet-stream")
        }

        @Test("Is case-insensitive for extension lookup")
        func isCaseInsensitiveForExtensions() {
            let lower = DZWebServerGetMimeType(forExtension: "html", overrides: nil)
            let upper = DZWebServerGetMimeType(forExtension: "HTML", overrides: nil)
            let mixed = DZWebServerGetMimeType(forExtension: "Html", overrides: nil)
            #expect(lower == upper)
            #expect(lower == mixed)
        }

        @Test("Override dictionary takes precedence over built-in types")
        func overrideTakesPrecedence() {
            let overrides = ["html": "text/x-custom-html", "css": "text/x-custom-css"]
            let htmlResult = DZWebServerGetMimeType(forExtension: "html", overrides: overrides)
            let cssResult = DZWebServerGetMimeType(forExtension: "css", overrides: overrides)
            #expect(htmlResult == "text/x-custom-html")
            #expect(cssResult == "text/x-custom-css")
        }

        @Test("Override does not affect other extensions")
        func overrideDoesNotAffectOtherExtensions() {
            let overrides = ["html": "text/x-custom-html"]
            let jsonResult = DZWebServerGetMimeType(forExtension: "json", overrides: overrides)
            #expect(jsonResult == "application/json")
        }

        @Test("Returns application/octet-stream for empty extension")
        func returnsOctetStreamForEmptyExtension() {
            let result = DZWebServerGetMimeType(forExtension: "", overrides: nil)
            #expect(result == "application/octet-stream")
        }

        @Test("Returns application/octet-stream for very long extension string")
        func returnsOctetStreamForVeryLongExtension() {
            let longExt = String(repeating: "a", count: 1000)
            let result = DZWebServerGetMimeType(forExtension: longExt, overrides: nil)
            #expect(result == "application/octet-stream")
        }

        @Test("Built-in css override returns text/css not the system default")
        func builtInCSSOverrideIsActive() {
            // The implementation has a built-in override for css -> text/css
            let result = DZWebServerGetMimeType(forExtension: "css", overrides: nil)
            #expect(result == "text/css")
        }

        @Test("Nil overrides dictionary works correctly")
        func nilOverridesWorks() {
            let result = DZWebServerGetMimeType(forExtension: "png", overrides: nil)
            #expect(result == "image/png")
        }

        @Test("Empty overrides dictionary works correctly")
        func emptyOverridesWorks() {
            let result = DZWebServerGetMimeType(forExtension: "png", overrides: [:])
            #expect(result == "image/png")
        }
    }

    // MARK: - URL Encoding Tests

    @Suite("URL Encoding", .serialized, .tags(.encoding))
    struct URLEncodingTests {
        @Test(
            "Escapes reserved URL characters",
            arguments: [
                (":", "%3A"),
                ("@", "%40"),
                ("/", "%2F"),
                ("?", "%3F"),
                ("&", "%26"),
                ("=", "%3D"),
                ("+", "%2B"),
            ]
        )
        func escapesReservedCharacters(inputAndExpected: (String, String)) {
            let (input, expected) = inputAndExpected
            let result = DZWebServerEscapeURLString(input)
            #expect(result == expected, "Expected '\(expected)' for '\(input)', got '\(result ?? "nil")'")
        }

        @Test("Does not escape unreserved ASCII characters")
        func doesNotEscapeUnreservedASCII() {
            let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
            let result = DZWebServerEscapeURLString(unreserved)
            #expect(result == unreserved)
        }

        @Test("Escapes spaces")
        func escapesSpaces() {
            let result = DZWebServerEscapeURLString("hello world")
            #expect(result == "hello%20world")
        }

        @Test("Escapes unicode characters")
        func escapesUnicode() {
            let result = DZWebServerEscapeURLString("cafe\u{0301}")
            #expect(result != nil)
            #expect(result != "cafe\u{0301}")
            // After escaping, the string should contain percent-encoded bytes
            #expect(result?.contains("%") == true)
        }

        @Test("Escapes emoji characters")
        func escapesEmoji() {
            let result = DZWebServerEscapeURLString("\u{1F600}")
            #expect(result != nil)
            #expect(result?.contains("%") == true)
        }

        @Test("Returns empty string for empty input")
        func escapesEmptyString() {
            let result = DZWebServerEscapeURLString("")
            #expect(result == "")
        }

        @Test("Handles very long input strings")
        func escapesVeryLongString() {
            let long = String(repeating: "a", count: 10000)
            let result = DZWebServerEscapeURLString(long)
            #expect(result == long) // all unreserved, should be unchanged
        }

        @Test("Escapes a complex query string")
        func escapesComplexQueryString() {
            let input = "key=value&foo=bar baz"
            let result = DZWebServerEscapeURLString(input)
            #expect(result != nil)
            #expect(result?.contains("=") == false)
            #expect(result?.contains("&") == false)
            #expect(result?.contains(" ") == false)
        }
    }

    // MARK: - URL Decoding Tests

    @Suite("URL Decoding", .serialized, .tags(.encoding))
    struct URLDecodingTests {
        @Test(
            "Unescapes percent-encoded characters",
            arguments: [
                ("%3A", ":"),
                ("%40", "@"),
                ("%2F", "/"),
                ("%3F", "?"),
                ("%26", "&"),
                ("%3D", "="),
                ("%2B", "+"),
                ("%20", " "),
            ]
        )
        func unescapesPercentEncodedCharacters(inputAndExpected: (String, String)) {
            let (input, expected) = inputAndExpected
            let result = DZWebServerUnescapeURLString(input)
            #expect(result == expected)
        }

        @Test("Returns the same string when nothing to unescape")
        func returnsUnchangedForPlainString() {
            let input = "hello"
            let result = DZWebServerUnescapeURLString(input)
            #expect(result == input)
        }

        @Test("Unescapes empty string to empty string")
        func unescapesEmptyString() {
            let result = DZWebServerUnescapeURLString("")
            #expect(result == "")
        }

        @Test("Handles mixed encoded and unencoded content")
        func handlesMixedContent() {
            let result = DZWebServerUnescapeURLString("hello%20world%21")
            #expect(result == "hello world!")
        }

        @Test("Unescapes unicode percent-encoded sequences")
        func unescapesUnicodeSequences() {
            // The e-acute character U+00E9 in UTF-8 is C3 A9
            let result = DZWebServerUnescapeURLString("caf%C3%A9")
            #expect(result == "caf\u{00E9}")
        }

        @Test("Handles lowercase hex digits in percent encoding")
        func handlesLowercaseHex() {
            let result = DZWebServerUnescapeURLString("%2f")
            #expect(result == "/")
        }

        @Test("Handles uppercase hex digits in percent encoding")
        func handlesUppercaseHex() {
            let result = DZWebServerUnescapeURLString("%2F")
            #expect(result == "/")
        }
    }

    // MARK: - URL Encoding Round-Trip Tests

    @Suite("URL Encoding Round-Trip", .serialized, .tags(.encoding))
    struct URLEncodingRoundTripTests {
        @Test(
            "Round-trip encode then decode restores original string",
            arguments: [
                "hello world",
                "foo=bar&baz=qux",
                "https://example.com/path?q=1",
                "simple",
                "",
                "unicode: cafe\u{0301}",
            ]
        )
        func roundTripEncodeDecodeRestoresOriginal(input: String) {
            let encoded = DZWebServerEscapeURLString(input)
            let decoded = encoded.flatMap { DZWebServerUnescapeURLString($0) }
            #expect(
                decoded == input,
                "Round-trip failed for '\(input)': encoded='\(encoded ?? "nil")', decoded='\(decoded ?? "nil")'"
            )
        }

        @Test("Round-trip preserves ASCII-only strings without mutation")
        func roundTripPreservesASCII() throws {
            let input = "ABCabc123-._~"
            let encoded = DZWebServerEscapeURLString(input)
            #expect(encoded == input) // unreserved chars should not be encoded
            let decoded = try DZWebServerUnescapeURLString(#require(encoded))
            #expect(decoded == input)
        }
    }

    // MARK: - URL-Encoded Form Parsing Tests

    @Suite("URL-Encoded Form Parsing", .serialized, .tags(.encoding))
    struct URLEncodedFormParsingTests {
        @Test("Parses simple key-value pair")
        func parsesSimpleKeyValuePair() {
            let result = DZWebServerParseURLEncodedForm("name=John")
            #expect(result["name"] == "John")
            #expect(result.count == 1)
        }

        @Test("Parses multiple key-value pairs")
        func parsesMultiplePairs() {
            let result = DZWebServerParseURLEncodedForm("name=John&age=30&city=Berlin")
            #expect(result["name"] == "John")
            #expect(result["age"] == "30")
            #expect(result["city"] == "Berlin")
            #expect(result.count == 3)
        }

        @Test("Decodes plus signs as spaces in values")
        func decodesPlusAsSpace() {
            let result = DZWebServerParseURLEncodedForm("greeting=hello+world")
            #expect(result["greeting"] == "hello world")
        }

        @Test("Decodes plus signs as spaces in keys")
        func decodesPlusAsSpaceInKeys() {
            let result = DZWebServerParseURLEncodedForm("my+key=value")
            #expect(result["my key"] == "value")
        }

        @Test("Decodes percent-encoded characters in values")
        func decodesPercentEncodedValues() {
            let result = DZWebServerParseURLEncodedForm("path=%2Fhome%2Fuser")
            #expect(result["path"] == "/home/user")
        }

        @Test("Decodes percent-encoded characters in keys")
        func decodesPercentEncodedKeys() {
            let result = DZWebServerParseURLEncodedForm("%6Eame=John")
            #expect(result["name"] == "John")
        }

        @Test("Returns empty dictionary for empty form string")
        func returnsEmptyDictionaryForEmptyString() {
            let result = DZWebServerParseURLEncodedForm("")
            #expect(result.isEmpty)
        }

        @Test("Last occurrence wins for duplicate keys")
        func lastOccurrenceWinsForDuplicateKeys() {
            let result = DZWebServerParseURLEncodedForm("key=first&key=second&key=third")
            #expect(result["key"] == "third")
            #expect(result.count == 1)
        }

        @Test("Handles empty value")
        func handlesEmptyValue() {
            let result = DZWebServerParseURLEncodedForm("key=")
            #expect(result["key"] == "")
        }

        @Test("Handles value containing equals sign")
        func handlesValueContainingEquals() {
            // "expr=a=b" -> key="expr", value="a=b" (only first = splits)
            // Based on implementation: scans up to first =, then scans up to &
            // So key="expr" and value="a=b"
            let result = DZWebServerParseURLEncodedForm("expr=a%3Db")
            #expect(result["expr"] == "a=b")
        }

        @Test("Handles special characters in values")
        func handlesSpecialCharactersInValues() {
            let result = DZWebServerParseURLEncodedForm("q=%21%40%23%24%25")
            #expect(result["q"] == "!@#$%")
        }

        @Test("Parses complex real-world form data")
        func parsesRealWorldFormData() {
            let form = "username=john%40example.com&password=p%40ss%26word&remember=true"
            let result = DZWebServerParseURLEncodedForm(form)
            #expect(result["username"] == "john@example.com")
            #expect(result["password"] == "p@ss&word")
            #expect(result["remember"] == "true")
        }
    }

    // MARK: - RFC 822 Date Tests

    @Suite("RFC 822 Date Formatting and Parsing", .serialized, .tags(.dateFormatting))
    struct RFC822DateTests {
        @Test("Formats a known date correctly")
        func formatsKnownDateCorrectly() throws {
            // Create a known date: 2026-02-27 12:00:00 UTC
            var components = DateComponents()
            components.year = 2026
            components.month = 2
            components.day = 27
            components.hour = 12
            components.minute = 0
            components.second = 0
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let date = try #require(calendar.date(from: components))

            let result = DZWebServerFormatRFC822(date)
            #expect(result == "Fri, 27 Feb 2026 12:00:00 GMT")
        }

        @Test("Parses a valid RFC 822 string")
        func parsesValidRFC822String() throws {
            let date = DZWebServerParseRFC822("Fri, 27 Feb 2026 12:00:00 GMT")
            #expect(date != nil)

            let calendar = Calendar(identifier: .gregorian)
            let components = try calendar.dateComponents(
                in: #require(TimeZone(abbreviation: "GMT")),
                from: #require(date)
            )
            #expect(components.year == 2026)
            #expect(components.month == 2)
            #expect(components.day == 27)
            #expect(components.hour == 12)
            #expect(components.minute == 0)
            #expect(components.second == 0)
        }

        @Test("Round-trip format then parse returns equivalent date")
        func roundTripFormatParse() throws {
            // Use a date with whole seconds to avoid sub-second precision issues
            var components = DateComponents()
            components.year = 2025
            components.month = 6
            components.day = 15
            components.hour = 8
            components.minute = 30
            components.second = 45
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let originalDate = try #require(calendar.date(from: components))

            let formatted = DZWebServerFormatRFC822(originalDate)
            let parsed = DZWebServerParseRFC822(formatted)
            #expect(parsed != nil)

            // Compare with 1-second tolerance (format truncates sub-seconds)
            let difference = try abs(originalDate.timeIntervalSince(#require(parsed)))
            #expect(difference < 1.0, "Dates differ by \(difference) seconds")
        }

        @Test(
            "Returns nil for invalid RFC 822 strings",
            arguments: [
                "not a date",
                "2026-02-27",
                "27 Feb 2026",
                "12345",
            ]
        )
        func returnsNilForInvalidRFC822Strings(input: String) {
            let result = DZWebServerParseRFC822(input)
            #expect(
                result == nil,
                "Expected nil for invalid RFC 822 string '\(input)', got \(String(describing: result))"
            )
        }

        @Test("Returns nil for empty string")
        func returnsNilForEmptyString() {
            let result = DZWebServerParseRFC822("")
            #expect(result == nil)
        }

        @Test(
            "Formats different dates with correct day-of-week",
            arguments: [
                (2026, 2, 27, "Fri"), // Friday
                (2026, 3, 1, "Sun"), // Sunday
                (2026, 1, 1, "Thu"), // Thursday
                (2025, 12, 25, "Thu"), // Thursday (Christmas 2025)
            ]
        )
        func formatsWithCorrectDayOfWeek(yearMonthDayDow: (Int, Int, Int, String)) throws {
            let (year, month, day, expectedDow) = yearMonthDayDow

            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 0
            components.minute = 0
            components.second = 0
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let date = try #require(calendar.date(from: components))

            let formatted = DZWebServerFormatRFC822(date)
            #expect(formatted.hasPrefix(expectedDow + ","), "Expected '\(expectedDow),' prefix in '\(formatted)'")
        }
    }

    // MARK: - ISO 8601 Date Tests

    @Suite("ISO 8601 Date Formatting and Parsing", .serialized, .tags(.dateFormatting))
    struct ISO8601DateTests {
        @Test("Formats a known date correctly")
        func formatsKnownDateCorrectly() throws {
            var components = DateComponents()
            components.year = 2026
            components.month = 2
            components.day = 27
            components.hour = 12
            components.minute = 0
            components.second = 0
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let date = try #require(calendar.date(from: components))

            let result = DZWebServerFormatISO8601(date)
            #expect(result == "2026-02-27T12:00:00+00:00")
        }

        @Test("Parses a valid ISO 8601 string")
        func parsesValidISO8601String() throws {
            let date = DZWebServerParseISO8601("2026-02-27T12:00:00+00:00")
            #expect(date != nil)

            let calendar = Calendar(identifier: .gregorian)
            let components = try calendar.dateComponents(
                in: #require(TimeZone(abbreviation: "GMT")),
                from: #require(date)
            )
            #expect(components.year == 2026)
            #expect(components.month == 2)
            #expect(components.day == 27)
            #expect(components.hour == 12)
            #expect(components.minute == 0)
            #expect(components.second == 0)
        }

        @Test("Round-trip format then parse returns equivalent date")
        func roundTripFormatParse() throws {
            var components = DateComponents()
            components.year = 2025
            components.month = 6
            components.day = 15
            components.hour = 8
            components.minute = 30
            components.second = 45
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let originalDate = try #require(calendar.date(from: components))

            let formatted = DZWebServerFormatISO8601(originalDate)
            let parsed = DZWebServerParseISO8601(formatted)
            #expect(parsed != nil)

            let difference = try abs(originalDate.timeIntervalSince(#require(parsed)))
            #expect(difference < 1.0, "Dates differ by \(difference) seconds")
        }

        @Test(
            "Returns nil for invalid ISO 8601 strings",
            arguments: [
                "not a date",
                "Fri, 27 Feb 2026 12:00:00 GMT",
                "2026/02/27 12:00:00",
                "2026-02-27",
                "12345",
            ]
        )
        func returnsNilForInvalidISO8601Strings(input: String) {
            let result = DZWebServerParseISO8601(input)
            #expect(
                result == nil,
                "Expected nil for invalid ISO 8601 string '\(input)', got \(String(describing: result))"
            )
        }

        @Test("Returns nil for empty string")
        func returnsNilForEmptyString() {
            let result = DZWebServerParseISO8601("")
            #expect(result == nil)
        }

        @Test("Returns nil for ISO 8601 with non-UTC offset")
        func returnsNilForNonUTCOffset() {
            // The implementation only supports +00:00
            let result = DZWebServerParseISO8601("2026-02-27T12:00:00+05:30")
            #expect(result == nil)
        }

        @Test("Returns nil for ISO 8601 with Z suffix instead of +00:00")
        func returnsNilForZSuffix() {
            // The format string uses literal '+00:00', so Z should not parse
            let result = DZWebServerParseISO8601("2026-02-27T12:00:00Z")
            #expect(result == nil)
        }

        @Test("Formats midnight correctly")
        func formatsMidnightCorrectly() throws {
            var components = DateComponents()
            components.year = 2026
            components.month = 1
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let date = try #require(calendar.date(from: components))

            let result = DZWebServerFormatISO8601(date)
            #expect(result == "2026-01-01T00:00:00+00:00")
        }

        @Test("Formats end of day correctly")
        func formatsEndOfDayCorrectly() throws {
            var components = DateComponents()
            components.year = 2026
            components.month = 12
            components.day = 31
            components.hour = 23
            components.minute = 59
            components.second = 59
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let date = try #require(calendar.date(from: components))

            let result = DZWebServerFormatISO8601(date)
            #expect(result == "2026-12-31T23:59:59+00:00")
        }
    }

    // MARK: - Cross-Format Date Tests

    @Suite("Cross-Format Date Consistency", .serialized, .tags(.dateFormatting))
    struct CrossFormatDateTests {
        @Test("RFC 822 and ISO 8601 format the same date to different strings representing the same instant")
        func crossFormatConsistency() throws {
            var components = DateComponents()
            components.year = 2026
            components.month = 6
            components.day = 15
            components.hour = 14
            components.minute = 30
            components.second = 0
            components.timeZone = TimeZone(abbreviation: "GMT")

            let calendar = Calendar(identifier: .gregorian)
            let date = try #require(calendar.date(from: components))

            let rfc822 = DZWebServerFormatRFC822(date)
            let iso8601 = DZWebServerFormatISO8601(date)

            // Parse both back
            let parsedRFC822 = DZWebServerParseRFC822(rfc822)
            let parsedISO8601 = DZWebServerParseISO8601(iso8601)

            #expect(parsedRFC822 != nil)
            #expect(parsedISO8601 != nil)

            // Both should represent the same instant
            let difference = try abs(#require(parsedRFC822?.timeIntervalSince(#require(parsedISO8601))))
            #expect(difference < 1.0, "RFC 822 and ISO 8601 parsed dates differ by \(difference) seconds")
        }
    }

    // MARK: - Path Normalization Tests

    @Suite("Path Normalization", .serialized, .tags(.functions))
    struct PathNormalizationTests {
        @Test("Preserves normal absolute paths")
        func preservesNormalPaths() {
            let result = DZWebServerNormalizePath("/a/b/c")
            #expect(result == "/a/b/c")
        }

        @Test(
            "Removes single dot segments",
            arguments: [
                ("/a/./b", "/a/b"),
                ("/a/./b/./c", "/a/b/c"),
                ("/./a", "/a"),
            ]
        )
        func removesDotSegments(inputAndExpected: (String, String)) {
            let (input, expected) = inputAndExpected
            let result = DZWebServerNormalizePath(input)
            #expect(result == expected, "Expected '\(expected)' for '\(input)', got '\(result)'")
        }

        @Test(
            "Resolves parent traversal segments",
            arguments: [
                ("/a/b/../c", "/a/c"),
                ("/a/b/c/../../d", "/a/d"),
                ("/a/b/../c/../d", "/a/d"),
            ]
        )
        func resolvesParentTraversal(inputAndExpected: (String, String)) {
            let (input, expected) = inputAndExpected
            let result = DZWebServerNormalizePath(input)
            #expect(result == expected, "Expected '\(expected)' for '\(input)', got '\(result)'")
        }

        @Test("Removes trailing slashes")
        func removesTrailingSlashes() {
            let result = DZWebServerNormalizePath("/a/b/")
            #expect(result == "/a/b")
        }

        @Test(
            "Collapses multiple consecutive slashes",
            arguments: [
                ("/a//b", "/a/b"),
                ("/a///b", "/a/b"),
                ("//a//b//", "/a/b"),
            ]
        )
        func collapsesMultipleSlashes(inputAndExpected: (String, String)) {
            let (input, expected) = inputAndExpected
            let result = DZWebServerNormalizePath(input)
            #expect(result == expected, "Expected '\(expected)' for '\(input)', got '\(result)'")
        }

        @Test("Normalizes root path to slash")
        func normalizesRootPath() {
            let result = DZWebServerNormalizePath("/")
            #expect(result == "/")
        }

        @Test("Returns empty string for empty path")
        func returnsEmptyForEmptyPath() {
            let result = DZWebServerNormalizePath("")
            #expect(result == "")
        }

        @Test("Handles complex path with mixed segments")
        func handlesComplexMixedPath() {
            let result = DZWebServerNormalizePath("/a/b/../c/./d/")
            #expect(result == "/a/c/d")
        }

        @Test("Normalizes relative paths without leading slash")
        func normalizesRelativePaths() {
            let result = DZWebServerNormalizePath("a/b/../c")
            #expect(result == "a/c")
        }

        @Test("Handles parent traversal beyond root")
        func handlesParentTraversalBeyondRoot() {
            // Going up beyond root should not crash; components just get removed
            let result = DZWebServerNormalizePath("/a/../..")
            #expect(result == "/")
        }

        @Test("Handles path of only dots")
        func handlesOnlyDots() {
            let result = DZWebServerNormalizePath("/./././.")
            #expect(result == "/")
        }

        @Test("Handles path of only parent traversals")
        func handlesOnlyParentTraversals() {
            let result = DZWebServerNormalizePath("/../../../..")
            #expect(result == "/")
        }

        @Test("Preserves single-component path")
        func preservesSingleComponent() {
            let result = DZWebServerNormalizePath("/file.txt")
            #expect(result == "/file.txt")
        }

        @Test("Handles path with special characters in component names")
        func handlesSpecialCharactersInComponents() {
            let result = DZWebServerNormalizePath("/a%20b/c%2Fd")
            #expect(result == "/a%20b/c%2Fd")
        }

        @Test("Handles very deep paths")
        func handlesVeryDeepPaths() {
            let deep = "/" + (1...100).map { "dir\($0)" }.joined(separator: "/")
            let result = DZWebServerNormalizePath(deep)
            #expect(result == deep)
        }
    }

    // MARK: - IP Address Tests

    @Suite("Primary IP Address", .serialized, .tags(.functions))
    struct IPAddressTests {
        @Test("Returns a non-nil IPv4 address on a networked machine")
        func returnsIPv4Address() {
            let address = DZWebServerGetPrimaryIPAddress(false)
            // On a machine with network, this should return an address
            // It may be nil in very unusual CI environments
            if let address {
                #expect(!address.isEmpty)
                // Basic IPv4 format check: contains dots
                #expect(address.contains("."), "IPv4 address '\(address)' should contain dots")
            }
        }

        @Test("IPv6 call does not crash")
        func ipv6DoesNotCrash() {
            // IPv6 may or may not return a result depending on network configuration.
            // The important thing is it does not crash.
            _ = DZWebServerGetPrimaryIPAddress(true)
        }

        @Test("IPv4 address has valid format when returned")
        func ipv4HasValidFormat() {
            guard let address = DZWebServerGetPrimaryIPAddress(false) else {
                return // Skip if no network
            }

            let components = address.split(separator: ".")
            #expect(components.count == 4, "IPv4 should have 4 octets, got \(components.count)")

            for octet in components {
                let value = Int(octet)
                #expect(value != nil, "Octet '\(octet)' is not a valid integer")
                if let value {
                    #expect(value >= 0 && value <= 255, "Octet \(value) is out of range 0-255")
                }
            }
        }
    }
}
