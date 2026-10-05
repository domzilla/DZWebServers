//
//  DZWebServerErrorResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

private func html(of response: DZWebServerResponse) throws -> String {
    try #require(String(data: TestSupport.readBody(of: response), encoding: .utf8))
}

@Suite("DZWebServerErrorResponse", .serialized, .tags(.response, .errorHandling))
struct DZWebServerErrorResponseTests {
    // MARK: Status Codes

    @Suite("Status codes", .tags(.statusCodes))
    struct StatusCodes {
        @Test(
            "Client error sets the status code and renders an HTML error page",
            arguments: [
                (.httpStatusCode_BadRequest, 400),
                (.httpStatusCode_Unauthorized, 401),
                (.httpStatusCode_PaymentRequired, 402),
                (.httpStatusCode_Forbidden, 403),
                (.httpStatusCode_NotFound, 404),
                (.httpStatusCode_MethodNotAllowed, 405),
                (.httpStatusCode_NotAcceptable, 406),
                (.httpStatusCode_ProxyAuthenticationRequired, 407),
                (.httpStatusCode_RequestTimeout, 408),
                (.httpStatusCode_Conflict, 409),
                (.httpStatusCode_Gone, 410),
                (.httpStatusCode_LengthRequired, 411),
                (.httpStatusCode_PreconditionFailed, 412),
                (.httpStatusCode_RequestEntityTooLarge, 413),
                (.httpStatusCode_RequestURITooLong, 414),
                (.httpStatusCode_UnsupportedMediaType, 415),
                (.httpStatusCode_RequestedRangeNotSatisfiable, 416),
                (.httpStatusCode_ExpectationFailed, 417),
                (.httpStatusCode_UnprocessableEntity, 422),
                (.httpStatusCode_Locked, 423),
                (.httpStatusCode_FailedDependency, 424),
                (.httpStatusCode_UpgradeRequired, 426),
                (.httpStatusCode_PreconditionRequired, 428),
                (.httpStatusCode_TooManyRequests, 429),
                (.httpStatusCode_RequestHeaderFieldsTooLarge, 431),
            ] as [(DZWebServerClientErrorHTTPStatusCode, Int)]
        )
        func clientErrorRendersErrorPage(errorCode: DZWebServerClientErrorHTTPStatusCode, statusCode: Int) throws {
            let response = DZWebServerErrorResponse(clientError: errorCode, message: "Test error")

            #expect(response.statusCode == statusCode)
            #expect(response.contentType == "text/html; charset=utf-8")
            let html = try html(of: response)
            #expect(response.contentLength == UInt(html.utf8.count))
            #expect(html.contains("<title>HTTP Error \(statusCode)</title>"))
            #expect(html.contains("<h1>HTTP Error \(statusCode): Test error</h1>"))
        }

        @Test(
            "Server error sets the status code and renders an HTML error page",
            arguments: [
                (.httpStatusCode_InternalServerError, 500),
                (.httpStatusCode_NotImplemented, 501),
                (.httpStatusCode_BadGateway, 502),
                (.httpStatusCode_ServiceUnavailable, 503),
                (.httpStatusCode_GatewayTimeout, 504),
                (.httpStatusCode_HTTPVersionNotSupported, 505),
                (.httpStatusCode_InsufficientStorage, 507),
                (.httpStatusCode_LoopDetected, 508),
                (.httpStatusCode_NotExtended, 510),
                (.httpStatusCode_NetworkAuthenticationRequired, 511),
            ] as [(DZWebServerServerErrorHTTPStatusCode, Int)]
        )
        func serverErrorRendersErrorPage(errorCode: DZWebServerServerErrorHTTPStatusCode, statusCode: Int) throws {
            let response = DZWebServerErrorResponse(serverError: errorCode, message: "Test error")

            #expect(response.statusCode == statusCode)
            #expect(response.contentType == "text/html; charset=utf-8")
            let html = try html(of: response)
            #expect(response.contentLength == UInt(html.utf8.count))
            #expect(html.contains("<title>HTTP Error \(statusCode)</title>"))
            #expect(html.contains("<h1>HTTP Error \(statusCode): Test error</h1>"))
        }
    }

    // MARK: Underlying Error

    @Suite("Underlying NSError")
    struct UnderlyingError {
        @Test("Client error renders the underlying error's domain, description and code")
        func clientErrorRendersUnderlyingError() throws {
            let underlyingError = NSError(
                domain: "TestDomain",
                code: 42,
                userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]
            )
            let response = DZWebServerErrorResponse(
                clientError: .httpStatusCode_NotFound,
                underlyingError: underlyingError,
                message: "Resource missing"
            )

