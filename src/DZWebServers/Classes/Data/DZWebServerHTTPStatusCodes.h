/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @file DZWebServerHTTPStatusCodes.h
 * @brief Standard HTTP 1.1 status code constants organized by response class.
 *
 * Provides typed enumerations for the five classes of HTTP status codes as
 * defined in RFC 2616 Section 10 and the IANA HTTP Status Code Registry:
 *
 * - @c DZWebServerInformationalHTTPStatusCode (1xx) -- provisional responses
 * - @c DZWebServerSuccessfulHTTPStatusCode    (2xx) -- request succeeded
 * - @c DZWebServerRedirectionHTTPStatusCode   (3xx) -- further action needed
 * - @c DZWebServerClientErrorHTTPStatusCode   (4xx) -- client-side errors
 * - @c DZWebServerServerErrorHTTPStatusCode   (5xx) -- server-side errors
 *
 * @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
 * @see http://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Informational HTTP status codes (1xx).
 *
 * These codes indicate a provisional response. The client should continue
 * the request or ignore the response if the request is already finished.
 */
typedef NS_ENUM(NSInteger, DZWebServerInformationalHTTPStatusCode) {
  /** 100 -- The server has received the request headers and the client should proceed to send the body. */
  kDZWebServerHTTPStatusCode_Continue = 100,
  /** 101 -- The server is switching to the protocol requested by the client via the @c Upgrade header. */
  kDZWebServerHTTPStatusCode_SwitchingProtocols = 101,
  /** 102 -- The server has accepted the full request but has not yet completed it (WebDAV; RFC 2518). */
  kDZWebServerHTTPStatusCode_Processing = 102
};

/**
 * Successful HTTP status codes (2xx).
 *
 * These codes indicate that the client's request was successfully received,
 * understood, and accepted.
 */
typedef NS_ENUM(NSInteger, DZWebServerSuccessfulHTTPStatusCode) {
  /** 200 -- The request succeeded. The response body contains the requested resource. */
  kDZWebServerHTTPStatusCode_OK = 200,
  /** 201 -- The request was fulfilled and a new resource was created. */
  kDZWebServerHTTPStatusCode_Created = 201,
  /** 202 -- The request was accepted for processing, but processing has not completed. */
  kDZWebServerHTTPStatusCode_Accepted = 202,
  /** 203 -- The response metadata is not from the origin server (e.g., a local or third-party copy). */
  kDZWebServerHTTPStatusCode_NonAuthoritativeInformation = 203,
  /** 204 -- The request succeeded but there is no content to return. */
  kDZWebServerHTTPStatusCode_NoContent = 204,
  /** 205 -- The request succeeded; the client should reset the document view. */
  kDZWebServerHTTPStatusCode_ResetContent = 205,
  /** 206 -- The server is delivering only part of the resource due to a @c Range header. */
  kDZWebServerHTTPStatusCode_PartialContent = 206,
  /** 207 -- The response body contains multiple status codes for independent operations (WebDAV; RFC 4918). */
  kDZWebServerHTTPStatusCode_MultiStatus = 207,
  /** 208 -- Members of a DAV binding have already been enumerated and are not included again (WebDAV; RFC 5842). */
  kDZWebServerHTTPStatusCode_AlreadyReported = 208
};

/**
 * Redirection HTTP status codes (3xx).
 *
 * These codes indicate that further action is needed by the client to
 * fulfill the request, typically by following a different URI.
 */
typedef NS_ENUM(NSInteger, DZWebServerRedirectionHTTPStatusCode) {
  /** 300 -- The request has multiple possible responses; the client should choose one. */
  kDZWebServerHTTPStatusCode_MultipleChoices = 300,
  /** 301 -- The resource has been permanently moved to a new URI. */
  kDZWebServerHTTPStatusCode_MovedPermanently = 301,
  /** 302 -- The resource temporarily resides at a different URI. */
  kDZWebServerHTTPStatusCode_Found = 302,
  /** 303 -- The response can be found at another URI using a GET request. */
  kDZWebServerHTTPStatusCode_SeeOther = 303,
  /** 304 -- The resource has not been modified since the last request (conditional GET). */
  kDZWebServerHTTPStatusCode_NotModified = 304,
  /** 305 -- The resource must be accessed through the proxy given by the @c Location header. */
  kDZWebServerHTTPStatusCode_UseProxy = 305,
  /** 307 -- The resource temporarily resides at a different URI; the request method must not change. */
  kDZWebServerHTTPStatusCode_TemporaryRedirect = 307,
  /** 308 -- The resource has been permanently moved; the request method must not change (RFC 7538). */
  kDZWebServerHTTPStatusCode_PermanentRedirect = 308
};

/**
 * Client error HTTP status codes (4xx).
 *
 * These codes indicate that the request contains bad syntax or cannot be
 * fulfilled by the server due to an apparent client-side error.
 */
