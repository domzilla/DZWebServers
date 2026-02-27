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

#import "DZWebServerDataResponse.h"
#import "DZWebServerHTTPStatusCodes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief A response subclass that generates an HTML error page from an HTTP status code and message.
 *
 *  @c DZWebServerErrorResponse extends @c DZWebServerDataResponse to produce a minimal,
 *  self-contained HTML page whose title and body reflect the given HTTP error status code
 *  and a human-readable error message. When an optional @c NSError is provided, its domain,
 *  localized description, and code are rendered in a secondary heading beneath the message.
 *
 *  The class is split into two families of methods -- client errors (4xx) and server errors
 *  (5xx) -- each available as both factory methods and initializers. Every family offers
 *  a variadic @c message: variant (Objective-C only) and a @c formattedMessage: variant
 *  that is accessible from both Objective-C and Swift.
 *
 *  @note The generated HTML sets the response content type to @c text/html with UTF-8
 *        encoding and the status code on the response to the value of @c errorCode.
 *
 *  @see DZWebServerClientErrorHTTPStatusCode
 *  @see DZWebServerServerErrorHTTPStatusCode
 *  @see DZWebServerDataResponse
 */
@interface DZWebServerErrorResponse : DZWebServerDataResponse

// ---------------------------------------------------------------------------
/// @name Factory Methods -- Client Errors (4xx)
// ---------------------------------------------------------------------------

