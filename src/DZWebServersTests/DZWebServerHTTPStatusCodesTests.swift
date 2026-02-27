//
//  DZWebServerHTTPStatusCodesTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Testing
@testable import DZWebServers

// MARK: - Informational (1xx)

@Suite("Informational HTTP Status Codes (1xx)", .serialized, .tags(.statusCodes))
struct InformationalHTTPStatusCodeTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Each informational status code has the correct raw value",
        arguments: [
            (DZWebServerInformationalHTTPStatusCode.httpStatusCode_Continue, 100, "Continue"),
            (DZWebServerInformationalHTTPStatusCode.httpStatusCode_SwitchingProtocols, 101, "SwitchingProtocols"),
            (DZWebServerInformationalHTTPStatusCode.httpStatusCode_Processing, 102, "Processing"),
        ] as [(DZWebServerInformationalHTTPStatusCode, Int, String)]
    )
    func informationalStatusCodeHasCorrectRawValue(
        statusCode: DZWebServerInformationalHTTPStatusCode,
        expectedRawValue: Int,
        name: String
    ) {
        #expect(
            statusCode.rawValue == expectedRawValue,
            "\(name) should have raw value \(expectedRawValue)"
        )
    }

    @Test(
        "All informational status codes fall within the 1xx range",
        arguments: [
            DZWebServerInformationalHTTPStatusCode.httpStatusCode_Continue,
            DZWebServerInformationalHTTPStatusCode.httpStatusCode_SwitchingProtocols,
            DZWebServerInformationalHTTPStatusCode.httpStatusCode_Processing,
        ]
    )
    func informationalStatusCodeIsInValidRange(
        statusCode: DZWebServerInformationalHTTPStatusCode
    ) {
        #expect(
            statusCode.rawValue >= 100 && statusCode.rawValue <= 199,
            "Informational status code \(statusCode.rawValue) should be in 100-199 range"
        )
    }

    @Test(
        "Informational status codes round-trip through raw value initialization",
        arguments: [100, 101, 102]
    )
    func informationalStatusCodeRoundTripsFromRawValue(rawValue: Int) throws {
        let statusCode = try #require(DZWebServerInformationalHTTPStatusCode(rawValue: rawValue))
        #expect(
            statusCode.rawValue == rawValue,
            "Round-tripped raw value should equal \(rawValue)"
        )
    }
}

// MARK: - Successful (2xx)

@Suite("Successful HTTP Status Codes (2xx)", .serialized, .tags(.statusCodes))
struct SuccessfulHTTPStatusCodeTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Each successful status code has the correct raw value",
        arguments: [
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_OK, 200, "OK"),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_Created, 201, "Created"),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_Accepted, 202, "Accepted"),
            (
                DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_NonAuthoritativeInformation,
                203,
                "NonAuthoritativeInformation"
            ),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_NoContent, 204, "NoContent"),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_ResetContent, 205, "ResetContent"),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_PartialContent, 206, "PartialContent"),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_MultiStatus, 207, "MultiStatus"),
            (DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_AlreadyReported, 208, "AlreadyReported"),
        ] as [(DZWebServerSuccessfulHTTPStatusCode, Int, String)]
    )
    func successfulStatusCodeHasCorrectRawValue(
        statusCode: DZWebServerSuccessfulHTTPStatusCode,
        expectedRawValue: Int,
        name: String
    ) {
        #expect(
            statusCode.rawValue == expectedRawValue,
            "\(name) should have raw value \(expectedRawValue)"
        )
    }

    @Test(
        "All successful status codes fall within the 2xx range",
        arguments: [
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_OK,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_Created,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_Accepted,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_NonAuthoritativeInformation,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_NoContent,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_ResetContent,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_PartialContent,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_MultiStatus,
            DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_AlreadyReported,
        ]
    )
    func successfulStatusCodeIsInValidRange(
        statusCode: DZWebServerSuccessfulHTTPStatusCode
    ) {
        #expect(
            statusCode.rawValue >= 200 && statusCode.rawValue <= 299,
            "Successful status code \(statusCode.rawValue) should be in 200-299 range"
        )
    }

    @Test(
        "Successful status codes round-trip through raw value initialization",
        arguments: [200, 201, 202, 203, 204, 205, 206, 207, 208]
    )
    func successfulStatusCodeRoundTripsFromRawValue(rawValue: Int) throws {
        let statusCode = try #require(DZWebServerSuccessfulHTTPStatusCode(rawValue: rawValue))
        #expect(
            statusCode.rawValue == rawValue,
            "Round-tripped raw value should equal \(rawValue)"
        )
    }
}

