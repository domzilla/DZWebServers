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

#import "DZWebServerResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief A block that provides successive chunks of HTTP body data synchronously.
 *
 *  The server calls this block repeatedly to obtain the next chunk of streamed
 *  response data. The block is invoked on an internal GCD thread managed by the
 *  server connection.
 *
 *  @param error A pointer to an @c NSError variable. Guaranteed to be non-NULL.
 *               On failure the block must set this to a valid @c NSError and return @c nil.
 *
 *  @return A non-empty @c NSData containing the next chunk of body data,
 *          an empty @c NSData (length 0) to signal that streaming is complete,
 *          or @c nil to indicate an error (in which case @a error must be set).
 *
 *  @see DZWebServerAsyncStreamBlock
 */
typedef NSData* _Nullable (^DZWebServerStreamBlock)(NSError** error);

/**
 *  @brief A block that provides successive chunks of HTTP body data asynchronously.
 *
 *  Works like @c DZWebServerStreamBlock except the data does not need to be
 *  available immediately. The block may defer data production to another queue
 *  or wait for an external event before delivering the next chunk, enabling
 *  truly asynchronous response generation.
 *
 *  The server calls this block repeatedly. Each invocation must eventually call
 *  @a completionBlock exactly once with the result.
 *
 *  @param completionBlock A @c DZWebServerBodyReaderCompletionBlock that the
 *         block must call exactly once per invocation, passing:
 *         @li A non-empty @c NSData containing the next chunk of body data, or
 *         @li An empty @c NSData (length 0) to signal that streaming is complete, or
 *         @li @c nil together with a non-nil @c NSError to indicate an error.
 *
 *  @warning The @a completionBlock must not be called more than once per invocation.
 *
 *  @see DZWebServerStreamBlock
 *  @see DZWebServerBodyReaderCompletionBlock
 */
typedef void (^DZWebServerAsyncStreamBlock)(DZWebServerBodyReaderCompletionBlock completionBlock);

/**
 *  @brief A response subclass that streams its HTTP body via a caller-supplied block.
 *
 *  @c DZWebServerStreamedResponse delivers the response body incrementally
 *  through a block that is called repeatedly until the stream signals completion
 *  or an error. Because the total content length is unknown ahead of time, the
 *  server automatically uses chunked transfer encoding (HTTP/1.1).
 *
 *  Two streaming modes are supported:
 *  @li **Synchronous** -- provide a @c DZWebServerStreamBlock that returns data
 *      directly each time it is called.
 *  @li **Asynchronous** -- provide a @c DZWebServerAsyncStreamBlock that can
 *      deliver data at a later time via a completion callback, enabling truly
 *      non-blocking response generation.
 *
 *  @note The synchronous variant is internally wrapped into an asynchronous block,
 *        so both paths share the same underlying mechanism.
 *
 *  @see DZWebServerStreamBlock
 *  @see DZWebServerAsyncStreamBlock
 *  @see DZWebServerResponse
 */
@interface DZWebServerStreamedResponse : DZWebServerResponse

/**
 *  @brief The MIME content type of the streamed response body.
 *
 *  Redeclared from the superclass as non-null because a streamed response
 *  always carries a body and therefore must have a content type.
 */
@property(nonatomic, copy) NSString* contentType;

/** Default initializer is unavailable. Use one of the @c initWithContentType: variants instead. */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  @brief Creates an autoreleased streamed response using a synchronous stream block.
 *
 *  @param type  The MIME content type of the response body (e.g. @c @"application/json" ).
 *  @param block A @c DZWebServerStreamBlock called repeatedly to obtain successive
 *               chunks of body data. The block must eventually return an empty
 *               @c NSData to signal completion.
 *
 *  @return A new @c DZWebServerStreamedResponse instance.
 *
 *  @see -initWithContentType:streamBlock:
 */
+ (instancetype)responseWithContentType:(NSString*)type streamBlock:(DZWebServerStreamBlock)block;

/**
 *  @brief Creates an autoreleased streamed response using an asynchronous stream block.
 *
 *  @param type  The MIME content type of the response body (e.g. @c @"text/event-stream" ).
 *  @param block A @c DZWebServerAsyncStreamBlock called repeatedly to obtain successive
 *               chunks of body data. The block may deliver data asynchronously via
 *               its completion callback.
 *
 *  @return A new @c DZWebServerStreamedResponse instance.
 *
 *  @see -initWithContentType:asyncStreamBlock:
 */
+ (instancetype)responseWithContentType:(NSString*)type asyncStreamBlock:(DZWebServerAsyncStreamBlock)block;

/**
 *  @brief Initializes a streamed response using a synchronous stream block.
 *
 *  The provided synchronous block is internally wrapped into a
 *  @c DZWebServerAsyncStreamBlock and forwarded to the designated initializer
 *  @c -initWithContentType:asyncStreamBlock: .
 *
 *  @param type  The MIME content type of the response body.
 *  @param block A @c DZWebServerStreamBlock called repeatedly to obtain successive
 *               chunks of body data. The block must eventually return an empty
 *               @c NSData to signal completion, or @c nil with an @c NSError on failure.
 *
 *  @return An initialized @c DZWebServerStreamedResponse, or @c nil if
 *          superclass initialization failed.
 *
 *  @see -initWithContentType:asyncStreamBlock:
 */
- (instancetype)initWithContentType:(NSString*)type streamBlock:(DZWebServerStreamBlock)block;

/**
 *  @brief Initializes a streamed response using an asynchronous stream block.
 *
 *  This is the designated initializer for @c DZWebServerStreamedResponse.
 *  The block is stored and called repeatedly by the server connection (via
 *  @c -asyncReadDataWithCompletion: ) to obtain chunks of body data.
 *
 *  Because the total content length is not known in advance, the inherited
 *  @c contentLength property remains at its default value of @c NSUIntegerMax,
 *  causing the server connection to use chunked transfer encoding.
 *
 *  @param type  The MIME content type of the response body.
 *  @param block A @c DZWebServerAsyncStreamBlock called repeatedly to obtain
 *               successive chunks of body data. The block may deliver data
 *               asynchronously via its completion callback.
 *
 *  @return An initialized @c DZWebServerStreamedResponse, or @c nil if
 *          superclass initialization failed.
 *
 *  @see DZWebServerAsyncStreamBlock
 */
- (instancetype)initWithContentType:(NSString*)type asyncStreamBlock:(DZWebServerAsyncStreamBlock)block NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