/**
 *  @brief Creates a client error response with the given HTTP 4xx status code and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message displayed in the HTML body.
 *
 *  @param errorCode A client error HTTP status code (400--499).
 *  @param format    A format string describing the error, followed by a comma-separated
 *                   list of arguments to substitute into the format string.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c responseWithClientError:formattedMessage: instead.
 *
 *  @see responseWithClientError:formattedMessage:
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use responseWithClientError:formattedMessage: instead");

/**
 *  @brief Creates a client error response with the given HTTP 4xx status code and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c responseWithClientError:message: that accepts
 *  an already-formatted string rather than a variadic format.
 *
 *  @param errorCode A client error HTTP status code (400--499).
 *  @param message   A pre-formatted string describing the error.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @see responseWithClientError:underlyingError:formattedMessage:
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message;

/**
 *  @brief Creates a client error response with the given HTTP 4xx status code, an underlying error, and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message. If @a underlyingError is non-nil, its domain, localized
 *  description, and error code are rendered as a secondary heading in the HTML body.
 *
 *  @param errorCode       A client error HTTP status code (400--499).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param format          A format string describing the error, followed by a comma-separated
 *                         list of arguments to substitute into the format string.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c responseWithClientError:underlyingError:formattedMessage: instead.
 *
 *  @see responseWithClientError:underlyingError:formattedMessage:
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use responseWithClientError:underlyingError:formattedMessage: instead");

/**
 *  @brief Creates a client error response with the given HTTP 4xx status code, an underlying error, and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c responseWithClientError:underlyingError:message:
 *  that accepts an already-formatted string rather than a variadic format.
 *
 *  @param errorCode       A client error HTTP status code (400--499).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param message         A pre-formatted string describing the error.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @see responseWithClientError:formattedMessage:
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message;

// ---------------------------------------------------------------------------
/// @name Factory Methods -- Server Errors (5xx)
// ---------------------------------------------------------------------------

/**
 *  @brief Creates a server error response with the given HTTP 5xx status code and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message displayed in the HTML body.
 *
 *  @param errorCode A server error HTTP status code (500--599).
 *  @param format    A format string describing the error, followed by a comma-separated
 *                   list of arguments to substitute into the format string.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c responseWithServerError:formattedMessage: instead.
 *
 *  @see responseWithServerError:formattedMessage:
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use responseWithServerError:formattedMessage: instead");

/**
 *  @brief Creates a server error response with the given HTTP 5xx status code and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c responseWithServerError:message: that accepts
 *  an already-formatted string rather than a variadic format.
 *
 *  @param errorCode A server error HTTP status code (500--599).
 *  @param message   A pre-formatted string describing the error.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @see responseWithServerError:underlyingError:formattedMessage:
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message;

/**
 *  @brief Creates a server error response with the given HTTP 5xx status code, an underlying error, and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message. If @a underlyingError is non-nil, its domain, localized
 *  description, and error code are rendered as a secondary heading in the HTML body.
 *
 *  @param errorCode       A server error HTTP status code (500--599).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param format          A format string describing the error, followed by a comma-separated
 *                         list of arguments to substitute into the format string.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c responseWithServerError:underlyingError:formattedMessage: instead.
 *
 *  @see responseWithServerError:underlyingError:formattedMessage:
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use responseWithServerError:underlyingError:formattedMessage: instead");

/**
 *  @brief Creates a server error response with the given HTTP 5xx status code, an underlying error, and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c responseWithServerError:underlyingError:message:
 *  that accepts an already-formatted string rather than a variadic format.
 *
 *  @param errorCode       A server error HTTP status code (500--599).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param message         A pre-formatted string describing the error.
 *  @return A new error response whose @c statusCode is set to @a errorCode.
 *
 *  @see responseWithServerError:formattedMessage:
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message;

// ---------------------------------------------------------------------------
/// @name Initializers -- Client Errors (4xx)
// ---------------------------------------------------------------------------

/**
 *  @brief Initializes a client error response with the given HTTP 4xx status code and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message displayed in the HTML body.
 *
 *  @param errorCode A client error HTTP status code (400--499).
 *  @param format    A format string describing the error, followed by a comma-separated
 *                   list of arguments to substitute into the format string.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c initWithClientError:formattedMessage: instead.
 *
 *  @see initWithClientError:formattedMessage:
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use initWithClientError:formattedMessage: instead");

/**
 *  @brief Initializes a client error response with the given HTTP 4xx status code and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c initWithClientError:message: that accepts
 *  an already-formatted string rather than a variadic format.
 *
 *  @param errorCode A client error HTTP status code (400--499).
 *  @param message   A pre-formatted string describing the error.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @see initWithClientError:underlyingError:formattedMessage:
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(clientError:message:));

/**
 *  @brief Initializes a client error response with the given HTTP 4xx status code, an underlying error, and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message. If @a underlyingError is non-nil, its domain, localized
 *  description, and error code are rendered as a secondary heading in the HTML body.
 *
 *  @param errorCode       A client error HTTP status code (400--499).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param format          A format string describing the error, followed by a comma-separated
 *                         list of arguments to substitute into the format string.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c initWithClientError:underlyingError:formattedMessage: instead.
 *
 *  @see initWithClientError:underlyingError:formattedMessage:
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use initWithClientError:underlyingError:formattedMessage: instead");

/**
 *  @brief Initializes a client error response with the given HTTP 4xx status code, an underlying error, and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c initWithClientError:underlyingError:message:
 *  that accepts an already-formatted string rather than a variadic format.
 *
 *  @param errorCode       A client error HTTP status code (400--499).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param message         A pre-formatted string describing the error.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @see initWithClientError:formattedMessage:
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(clientError:underlyingError:message:));

// ---------------------------------------------------------------------------
/// @name Initializers -- Server Errors (5xx)
// ---------------------------------------------------------------------------

/**
 *  @brief Initializes a server error response with the given HTTP 5xx status code and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message displayed in the HTML body.
 *
 *  @param errorCode A server error HTTP status code (500--599).
 *  @param format    A format string describing the error, followed by a comma-separated
 *                   list of arguments to substitute into the format string.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c initWithServerError:formattedMessage: instead.
 *
 *  @see initWithServerError:formattedMessage:
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use initWithServerError:formattedMessage: instead");

/**
 *  @brief Initializes a server error response with the given HTTP 5xx status code and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c initWithServerError:message: that accepts
 *  an already-formatted string rather than a variadic format.
 *
 *  @param errorCode A server error HTTP status code (500--599).
 *  @param message   A pre-formatted string describing the error.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @see initWithServerError:underlyingError:formattedMessage:
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(serverError:message:));

/**
 *  @brief Initializes a server error response with the given HTTP 5xx status code, an underlying error, and a formatted message.
 *
 *  The format string and subsequent arguments are combined using @c NSString format specifiers
 *  to produce the error message. If @a underlyingError is non-nil, its domain, localized
 *  description, and error code are rendered as a secondary heading in the HTML body.
 *
 *  @param errorCode       A server error HTTP status code (500--599).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param format          A format string describing the error, followed by a comma-separated
 *                         list of arguments to substitute into the format string.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @note This method is unavailable in Swift. Use @c initWithServerError:underlyingError:formattedMessage: instead.
 *
 *  @see initWithServerError:underlyingError:formattedMessage:
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use initWithServerError:underlyingError:formattedMessage: instead");

/**
 *  @brief Initializes a server error response with the given HTTP 5xx status code, an underlying error, and a pre-formatted message.
 *
 *  This is the Swift-friendly alternative to @c initWithServerError:underlyingError:message:
 *  that accepts an already-formatted string rather than a variadic format.
 *
 *  @param errorCode       A server error HTTP status code (500--599).
 *  @param underlyingError An optional @c NSError providing additional context. Pass @c nil if not applicable.
 *  @param message         A pre-formatted string describing the error.
 *  @return An initialized error response whose @c statusCode is set to @a errorCode.
 *
 *  @see initWithServerError:formattedMessage:
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(serverError:underlyingError:message:));

@end

NS_ASSUME_NONNULL_END
