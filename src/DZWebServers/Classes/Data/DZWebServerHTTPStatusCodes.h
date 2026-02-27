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

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
// http://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Convenience constants for "informational" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, DZWebServerInformationalHTTPStatusCode) {
  kDZWebServerHTTPStatusCode_Continue = 100,
  kDZWebServerHTTPStatusCode_SwitchingProtocols = 101,
  kDZWebServerHTTPStatusCode_Processing = 102
};

/**
 *  Convenience constants for "successful" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, DZWebServerSuccessfulHTTPStatusCode) {
  kDZWebServerHTTPStatusCode_OK = 200,
  kDZWebServerHTTPStatusCode_Created = 201,
  kDZWebServerHTTPStatusCode_Accepted = 202,
  kDZWebServerHTTPStatusCode_NonAuthoritativeInformation = 203,
  kDZWebServerHTTPStatusCode_NoContent = 204,
  kDZWebServerHTTPStatusCode_ResetContent = 205,
  kDZWebServerHTTPStatusCode_PartialContent = 206,
  kDZWebServerHTTPStatusCode_MultiStatus = 207,
  kDZWebServerHTTPStatusCode_AlreadyReported = 208
};

/**
 *  Convenience constants for "redirection" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, DZWebServerRedirectionHTTPStatusCode) {
  kDZWebServerHTTPStatusCode_MultipleChoices = 300,
  kDZWebServerHTTPStatusCode_MovedPermanently = 301,
  kDZWebServerHTTPStatusCode_Found = 302,
  kDZWebServerHTTPStatusCode_SeeOther = 303,
  kDZWebServerHTTPStatusCode_NotModified = 304,
  kDZWebServerHTTPStatusCode_UseProxy = 305,
  kDZWebServerHTTPStatusCode_TemporaryRedirect = 307,
  kDZWebServerHTTPStatusCode_PermanentRedirect = 308
};

/**
 *  Convenience constants for "client error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, DZWebServerClientErrorHTTPStatusCode) {
  kDZWebServerHTTPStatusCode_BadRequest = 400,
  kDZWebServerHTTPStatusCode_Unauthorized = 401,
  kDZWebServerHTTPStatusCode_PaymentRequired = 402,
  kDZWebServerHTTPStatusCode_Forbidden = 403,
  kDZWebServerHTTPStatusCode_NotFound = 404,
  kDZWebServerHTTPStatusCode_MethodNotAllowed = 405,
  kDZWebServerHTTPStatusCode_NotAcceptable = 406,
  kDZWebServerHTTPStatusCode_ProxyAuthenticationRequired = 407,
  kDZWebServerHTTPStatusCode_RequestTimeout = 408,
  kDZWebServerHTTPStatusCode_Conflict = 409,
  kDZWebServerHTTPStatusCode_Gone = 410,
  kDZWebServerHTTPStatusCode_LengthRequired = 411,
  kDZWebServerHTTPStatusCode_PreconditionFailed = 412,
  kDZWebServerHTTPStatusCode_RequestEntityTooLarge = 413,
  kDZWebServerHTTPStatusCode_RequestURITooLong = 414,
  kDZWebServerHTTPStatusCode_UnsupportedMediaType = 415,
  kDZWebServerHTTPStatusCode_RequestedRangeNotSatisfiable = 416,
  kDZWebServerHTTPStatusCode_ExpectationFailed = 417,
  kDZWebServerHTTPStatusCode_UnprocessableEntity = 422,
  kDZWebServerHTTPStatusCode_Locked = 423,
  kDZWebServerHTTPStatusCode_FailedDependency = 424,
  kDZWebServerHTTPStatusCode_UpgradeRequired = 426,
  kDZWebServerHTTPStatusCode_PreconditionRequired = 428,
  kDZWebServerHTTPStatusCode_TooManyRequests = 429,
  kDZWebServerHTTPStatusCode_RequestHeaderFieldsTooLarge = 431
};

/**
 *  Convenience constants for "server error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, DZWebServerServerErrorHTTPStatusCode) {
  kDZWebServerHTTPStatusCode_InternalServerError = 500,
  kDZWebServerHTTPStatusCode_NotImplemented = 501,
  kDZWebServerHTTPStatusCode_BadGateway = 502,
  kDZWebServerHTTPStatusCode_ServiceUnavailable = 503,
  kDZWebServerHTTPStatusCode_GatewayTimeout = 504,
  kDZWebServerHTTPStatusCode_HTTPVersionNotSupported = 505,
  kDZWebServerHTTPStatusCode_InsufficientStorage = 507,
  kDZWebServerHTTPStatusCode_LoopDetected = 508,
  kDZWebServerHTTPStatusCode_NotExtended = 510,
  kDZWebServerHTTPStatusCode_NetworkAuthenticationRequired = 511
};

NS_ASSUME_NONNULL_END