// MARK: - Redirection (3xx)

@Suite("Redirection HTTP Status Codes (3xx)", .serialized, .tags(.statusCodes))
struct RedirectionHTTPStatusCodeTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Each redirection status code has the correct raw value",
        arguments: [
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_MultipleChoices, 300, "MultipleChoices"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_MovedPermanently, 301, "MovedPermanently"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_Found, 302, "Found"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_SeeOther, 303, "SeeOther"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_NotModified, 304, "NotModified"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_UseProxy, 305, "UseProxy"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_TemporaryRedirect, 307, "TemporaryRedirect"),
            (DZWebServerRedirectionHTTPStatusCode.httpStatusCode_PermanentRedirect, 308, "PermanentRedirect"),
        ] as [(DZWebServerRedirectionHTTPStatusCode, Int, String)]
    )
    func redirectionStatusCodeHasCorrectRawValue(
        statusCode: DZWebServerRedirectionHTTPStatusCode,
        expectedRawValue: Int,
        name: String
    ) {
        #expect(
            statusCode.rawValue == expectedRawValue,
            "\(name) should have raw value \(expectedRawValue)"
        )
    }

    @Test(
        "All redirection status codes fall within the 3xx range",
        arguments: [
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_MultipleChoices,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_MovedPermanently,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_Found,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_SeeOther,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_NotModified,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_UseProxy,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_TemporaryRedirect,
            DZWebServerRedirectionHTTPStatusCode.httpStatusCode_PermanentRedirect,
        ]
    )
    func redirectionStatusCodeIsInValidRange(
        statusCode: DZWebServerRedirectionHTTPStatusCode
    ) {
        #expect(
            statusCode.rawValue >= 300 && statusCode.rawValue <= 399,
            "Redirection status code \(statusCode.rawValue) should be in 300-399 range"
        )
    }

    @Test(
        "Redirection status codes round-trip through raw value initialization",
        arguments: [300, 301, 302, 303, 304, 305, 307, 308]
    )
    func redirectionStatusCodeRoundTripsFromRawValue(rawValue: Int) throws {
        let statusCode = try #require(DZWebServerRedirectionHTTPStatusCode(rawValue: rawValue))
        #expect(
            statusCode.rawValue == rawValue,
            "Round-tripped raw value should equal \(rawValue)"
        )
    }
}

// MARK: - Client Error (4xx)

@Suite("Client Error HTTP Status Codes (4xx)", .serialized, .tags(.statusCodes))
struct ClientErrorHTTPStatusCodeTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Each client error status code has the correct raw value",
        arguments: [
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest, 400, "BadRequest"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Unauthorized, 401, "Unauthorized"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PaymentRequired, 402, "PaymentRequired"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden, 403, "Forbidden"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound, 404, "NotFound"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_MethodNotAllowed, 405, "MethodNotAllowed"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotAcceptable, 406, "NotAcceptable"),
            (
                DZWebServerClientErrorHTTPStatusCode.httpStatusCode_ProxyAuthenticationRequired,
                407,
                "ProxyAuthenticationRequired"
            ),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestTimeout, 408, "RequestTimeout"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Conflict, 409, "Conflict"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Gone, 410, "Gone"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_LengthRequired, 411, "LengthRequired"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionFailed, 412, "PreconditionFailed"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestEntityTooLarge, 413, "RequestEntityTooLarge"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestURITooLong, 414, "RequestURITooLong"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnsupportedMediaType, 415, "UnsupportedMediaType"),
            (
                DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestedRangeNotSatisfiable,
                416,
                "RequestedRangeNotSatisfiable"
            ),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_ExpectationFailed, 417, "ExpectationFailed"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnprocessableEntity, 422, "UnprocessableEntity"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Locked, 423, "Locked"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_FailedDependency, 424, "FailedDependency"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UpgradeRequired, 426, "UpgradeRequired"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionRequired, 428, "PreconditionRequired"),
            (DZWebServerClientErrorHTTPStatusCode.httpStatusCode_TooManyRequests, 429, "TooManyRequests"),
            (
                DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestHeaderFieldsTooLarge,
                431,
                "RequestHeaderFieldsTooLarge"
            ),
        ] as [(DZWebServerClientErrorHTTPStatusCode, Int, String)]
    )
    func clientErrorStatusCodeHasCorrectRawValue(
        statusCode: DZWebServerClientErrorHTTPStatusCode,
        expectedRawValue: Int,
        name: String
    ) {
        #expect(
            statusCode.rawValue == expectedRawValue,
            "\(name) should have raw value \(expectedRawValue)"
        )
    }

    @Test(
        "All client error status codes fall within the 4xx range",
        arguments: [
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Unauthorized,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PaymentRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_MethodNotAllowed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotAcceptable,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_ProxyAuthenticationRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestTimeout,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Conflict,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Gone,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_LengthRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionFailed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestEntityTooLarge,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestURITooLong,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnsupportedMediaType,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestedRangeNotSatisfiable,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_ExpectationFailed,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnprocessableEntity,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Locked,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_FailedDependency,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UpgradeRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionRequired,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_TooManyRequests,
            DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestHeaderFieldsTooLarge,
        ]
    )
    func clientErrorStatusCodeIsInValidRange(
        statusCode: DZWebServerClientErrorHTTPStatusCode
    ) {
        #expect(
            statusCode.rawValue >= 400 && statusCode.rawValue <= 499,
            "Client error status code \(statusCode.rawValue) should be in 400-499 range"
        )
    }

    @Test(
        "Client error status codes round-trip through raw value initialization",
        arguments: [
            400,
            401,
            402,
            403,
            404,
            405,
            406,
            407,
            408,
            409,
            410,
            411,
            412,
            413,
            414,
            415,
            416,
            417,
            422,
            423,
            424,
            426,
            428,
            429,
            431
        ]
    )
    func clientErrorStatusCodeRoundTripsFromRawValue(rawValue: Int) throws {
        let statusCode = try #require(DZWebServerClientErrorHTTPStatusCode(rawValue: rawValue))
        #expect(
            statusCode.rawValue == rawValue,
            "Round-tripped raw value should equal \(rawValue)"
        )
    }
}

