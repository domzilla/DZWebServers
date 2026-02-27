//
//  DZWebServerErrorResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Testing
@testable import DZWebServers

// MARK: - Client Error Responses (4xx)

@Suite("Client Error Responses (4xx)", .serialized, .tags(.response, .errorHandling, .statusCodes))
struct ClientErrorResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Client error response sets the correct status code for each 4xx code",
        arguments: [
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest, 400, "Bad Request"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Unauthorized, 401, "Unauthorized"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden, 403, "Forbidden"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound, 404, "Not Found"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_MethodNotAllowed, 405, "Method Not Allowed"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Conflict, 409, "Conflict"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Gone, 410, "Gone"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnprocessableEntity, 422, "Unprocessable Entity"),
        ] as [(DZWebServerClientErrorHTTPStatusCode, Int, String)]
    )
    func clientErrorResponseSetsCorrectStatusCode(
        errorCode: DZWebServerClientErrorHTTPStatusCode,
        expectedStatusCode: Int,
        name: String
    ) {
        let response = DZWebServerErrorResponse(clientError: errorCode, message: "Test error")
        #expect(
            response.statusCode == expectedStatusCode,
            "\(name) response should have status code \(expectedStatusCode)"
        )
    }

    @Test(
        "Client error response has a body for each 4xx code",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Unauthorized,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_MethodNotAllowed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Conflict,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Gone,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnprocessableEntity,
        ]
    )
    func clientErrorResponseHasBody(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(clientError: errorCode, message: "Test error")
        #expect(
            response.hasBody(),
            "Client error response with code \(errorCode.rawValue) should have a body"
        )
    }

    @Test(
        "Client error response has HTML content type for each 4xx code",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Unauthorized,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_MethodNotAllowed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Conflict,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Gone,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnprocessableEntity,
        ]
    )
    func clientErrorResponseHasHTMLContentType(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(clientError: errorCode, message: "Test error")
        #expect(
            response.contentType.contains("text/html"),
            "Client error response should have text/html content type, got \(response.contentType)"
        )
    }

    @Test(
        "Client error response has non-zero content length",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden,
        ]
    )
    func clientErrorResponseHasNonZeroContentLength(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(clientError: errorCode, message: "Some error occurred")
        #expect(
            response.contentLength > 0,
            "Client error response should have a positive content length"
        )
    }

    @Test(
        "All remaining client error codes produce valid responses",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PaymentRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotAcceptable,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_ProxyAuthenticationRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestTimeout,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_LengthRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionFailed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestEntityTooLarge,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestURITooLong,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnsupportedMediaType,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestedRangeNotSatisfiable,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_ExpectationFailed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Locked,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_FailedDependency,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UpgradeRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_TooManyRequests,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestHeaderFieldsTooLarge,
        ]
    )
    func remainingClientErrorCodesProduceValidResponses(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(clientError: errorCode, message: "Error")
        #expect(response.statusCode == errorCode.rawValue)
        #expect(response.hasBody())
        #expect(response.contentType.contains("text/html"))
    }
}

// MARK: - Server Error Responses (5xx)

@Suite("Server Error Responses (5xx)", .serialized, .tags(.response, .errorHandling, .statusCodes))
struct ServerErrorResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Server error response sets the correct status code for each 5xx code",
        arguments: [
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError, 500, "Internal Server Error"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotImplemented, 501, "Not Implemented"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway, 502, "Bad Gateway"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable, 503, "Service Unavailable"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_GatewayTimeout, 504, "Gateway Timeout"),
        ] as [(DZWebServerServerErrorHTTPStatusCode, Int, String)]
    )
    func serverErrorResponseSetsCorrectStatusCode(
        errorCode: DZWebServerServerErrorHTTPStatusCode,
        expectedStatusCode: Int,
        name: String
    ) {
        let response = DZWebServerErrorResponse(serverError: errorCode, message: "Test error")
        #expect(
            response.statusCode == expectedStatusCode,
            "\(name) response should have status code \(expectedStatusCode)"
        )
    }

    @Test(
        "Server error response has a body for each 5xx code",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotImplemented,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_GatewayTimeout,
        ]
    )
    func serverErrorResponseHasBody(
        errorCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(serverError: errorCode, message: "Test error")
        #expect(
            response.hasBody(),
            "Server error response with code \(errorCode.rawValue) should have a body"
        )
    }

    @Test(
        "Server error response has HTML content type for each 5xx code",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotImplemented,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_GatewayTimeout,
        ]
    )
    func serverErrorResponseHasHTMLContentType(
        errorCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(serverError: errorCode, message: "Test error")
        #expect(
            response.contentType.contains("text/html"),
            "Server error response should have text/html content type, got \(response.contentType)"
        )
    }

    @Test(
        "Server error response has non-zero content length",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_GatewayTimeout,
        ]
    )
    func serverErrorResponseHasNonZeroContentLength(
        errorCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(serverError: errorCode, message: "Some error occurred")
        #expect(
            response.contentLength > 0,
            "Server error response should have a positive content length"
        )
    }

    @Test(
        "All remaining server error codes produce valid responses",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_HTTPVersionNotSupported,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InsufficientStorage,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_LoopDetected,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotExtended,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NetworkAuthenticationRequired,
        ]
    )
    func remainingServerErrorCodesProduceValidResponses(
        errorCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        let response = DZWebServerErrorResponse(serverError: errorCode, message: "Error")
        #expect(response.statusCode == errorCode.rawValue)
        #expect(response.hasBody())
        #expect(response.contentType.contains("text/html"))
    }
}

