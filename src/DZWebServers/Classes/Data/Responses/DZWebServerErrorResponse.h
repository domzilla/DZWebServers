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
 *  The DZWebServerDataResponse subclass of DZWebServerDataResponse generates
 *  an HTML body from an HTTP status code and an error message.
 */
@interface DZWebServerErrorResponse : DZWebServerDataResponse

/**
 *  Creates a client error response with the corresponding HTTP status code.
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use responseWithClientError:formattedMessage: instead");

/**
 *  Creates a client error response with the corresponding HTTP status code
 *  and a pre-formatted message string.
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message;

/**
 *  Creates a server error response with the corresponding HTTP status code.
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use responseWithServerError:formattedMessage: instead");

/**
 *  Creates a server error response with the corresponding HTTP status code
 *  and a pre-formatted message string.
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message;

/**
 *  Creates a client error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use responseWithClientError:underlyingError:formattedMessage: instead");

/**
 *  Creates a client error response with the corresponding HTTP status code,
 *  an underlying NSError, and a pre-formatted message string.
 */
+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message;

/**
 *  Creates a server error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use responseWithServerError:underlyingError:formattedMessage: instead");

/**
 *  Creates a server error response with the corresponding HTTP status code,
 *  an underlying NSError, and a pre-formatted message string.
 */
+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message;

/**
 *  Initializes a client error response with the corresponding HTTP status code.
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use initWithClientError:formattedMessage: instead");

/**
 *  Initializes a client error response with the corresponding HTTP status code
 *  and a pre-formatted message string.
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(clientError:message:));

/**
 *  Initializes a server error response with the corresponding HTTP status code.
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3) NS_SWIFT_UNAVAILABLE("Use initWithServerError:formattedMessage: instead");

/**
 *  Initializes a server error response with the corresponding HTTP status code
 *  and a pre-formatted message string.
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(serverError:message:));

/**
 *  Initializes a client error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use initWithClientError:underlyingError:formattedMessage: instead");

/**
 *  Initializes a client error response with the corresponding HTTP status code,
 *  an underlying NSError, and a pre-formatted message string.
 */
- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(clientError:underlyingError:message:));

/**
 *  Initializes a server error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4) NS_SWIFT_UNAVAILABLE("Use initWithServerError:underlyingError:formattedMessage: instead");

/**
 *  Initializes a server error response with the corresponding HTTP status code,
 *  an underlying NSError, and a pre-formatted message string.
 */
- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError formattedMessage:(NSString*)message
    NS_SWIFT_NAME(init(serverError:underlyingError:message:));

@end

NS_ASSUME_NONNULL_END