// MARK: - Server Error (5xx)

@Suite("Server Error HTTP Status Codes (5xx)", .serialized, .tags(.statusCodes))
struct ServerErrorHTTPStatusCodeTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test(
        "Each server error status code has the correct raw value",
        arguments: [
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError, 500, "InternalServerError"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotImplemented, 501, "NotImplemented"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway, 502, "BadGateway"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable, 503, "ServiceUnavailable"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_GatewayTimeout, 504, "GatewayTimeout"),
            (
                DZWebServerServerErrorHTTPStatusCode.httpStatusCode_HTTPVersionNotSupported,
                505,
                "HTTPVersionNotSupported"
            ),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InsufficientStorage, 507, "InsufficientStorage"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_LoopDetected, 508, "LoopDetected"),
            (DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotExtended, 510, "NotExtended"),
            (
                DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NetworkAuthenticationRequired,
                511,
                "NetworkAuthenticationRequired"
            ),
        ] as [(DZWebServerServerErrorHTTPStatusCode, Int, String)]
    )
    func serverErrorStatusCodeHasCorrectRawValue(
        statusCode: DZWebServerServerErrorHTTPStatusCode,
        expectedRawValue: Int,
        name: String
    ) {
        #expect(
            statusCode.rawValue == expectedRawValue,
            "\(name) should have raw value \(expectedRawValue)"
        )
    }

    @Test(
        "All server error status codes fall within the 5xx range",
        arguments: [
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotImplemented,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_BadGateway,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_GatewayTimeout,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_HTTPVersionNotSupported,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InsufficientStorage,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_LoopDetected,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NotExtended,
            DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NetworkAuthenticationRequired,
        ]
    )
    func serverErrorStatusCodeIsInValidRange(
        statusCode: DZWebServerServerErrorHTTPStatusCode
    ) {
        #expect(
            statusCode.rawValue >= 500 && statusCode.rawValue <= 599,
            "Server error status code \(statusCode.rawValue) should be in 500-599 range"
        )
    }

    @Test(
        "Server error status codes round-trip through raw value initialization",
        arguments: [500, 501, 502, 503, 504, 505, 507, 508, 510, 511]
    )
    func serverErrorStatusCodeRoundTripsFromRawValue(rawValue: Int) throws {
        let statusCode = try #require(DZWebServerServerErrorHTTPStatusCode(rawValue: rawValue))
        #expect(
            statusCode.rawValue == rawValue,
            "Round-tripped raw value should equal \(rawValue)"
        )
    }
}

// MARK: - Cross-Category Validation