typedef NS_ENUM(NSInteger, DZWebServerClientErrorHTTPStatusCode) {
  /** 400 -- The request could not be understood due to malformed syntax. */
  kDZWebServerHTTPStatusCode_BadRequest = 400,
  /** 401 -- Authentication is required and has not been provided or has failed. */
  kDZWebServerHTTPStatusCode_Unauthorized = 401,
  /** 402 -- Reserved for future use (intended for digital payment schemes). */
  kDZWebServerHTTPStatusCode_PaymentRequired = 402,
  /** 403 -- The server understood the request but refuses to authorize it. */
  kDZWebServerHTTPStatusCode_Forbidden = 403,
  /** 404 -- The requested resource could not be found on the server. */
  kDZWebServerHTTPStatusCode_NotFound = 404,
  /** 405 -- The HTTP method is not allowed for the requested resource. */
  kDZWebServerHTTPStatusCode_MethodNotAllowed = 405,
  /** 406 -- The resource cannot generate content acceptable per the request's @c Accept headers. */
  kDZWebServerHTTPStatusCode_NotAcceptable = 406,
  /** 407 -- The client must first authenticate with the proxy. */
  kDZWebServerHTTPStatusCode_ProxyAuthenticationRequired = 407,
  /** 408 -- The server timed out waiting for the client's request. */
  kDZWebServerHTTPStatusCode_RequestTimeout = 408,
  /** 409 -- The request conflicts with the current state of the resource. */
  kDZWebServerHTTPStatusCode_Conflict = 409,
  /** 410 -- The resource is permanently gone and no forwarding address is known. */
  kDZWebServerHTTPStatusCode_Gone = 410,
  /** 411 -- The server requires a @c Content-Length header in the request. */
  kDZWebServerHTTPStatusCode_LengthRequired = 411,
  /** 412 -- One or more precondition headers evaluated to false on the server. */
  kDZWebServerHTTPStatusCode_PreconditionFailed = 412,
  /** 413 -- The request body is larger than the server is willing to process. */
  kDZWebServerHTTPStatusCode_RequestEntityTooLarge = 413,
  /** 414 -- The request URI is longer than the server is willing to interpret. */
  kDZWebServerHTTPStatusCode_RequestURITooLong = 414,
  /** 415 -- The request body's media type is not supported by the server. */
  kDZWebServerHTTPStatusCode_UnsupportedMediaType = 415,
  /** 416 -- The @c Range specified in the request header cannot be satisfied. */
  kDZWebServerHTTPStatusCode_RequestedRangeNotSatisfiable = 416,
  /** 417 -- The server cannot meet the expectation given in the @c Expect header. */
  kDZWebServerHTTPStatusCode_ExpectationFailed = 417,
  /** 422 -- The request is well-formed but contains semantic errors (WebDAV; RFC 4918). */
  kDZWebServerHTTPStatusCode_UnprocessableEntity = 422,
  /** 423 -- The resource being accessed is locked (WebDAV; RFC 4918). */
  kDZWebServerHTTPStatusCode_Locked = 423,
  /** 424 -- The request failed because it depended on another request that failed (WebDAV; RFC 4918). */
  kDZWebServerHTTPStatusCode_FailedDependency = 424,
  /** 426 -- The server refuses the request unless the client upgrades to a different protocol. */
  kDZWebServerHTTPStatusCode_UpgradeRequired = 426,
  /** 428 -- The server requires the request to be conditional (RFC 6585). */
  kDZWebServerHTTPStatusCode_PreconditionRequired = 428,
  /** 429 -- The client has sent too many requests in a given time period (RFC 6585). */
  kDZWebServerHTTPStatusCode_TooManyRequests = 429,
  /** 431 -- The request's header fields are too large for the server to process (RFC 6585). */
  kDZWebServerHTTPStatusCode_RequestHeaderFieldsTooLarge = 431
};

/**
 * Server error HTTP status codes (5xx).
 *
 * These codes indicate that the server failed to fulfill an apparently
 * valid request due to an internal error or temporary incapacity.
 */
typedef NS_ENUM(NSInteger, DZWebServerServerErrorHTTPStatusCode) {
  /** 500 -- The server encountered an unexpected condition that prevented it from fulfilling the request. */
  kDZWebServerHTTPStatusCode_InternalServerError = 500,
  /** 501 -- The server does not support the functionality required to fulfill the request. */
  kDZWebServerHTTPStatusCode_NotImplemented = 501,
  /** 502 -- The server, acting as a gateway, received an invalid response from the upstream server. */
  kDZWebServerHTTPStatusCode_BadGateway = 502,
  /** 503 -- The server is temporarily unable to handle the request (overload or maintenance). */
  kDZWebServerHTTPStatusCode_ServiceUnavailable = 503,
  /** 504 -- The server, acting as a gateway, did not receive a timely response from the upstream server. */
  kDZWebServerHTTPStatusCode_GatewayTimeout = 504,
  /** 505 -- The server does not support the HTTP protocol version used in the request. */
  kDZWebServerHTTPStatusCode_HTTPVersionNotSupported = 505,
  /** 507 -- The server cannot store the representation needed to complete the request (WebDAV; RFC 4918). */
  kDZWebServerHTTPStatusCode_InsufficientStorage = 507,
  /** 508 -- The server detected an infinite loop while processing the request (WebDAV; RFC 5842). */
  kDZWebServerHTTPStatusCode_LoopDetected = 508,
  /** 510 -- Further extensions to the request are required for the server to fulfill it (RFC 2774). */
  kDZWebServerHTTPStatusCode_NotExtended = 510,
  /** 511 -- The client needs to authenticate to gain network access (RFC 6585). */
  kDZWebServerHTTPStatusCode_NetworkAuthenticationRequired = 511
};

NS_ASSUME_NONNULL_END