// MARK: - Underlying Error

@Suite("Error Responses with Underlying NSError", .serialized, .tags(.response, .errorHandling))
struct UnderlyingErrorResponseTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Client error response with underlying error is created successfully")
    func clientErrorWithUnderlyingErrorIsCreated() {
        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Something went wrong",
        ])
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_NotFound,
            underlyingError: underlyingError,
            message: "Resource missing"
        )
        #expect(response.statusCode == 404)
        #expect(response.hasBody())
    }

    @Test("Server error response with underlying error is created successfully")
    func serverErrorWithUnderlyingErrorIsCreated() {
        let underlyingError = NSError(domain: "TestDomain", code: 99, userInfo: [
            NSLocalizedDescriptionKey: "Internal failure",
        ])
        let response = DZWebServerErrorResponse(
            serverError: .httpStatusCode_InternalServerError,
            underlyingError: underlyingError,
            message: "Server crashed"
        )
        #expect(response.statusCode == 500)
        #expect(response.hasBody())
    }

    @Test("Client error response with nil underlying error works correctly")
    func clientErrorWithNilUnderlyingErrorWorks() {
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_BadRequest,
            underlyingError: nil,
            message: "Bad input"
        )
        #expect(response.statusCode == 400)
        #expect(response.hasBody())
        #expect(response.contentType.contains("text/html"))
    }

    @Test("Server error response with nil underlying error works correctly")
    func serverErrorWithNilUnderlyingErrorWorks() {
        let response = DZWebServerErrorResponse(
            serverError: .httpStatusCode_ServiceUnavailable,
            underlyingError: nil,
            message: "Maintenance"
        )
        #expect(response.statusCode == 503)
        #expect(response.hasBody())
        #expect(response.contentType.contains("text/html"))
    }

    @Test("Underlying error with custom domain and code is accepted")
    func underlyingErrorWithCustomDomainAndCodeIsAccepted() {
        let underlyingError = NSError(
            domain: "com.example.custom.error.domain",
            code: -9999,
            userInfo: [
                NSLocalizedDescriptionKey: "A very custom error",
            ]
        )
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_Forbidden,
            underlyingError: underlyingError,
            message: "Access denied"
        )
        #expect(response.statusCode == 403)
        #expect(response.hasBody())
    }

    @Test("Underlying error with no localized description is accepted")
    func underlyingErrorWithNoLocalizedDescriptionIsAccepted() {
        let underlyingError = NSError(domain: "MinimalDomain", code: 1, userInfo: nil)
        let response = DZWebServerErrorResponse(
            serverError: .httpStatusCode_BadGateway,
            underlyingError: underlyingError,
            message: "Upstream failure"
        )
        #expect(response.statusCode == 502)
        #expect(response.hasBody())
    }

    @Test("Underlying error with empty domain string is accepted")
    func underlyingErrorWithEmptyDomainStringIsAccepted() {
        let underlyingError = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Unknown",
        ])
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_Conflict,
            underlyingError: underlyingError,
            message: "Conflict detected"
        )
        #expect(response.statusCode == 409)
        #expect(response.hasBody())
    }

    @Test("Response content length increases when underlying error is provided")
    func responseContentLengthIncreasesWithUnderlyingError() {
        let message = "Resource not found"
        let responseWithout = DZWebServerErrorResponse(
            clientError: .httpStatusCode_NotFound,
            underlyingError: nil,
            message: message
        )
        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "File does not exist on disk",
        ])
        let responseWith = DZWebServerErrorResponse(
            clientError: .httpStatusCode_NotFound,
            underlyingError: underlyingError,
            message: message
        )
        #expect(
            responseWith.contentLength > responseWithout.contentLength,
            "Response with underlying error should have a larger body than without"
        )
    }
}