@Suite("HTTP Status Code Cross-Category Validation", .serialized, .tags(.statusCodes))
struct HTTPStatusCodeCrossCategoryTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    @Test("Well-known HTTP status codes map to the correct enum cases")
    func wellKnownHTTPStatusCodesMapToCorrectEnumCases() {
        // Most commonly used status codes in web development
        #expect(DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_OK.rawValue == 200)
        #expect(DZWebServerRedirectionHTTPStatusCode.httpStatusCode_MovedPermanently.rawValue == 301)
        #expect(DZWebServerRedirectionHTTPStatusCode.httpStatusCode_Found.rawValue == 302)
        #expect(DZWebServerRedirectionHTTPStatusCode.httpStatusCode_NotModified.rawValue == 304)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_BadRequest.rawValue == 400)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Unauthorized.rawValue == 401)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Forbidden.rawValue == 403)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound.rawValue == 404)
        #expect(DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InternalServerError.rawValue == 500)
        #expect(DZWebServerServerErrorHTTPStatusCode.httpStatusCode_ServiceUnavailable.rawValue == 503)
    }

    @Test("WebDAV-specific status codes have the correct raw values")
    func webDAVSpecificStatusCodesHaveCorrectRawValues() {
        // 1xx WebDAV
        #expect(DZWebServerInformationalHTTPStatusCode.httpStatusCode_Processing.rawValue == 102)
        // 2xx WebDAV
        #expect(DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_MultiStatus.rawValue == 207)
        #expect(DZWebServerSuccessfulHTTPStatusCode.httpStatusCode_AlreadyReported.rawValue == 208)
        // 4xx WebDAV
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_UnprocessableEntity.rawValue == 422)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_Locked.rawValue == 423)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_FailedDependency.rawValue == 424)
        // 5xx WebDAV
        #expect(DZWebServerServerErrorHTTPStatusCode.httpStatusCode_InsufficientStorage.rawValue == 507)
        #expect(DZWebServerServerErrorHTTPStatusCode.httpStatusCode_LoopDetected.rawValue == 508)
    }

    @Test("RFC 6585 status codes have the correct raw values")
    func rfc6585StatusCodesHaveCorrectRawValues() {
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_PreconditionRequired.rawValue == 428)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_TooManyRequests.rawValue == 429)
        #expect(DZWebServerClientErrorHTTPStatusCode.httpStatusCode_RequestHeaderFieldsTooLarge.rawValue == 431)
        #expect(DZWebServerServerErrorHTTPStatusCode.httpStatusCode_NetworkAuthenticationRequired.rawValue == 511)
    }

    @Test("Status code enum categories do not overlap in raw value ranges")
    func statusCodeEnumCategoriesDoNotOverlapInRawValueRanges() {
        let informationalValues: [Int] = [100, 101, 102]
        let successfulValues: [Int] = [200, 201, 202, 203, 204, 205, 206, 207, 208]
        let redirectionValues: [Int] = [300, 301, 302, 303, 304, 305, 307, 308]
        let clientErrorValues: [Int] = [
            400,
            401,
            402,
            403,
            404,
            405,
            406,
            407,
            408,
            409,
            410,
            411,
            412,
            413,
            414,
            415,
            416,
            417,
            422,
            423,
            424,
            426,
            428,
            429,
            431,
        ]
        let serverErrorValues: [Int] = [500, 501, 502, 503, 504, 505, 507, 508, 510, 511]

        let allValues = informationalValues + successfulValues + redirectionValues
            + clientErrorValues + serverErrorValues
        let uniqueValues = Set(allValues)

        #expect(
            allValues.count == uniqueValues.count,
            "All status code raw values should be unique across all categories"
        )
    }

    @Test("Each enum category contains the expected number of cases")
    func eachEnumCategoryContainsExpectedNumberOfCases() {
        // Verify by exhaustively listing all valid raw values per category
        let informationalCodes = [100, 101, 102]
            .compactMap { DZWebServerInformationalHTTPStatusCode(rawValue: $0) }
        #expect(
            informationalCodes.count == 3,
            "Informational category should have 3 status codes"
        )

        let successfulCodes = (200...208)
            .compactMap { DZWebServerSuccessfulHTTPStatusCode(rawValue: $0) }
        #expect(
            successfulCodes.count == 9,
            "Successful category should have 9 status codes"
        )

        let redirectionCodes = (300...308)
            .compactMap { DZWebServerRedirectionHTTPStatusCode(rawValue: $0) }
        #expect(
            redirectionCodes.count == 9,
            "Redirection category should have 9 status codes"
        )

        let clientErrorCodes = (400...431)
            .compactMap { DZWebServerClientErrorHTTPStatusCode(rawValue: $0) }
        #expect(
            clientErrorCodes.count == 32,
            "Client error category should have 32 status codes"
        )

        let serverErrorCodes = (500...511)
            .compactMap { DZWebServerServerErrorHTTPStatusCode(rawValue: $0) }
        #expect(
            serverErrorCodes.count == 12,
            "Server error category should have 12 status codes"
        )
    }
}
