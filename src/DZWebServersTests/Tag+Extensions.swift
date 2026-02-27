//
//  Tag+Extensions.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Testing

extension Tag {
    /// Core server lifecycle (start, stop, options, delegate)
    @Tag static var server: Self

    /// Connection-level behavior
    @Tag static var connection: Self

    /// Request parsing and properties
    @Tag static var request: Self

    /// Response generation and properties
    @Tag static var response: Self

    /// Utility C functions (MIME, URL encoding, dates, paths)
    @Tag static var functions: Self

    /// HTTP status code enum values
    @Tag static var statusCodes: Self

    /// Error handling and error responses
    @Tag static var errorHandling: Self

    /// Integration tests (server + HTTP client round-trip)
    @Tag static var integration: Self

    /// File I/O operations (reading, writing, temp files)
    @Tag static var fileIO: Self

    /// URL encoding and decoding
    @Tag static var encoding: Self

    /// Date formatting (RFC 822, ISO 8601)
    @Tag static var dateFormatting: Self

    /// MIME type resolution
    @Tag static var mimeType: Self

    /// WebDAV protocol operations
    @Tag static var webDAV: Self

    /// File uploader web interface
    @Tag static var uploader: Self

    /// HTTP authentication (Basic, Digest)
    @Tag static var authentication: Self

    /// Streaming response behavior
    @Tag static var streaming: Self

    /// Property default values and behavior
    @Tag static var properties: Self
}