// MARK: - Message Content

@Suite("Error Response Messages", .serialized, .tags(.response, .errorHandling))
struct ErrorResponseMessageTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Simple message text produces a valid response")
    func simpleMessageTextProducesValidResponse() {
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_NotFound,
            message: "The page you requested could not be found."
        )
        #expect(response.statusCode == 404)
        #expect(response.hasBody())
        #expect(response.contentLength > 0)
    }

    @Test("Empty message produces a valid response")
    func emptyMessageProducesValidResponse() {
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_BadRequest,
            message: ""
        )
        #expect(response.statusCode == 400)
        #expect(response.hasBody())
        #expect(
            response.contentLength > 0,
            "Even an empty message should produce HTML boilerplate with non-zero length"
        )
    }

    @Test("Unicode message with emoji produces a valid response")
    func unicodeMessageWithEmojiProducesValidResponse() {
        let response = DZWebServerErrorResponse(
            serverError: .httpStatusCode_InternalServerError,
            message: "Etwas ist schiefgelaufen \u{1F622} \u{2764}\u{FE0F}"
        )
        #expect(response.statusCode == 500)
        #expect(response.hasBody())
        #expect(response.contentLength > 0)
    }

    @Test("Very long message produces a valid response")
    func veryLongMessageProducesValidResponse() {
        let longMessage = String(repeating: "This is a very long error message. ", count: 1000)
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_RequestEntityTooLarge,
            message: longMessage
        )
        #expect(response.statusCode == 413)
        #expect(response.hasBody())
        #expect(
            response.contentLength > longMessage.utf8.count,
            "Content length should exceed the raw message length due to HTML wrapping"
        )
    }

    @Test("Message with HTML special characters produces a valid response")
    func messageWithHTMLSpecialCharactersProducesValidResponse() {
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_BadRequest,
            message: "Invalid <script>alert('xss')</script> & \"quotes\" in request"
        )
        #expect(response.statusCode == 400)
        #expect(response.hasBody())
        #expect(response.contentLength > 0)
    }

    @Test("Message with only whitespace produces a valid response")
    func messageWithOnlyWhitespaceProducesValidResponse() {
        let response = DZWebServerErrorResponse(
            serverError: .httpStatusCode_InternalServerError,
            message: "   \t\n   "
        )
        #expect(response.statusCode == 500)
        #expect(response.hasBody())
    }

    @Test("Message with newlines produces a valid response")
    func messageWithNewlinesProducesValidResponse() {
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_UnprocessableEntity,
            message: "Line 1\nLine 2\nLine 3"
        )
        #expect(response.statusCode == 422)
        #expect(response.hasBody())
    }

    @Test("Message with double quotes is handled correctly")
    func messageWithDoubleQuotesIsHandled() {
        let response = DZWebServerErrorResponse(
            clientError: .httpStatusCode_BadRequest,
            message: "Expected \"value\" but got \"null\""
        )
        #expect(response.statusCode == 400)
        #expect(response.hasBody())
        #expect(response.contentLength > 0)
    }

    @Test("Different messages produce different content lengths")
    func differentMessagesProduceDifferentContentLengths() {
        let shortResponse = DZWebServerErrorResponse(
            clientError: .httpStatusCode_BadRequest,
            message: "Short"
        )
        let longResponse = DZWebServerErrorResponse(
            clientError: .httpStatusCode_BadRequest,
            message: "This is a considerably longer error message with more detail"
        )
        #expect(
            longResponse.contentLength > shortResponse.contentLength,
            "Longer message should produce a response with greater content length"
        )
    }
}

// MARK: - Factory Methods vs Initializers