            #expect(response.statusCode == 404)
            let html = try html(of: response)
            #expect(html.contains("<h1>HTTP Error 404: Resource missing</h1>"))
            #expect(html.contains("<h3>[TestDomain] Something went wrong (42)</h3>"))
        }

        @Test("Server error renders the underlying error's domain, description and code")
        func serverErrorRendersUnderlyingError() throws {
            let underlyingError = NSError(
                domain: "com.example.custom.error.domain",
                code: -9999,
                userInfo: [NSLocalizedDescriptionKey: "Internal failure"]
            )
            let response = DZWebServerErrorResponse(
                serverError: .httpStatusCode_InternalServerError,
                underlyingError: underlyingError,
                message: "Server crashed"
            )

            #expect(response.statusCode == 500)
            let html = try html(of: response)
            #expect(html.contains("<h1>HTTP Error 500: Server crashed</h1>"))
            #expect(html.contains("<h3>[com.example.custom.error.domain] Internal failure (-9999)</h3>"))
        }

        @Test("Underlying error without a localized description falls back to Foundation's default description")
        func underlyingErrorWithoutLocalizedDescription() throws {
            let underlyingError = NSError(domain: "MinimalDomain", code: 1, userInfo: nil)
            let response = DZWebServerErrorResponse(
                serverError: .httpStatusCode_BadGateway,
                underlyingError: underlyingError,
                message: "Upstream failure"
            )

            let html = try html(of: response)
            #expect(html.contains("<h3>[MinimalDomain] \(underlyingError.localizedDescription) (1)</h3>"))
        }

        @Test("Nil underlying error renders an empty secondary heading")
        func nilUnderlyingErrorRendersEmptyHeading() throws {
            let response = DZWebServerErrorResponse(
                clientError: .httpStatusCode_BadRequest,
                underlyingError: nil,
                message: "Bad input"
            )

            #expect(response.statusCode == 400)
            #expect(try html(of: response).contains("<h1>HTTP Error 400: Bad input</h1><h3></h3>"))
        }

        @Test("Double quotes in the underlying error description are escaped")
        func underlyingErrorDescriptionQuotesAreEscaped() throws {
            let underlyingError = NSError(
                domain: "TestDomain",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "File \"a.txt\" missing"]
            )
            let response = DZWebServerErrorResponse(
                clientError: .httpStatusCode_NotFound,
                underlyingError: underlyingError,
                message: "Missing"
            )

            #expect(try html(of: response).contains("<h3>[TestDomain] File &quot;a.txt&quot; missing (7)</h3>"))
        }
    }

    // MARK: Message

    @Suite("Message rendering")
    struct Message {
        @Test(
            "Message is rendered verbatim in the heading",
            arguments: [
                "The page you requested could not be found.",
                "",
                "Etwas ist schiefgelaufen \u{1F622} \u{2764}\u{FE0F}",
                "   \t\n   ",
                "Line 1\nLine 2\nLine 3",
                String(repeating: "This is a very long error message. ", count: 1000),
            ]
        )
        func messageIsRenderedVerbatim(message: String) throws {
            let response = DZWebServerErrorResponse(clientError: .httpStatusCode_BadRequest, message: message)

            #expect(try html(of: response).contains("<h1>HTTP Error 400: \(message)</h1>"))
        }

        @Test("Double quotes in the message are escaped")
        func messageDoubleQuotesAreEscaped() throws {
            let response = DZWebServerErrorResponse(
                clientError: .httpStatusCode_BadRequest,
                message: "Expected \"value\" but got \"null\""
            )

            #expect(
                try html(of: response)
                    .contains("<h1>HTTP Error 400: Expected &quot;value&quot; but got &quot;null&quot;</h1>")
            )
        }

        @Test("HTML markup in the message is escaped")
        func messageHTMLMarkupIsEscaped() throws {
            let response = DZWebServerErrorResponse(
                clientError: .httpStatusCode_BadRequest,
                message: "Invalid <script>alert('xss')</script> & more"
            )
            let html = try html(of: response)

            withKnownIssue("Framework bug: _EscapeHTMLString only escapes double quotes, not <, > and &") {
                #expect(html.contains("&lt;script&gt;alert('xss')&lt;/script&gt; &amp; more"))
                #expect(!html.contains("<script>"))
            }
        }
    }
}