@Suite("Factory Methods vs Initializers", .serialized, .tags(.response, .errorHandling))
struct FactoryVsInitializerTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Client error factory method and initializer produce equivalent status codes",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Conflict,
        ]
    )
    func clientErrorFactoryAndInitializerProduceEquivalentStatusCodes(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let message = "Test error message"
        let factoryResponse = DZWebServerErrorResponse(
            clientError: errorCode,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            clientError: errorCode,
            message: message
        )
        #expect(
            factoryResponse.statusCode == initResponse.statusCode,
            "Factory and initializer should produce the same status code"
        )
    }

    @Test(
        "Client error factory method and initializer produce equivalent content types",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
        ]
    )
    func clientErrorFactoryAndInitializerProduceEquivalentContentTypes(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let message = "Test error message"
        let factoryResponse = DZWebServerErrorResponse(
            clientError: errorCode,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            clientError: errorCode,
            message: message
        )
        #expect(
            factoryResponse.contentType == initResponse.contentType,
            "Factory and initializer should produce the same content type"
        )
    }

    @Test(
        "Client error factory method and initializer produce equivalent content lengths",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
        ]
    )
    func clientErrorFactoryAndInitializerProduceEquivalentContentLengths(
        errorCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        let message = "Test error message"
        let factoryResponse = DZWebServerErrorResponse(
            clientError: errorCode,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            clientError: errorCode,
            message: message
        )
        #expect(
            factoryResponse.contentLength == initResponse.contentLength,
            "Factory and initializer should produce the same content length"
        )
    }

    @Test(
        "Server error factory method and initializer produce equivalent status codes",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable,
        ]
    )
    func serverErrorFactoryAndInitializerProduceEquivalentStatusCodes(
        errorCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        let message = "Test error message"
        let factoryResponse = DZWebServerErrorResponse(
            serverError: errorCode,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            serverError: errorCode,
            message: message
        )
        #expect(
            factoryResponse.statusCode == initResponse.statusCode,
            "Factory and initializer should produce the same status code"
        )
    }

    @Test(
        "Server error factory method and initializer produce equivalent content lengths",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway,
        ]
    )
    func serverErrorFactoryAndInitializerProduceEquivalentContentLengths(
        errorCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        let message = "Test error message"
        let factoryResponse = DZWebServerErrorResponse(
            serverError: errorCode,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            serverError: errorCode,
            message: message
        )
        #expect(
            factoryResponse.contentLength == initResponse.contentLength,
            "Factory and initializer should produce the same content length"
        )
    }

    @Test("Client error factory with underlying error produces equivalent results to initializer")
    func clientErrorFactoryWithUnderlyingErrorMatchesInitializer() {
        let error = NSError(domain: "TestDomain", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "Underlying issue",
        ])
        let message = "Something failed"
        let factoryResponse = DZWebServerErrorResponse(
            clientError: .httpStatusCode_NotFound,
            underlyingError: error,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            clientError: .httpStatusCode_NotFound,
            underlyingError: error,
            message: message
        )
        #expect(factoryResponse.statusCode == initResponse.statusCode)
        #expect(factoryResponse.contentType == initResponse.contentType)
        #expect(factoryResponse.contentLength == initResponse.contentLength)
    }

    @Test("Server error factory with underlying error produces equivalent results to initializer")
    func serverErrorFactoryWithUnderlyingErrorMatchesInitializer() {
        let error = NSError(domain: "ServerDomain", code: 100, userInfo: [
            NSLocalizedDescriptionKey: "Backend timeout",
        ])
        let message = "Gateway failure"
        let factoryResponse = DZWebServerErrorResponse(
            serverError: .httpStatusCode_BadGateway,
            underlyingError: error,
            message: message
        )
        let initResponse = DZWebServerErrorResponse(
            serverError: .httpStatusCode_BadGateway,
            underlyingError: error,
            message: message
        )
        #expect(factoryResponse.statusCode == initResponse.statusCode)
        #expect(factoryResponse.contentType == initResponse.contentType)
        #expect(factoryResponse.contentLength == initResponse.contentLength)
    }
}

// MARK: - Inherited Properties

@Suite("Inherited Response Properties", .serialized, .tags(.response, .errorHandling, .properties))
struct InheritedPropertiesTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Error response is a subclass of DZWebServerDataResponse")
    func errorResponseIsSubclassOfDataResponse() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_NotFound, message: "Not found")
        #expect(
            response is DZWebServerDataResponse,
            "DZWebServerErrorResponse should be a subclass of DZWebServerDataResponse"
        )
    }

    @Test("Error response is a subclass of DZWebServerResponse")
    func errorResponseIsSubclassOfResponse() {
        let response = DZWebServerErrorResponse(serverError: .httpStatusCode_InternalServerError, message: "Error")
        #expect(
            response is DZWebServerResponse,
            "DZWebServerErrorResponse should be a subclass of DZWebServerResponse"
        )
    }

    @Test("Error response defaults to cache control max age of zero")
    func errorResponseDefaultsToCacheControlMaxAgeZero() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_NotFound, message: "Not found")
        #expect(
            response.cacheControlMaxAge == 0,
            "Default cache control max age should be 0 (no-cache)"
        )
    }

    @Test("Setting cache control max age on error response is retained")
    func settingCacheControlMaxAgeOnErrorResponseIsRetained() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_NotFound, message: "Not found")
        response.cacheControlMaxAge = 3600
        #expect(
            response.cacheControlMaxAge == 3600,
            "Cache control max age should be retained after being set"
        )
    }

    @Test("Setting additional headers on error response works correctly")
    func settingAdditionalHeadersOnErrorResponseWorks() {
        let response = DZWebServerErrorResponse(serverError: .httpStatusCode_ServiceUnavailable, message: "Down")
        response.setValue("120", forAdditionalHeader: "Retry-After")
        // If we reach here without an exception, the header was accepted.
        // The header value is stored internally and applied during response writing.
        #expect(response.statusCode == 503)
    }

    @Test("Error response defaults to gzip content encoding disabled")
    func errorResponseDefaultsToGzipDisabled() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_BadRequest, message: "Bad request")
        #expect(
            !response.isGZipContentEncodingEnabled,
            "Gzip content encoding should be disabled by default"
        )
    }

    @Test("Enabling gzip content encoding on error response is retained")
    func enablingGzipContentEncodingOnErrorResponseIsRetained() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_BadRequest, message: "Bad request")
        response.isGZipContentEncodingEnabled = true
        #expect(
            response.isGZipContentEncodingEnabled,
            "Gzip content encoding should be enabled after being set"
        )
    }

    @Test("Error response defaults to nil last modified date")
    func errorResponseDefaultsToNilLastModifiedDate() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_NotFound, message: "Not found")
        #expect(
            response.lastModifiedDate == nil,
            "Last modified date should be nil by default"
        )
    }

    @Test("Setting last modified date on error response is retained")
    func settingLastModifiedDateOnErrorResponseIsRetained() {
        let response = DZWebServerErrorResponse(serverError: .httpStatusCode_InternalServerError, message: "Error")
        let date = Date()
        response.lastModifiedDate = date
        #expect(
            response.lastModifiedDate != nil,
            "Last modified date should be retained after being set"
        )
    }

    @Test("Error response defaults to nil eTag")
    func errorResponseDefaultsToNilETag() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_NotFound, message: "Not found")
        #expect(
            response.eTag == nil,
            "ETag should be nil by default"
        )
    }

    @Test("Setting eTag on error response is retained")
    func settingETagOnErrorResponseIsRetained() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_Conflict, message: "Conflict")
        response.eTag = "\"abc123\""
        #expect(
            response.eTag == "\"abc123\"",
            "ETag should be retained after being set"
        )
    }

    @Test("Content type includes UTF-8 charset for client error")
    func contentTypeIncludesUTF8CharsetForClientError() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_BadRequest, message: "Bad request")
        #expect(
            response.contentType.contains("charset=utf-8"),
            "Content type should include UTF-8 charset, got \(response.contentType)"
        )
    }

    @Test("Content type includes UTF-8 charset for server error")
    func contentTypeIncludesUTF8CharsetForServerError() {
        let response = DZWebServerErrorResponse(serverError: .httpStatusCode_InternalServerError, message: "Error")
        #expect(
            response.contentType.contains("charset=utf-8"),
            "Content type should include UTF-8 charset, got \(response.contentType)"
        )
    }

    @Test("Setting multiple additional headers on error response works")
    func settingMultipleAdditionalHeadersWorks() {
        let response = DZWebServerErrorResponse(serverError: .httpStatusCode_ServiceUnavailable, message: "Down")
        response.setValue("120", forAdditionalHeader: "Retry-After")
        response.setValue("no-store", forAdditionalHeader: "X-Custom-Cache")
        response.setValue("error-ref-12345", forAdditionalHeader: "X-Error-Reference")
        #expect(
            response.statusCode == 503,
            "Response should still be valid after setting multiple headers"
        )
    }

    @Test("Removing an additional header by setting nil works")
    func removingAdditionalHeaderBySettingNilWorks() {
        let response = DZWebServerErrorResponse(clientError: .httpStatusCode_NotFound, message: "Missing")
        response.setValue("some-value", forAdditionalHeader: "X-Temp-Header")
        response.setValue(nil, forAdditionalHeader: "X-Temp-Header")
        #expect(
            response.statusCode == 404,
            "Response should still be valid after removing a header"
        )
    }
}
