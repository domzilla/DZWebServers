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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief Completion block used for asynchronous body data reads.
 *
 *  This block is passed by DZWebServerConnection to a DZWebServerBodyReader
 *  when reading response body data asynchronously via
 *  @c -asyncReadDataWithCompletion:.
 *
 *  @param data A non-empty @c NSData if body data is available, an empty
 *              @c NSData (length 0) if the body has been fully read, or
 *              @c nil if an error occurred.
 *  @param error An @c NSError describing the failure when @c data is @c nil.
 *               This parameter is @c nil on success.
 */
typedef void (^DZWebServerBodyReaderCompletionBlock)(NSData* _Nullable data, NSError* _Nullable error);

/**
 *  @brief Protocol for reading HTTP response body data.
 *
 *  DZWebServerConnection uses this protocol to communicate with
 *  DZWebServerResponse and stream the HTTP body data to the client. The
 *  lifecycle follows a strict open-read-close sequence:
 *
 *  1. @c -open: is called once before any data is read.
 *  2. @c -readData: (or @c -asyncReadDataWithCompletion:) is called repeatedly
 *     until an empty @c NSData is returned, signaling end-of-body.
 *  3. @c -close is called once after all data has been sent.
 *
 *  Multiple DZWebServerBodyReader objects can be chained together internally
 *  (e.g., to apply gzip encoding to the content before transmission).
 *
 *  @warning These methods can be called on any GCD thread.
 */
@protocol DZWebServerBodyReader <NSObject>

@required

/**
 *  @brief Opens the body reader in preparation for reading data.
 *
 *  Called exactly once before any calls to @c -readData: or
 *  @c -asyncReadDataWithCompletion:. Use this method to acquire resources
 *  such as file handles or stream buffers needed for reading.
 *
 *  @param error On failure, set to an @c NSError describing what went wrong.
 *               The pointer is guaranteed to be non-NULL.
 *  @return @c YES on success, @c NO on failure (with @c error populated).
 */
- (BOOL)open:(NSError**)error;

/**
 *  @brief Synchronously reads the next chunk of body data.
 *
 *  Called repeatedly after @c -open: succeeds until the body is fully consumed.
 *
 *  @param error On failure, set to an @c NSError describing what went wrong.
 *               The pointer is guaranteed to be non-NULL.
 *  @return A non-empty @c NSData if body data is available, an empty @c NSData
 *          (length 0) if there is no more body data, or @c nil on error (with
 *          @c error populated).
 */
- (nullable NSData*)readData:(NSError**)error;

/**
 *  @brief Closes the body reader and releases any resources.
 *
 *  Called exactly once after all body data has been sent (or when the
 *  connection terminates). Use this method to release file handles, buffers,
 *  or other resources acquired in @c -open:.
 */
- (void)close;

@optional

/**
 *  @brief Asynchronously reads the next chunk of body data.
 *
 *  When implemented, this method is preferred over the synchronous
 *  @c -readData: method. The implementation must invoke @c block exactly once
 *  when data becomes available.
 *
 *  @param block A completion block that must be called with the result.
 *               Pass a non-empty @c NSData if body data is available, an empty
 *               @c NSData (length 0) if there is no more body data, or @c nil
 *               with an @c NSError on failure.
 *
 *  @note This method is optional. If not implemented, DZWebServerConnection
 *        falls back to the synchronous @c -readData: method.
 *
 *  @see DZWebServerBodyReaderCompletionBlock
 */
- (void)asyncReadDataWithCompletion:(DZWebServerBodyReaderCompletionBlock)block NS_SWIFT_DISABLE_ASYNC;

@end

/**
 *  @brief Base class representing a single HTTP response.
 *
 *  DZWebServerResponse wraps the metadata and body of an HTTP response. It is
 *  instantiated inside a DZWebServer request handler and returned to the
 *  DZWebServerConnection, which sends the response headers and streams the body
 *  using the DZWebServerBodyReader protocol.
 *
 *  @discussion The default DZWebServerBodyReader implementation on this class
 *  returns an empty body (zero-length @c NSData from @c -readData:). Subclasses
 *  such as @c DZWebServerDataResponse, @c DZWebServerFileResponse, and
 *  @c DZWebServerStreamedResponse override the reader methods to supply actual
 *  body content.
 *
 *  When @c gzipContentEncodingEnabled is set to @c YES, a gzip encoder is
 *  automatically chained in front of the body reader. This removes the
 *  @c Content-Length header and adds a @c Content-Encoding: gzip header.
 *
 *  @warning DZWebServerResponse instances can be created and used on any GCD
 *           thread.
 *
 *  @see DZWebServerDataResponse
 *  @see DZWebServerFileResponse
 *  @see DZWebServerStreamedResponse
 */
@interface DZWebServerResponse : NSObject <DZWebServerBodyReader>

/**
 *  @brief The MIME content type of the response body.
 *
 *  Sent as the @c Content-Type HTTP header. When @c nil, the response is
 *  treated as having no body, and the DZWebServerBodyReader methods will not
 *  be invoked.
 *
 *  Defaults to @c nil (no body).
 *
 *  @warning This property must be set to a non-nil value when a response body
 *           is present. The @c -hasBody method checks this property to determine
 *           whether a body exists.
 */
@property(nonatomic, copy, nullable) NSString* contentType;

/**
 *  @brief The byte length of the response body.
 *
 *  Sent as the @c Content-Length HTTP header. When set to a concrete value,
 *  DZWebServerConnection uses a fixed-length transfer. When set to
 *  @c NSUIntegerMax, the body length is considered unknown and chunked
 *  transfer encoding is automatically enabled to comply with HTTP/1.1
 *  specifications.
 *
 *  Defaults to @c NSUIntegerMax (unknown / no body).
 *
 *  @note Enabling @c gzipContentEncodingEnabled resets this property to
 *        @c NSUIntegerMax because the compressed size is not known in advance.
 *
 *  @see gzipContentEncodingEnabled
 */
@property(nonatomic) NSUInteger contentLength;

/**
 *  @brief The HTTP status code for the response.
 *
 *  Sent as the status code in the HTTP response status line. Use the
 *  constants defined in @c DZWebServerHTTPStatusCodes.h (e.g.,
 *  @c kDZWebServerHTTPStatusCode_OK, @c kDZWebServerHTTPStatusCode_NotFound).
 *
 *  Defaults to @c 200 (@c kDZWebServerHTTPStatusCode_OK).
 *
 *  @see DZWebServerHTTPStatusCodes.h
 */
@property(nonatomic) NSInteger statusCode;

/**
 *  @brief The maximum age for client-side caching, in seconds.
 *
 *  Sets the @c Cache-Control HTTP header. A value of @c 0 produces
 *  @c Cache-Control: no-cache, instructing clients and proxies not to cache
 *  the response. Any positive value produces @c Cache-Control: max-age=N.
 *
 *  Defaults to @c 0 (no-cache).
 */
@property(nonatomic) NSUInteger cacheControlMaxAge;

/**
 *  @brief The last-modified date of the resource.
 *
 *  When non-nil, sent as the @c Last-Modified HTTP header. Clients may use
 *  this value in subsequent conditional requests via the
 *  @c If-Modified-Since header, enabling 304 Not Modified responses.
 *
 *  Defaults to @c nil (header not sent).
 */
@property(nonatomic, nullable) NSDate* lastModifiedDate;

/**
 *  @brief The entity tag (ETag) for the resource.
 *
 *  When non-nil, sent as the @c ETag HTTP header. Clients may use this value
 *  in subsequent conditional requests via the @c If-None-Match header,
 *  enabling 304 Not Modified responses.
 *
 *  Defaults to @c nil (header not sent).
 */
@property(nonatomic, copy, nullable) NSString* eTag;

/**
 *  @brief Whether the response body is compressed with gzip encoding.
 *
 *  When set to @c YES, a gzip encoder is inserted into the body reader chain
 *  during response preparation. The encoder adds a
 *  @c Content-Encoding: gzip header and resets @c contentLength to
 *  @c NSUIntegerMax (since the compressed size is unknown ahead of time),
 *  which forces chunked transfer encoding.
 *
 *  Defaults to @c NO.
 *
 *  @warning Enabling gzip encoding removes any previously set
 *           @c Content-Length header. The client determines the body length
 *           by reading until the connection closes, per HTTP/1.1 specification.
 *
 *  @see contentLength
 */
@property(nonatomic, getter=isGZipContentEncodingEnabled) BOOL gzipContentEncodingEnabled;

/**
 *  @brief Creates an empty response with no body.
 *
 *  Convenience factory method that allocates and initializes a new response
 *  with default values: status code 200, no content type, and no body.
 *
 *  @return A new autoreleased response instance.
 */
+ (instancetype)response;

/**
 *  @brief Initializes an empty response with default values.
 *
 *  This is the designated initializer. After initialization, the response has:
 *  - @c contentType = @c nil (no body)
 *  - @c contentLength = @c NSUIntegerMax (unknown)
 *  - @c statusCode = @c 200 (OK)
 *  - @c cacheControlMaxAge = @c 0 (no-cache)
 *  - @c lastModifiedDate = @c nil
 *  - @c eTag = @c nil
 *  - @c gzipContentEncodingEnabled = @c NO
 *
 *  @return A newly initialized response instance.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 *  @brief Sets or removes a custom HTTP header on the response.
 *
 *  Use this method to attach additional headers beyond those managed
 *  automatically by DZWebServerResponse (e.g., @c Content-Type,
 *  @c Content-Length, @c Cache-Control, @c Last-Modified, @c ETag,
 *  @c Content-Encoding).
 *
 *  @param value The header value to set, or @c nil to remove an existing header.
 *  @param header The HTTP header field name (e.g., @c @"X-Custom-Header").
 *
 *  @warning Do not attempt to override the primary headers managed by
 *           DZWebServerResponse and DZWebServerConnection (such as
 *           @c Content-Type, @c Content-Length, @c ETag, @c Last-Modified,
 *           @c Cache-Control, or @c Content-Encoding). Doing so may produce
 *           malformed HTTP responses.
 */
- (void)setValue:(nullable NSString*)value forAdditionalHeader:(NSString*)header;

/**
 *  @brief Returns whether this response has a body.
 *
 *  This is a convenience method that checks whether @c contentType is non-nil.
 *  A response is considered to have a body if and only if a content type has
 *  been set.
 *
 *  @return @c YES if @c contentType is non-nil, @c NO otherwise.
 */
- (BOOL)hasBody;

@end

/**
 *  @brief Convenience initializers for common response patterns.
 *
 *  This category provides factory methods and initializers for creating
 *  responses with custom HTTP status codes and HTTP redirects.
 */
@interface DZWebServerResponse (Extensions)

/**
 *  @brief Creates an empty response with the specified HTTP status code.
 *
 *  The returned response has no body (@c contentType is @c nil).
 *
 *  @param statusCode The HTTP status code for the response. Use constants from
 *                    @c DZWebServerHTTPStatusCodes.h.
 *  @return A new autoreleased response instance with the given status code.
 *
 *  @see DZWebServerHTTPStatusCodes.h
 */
+ (instancetype)responseWithStatusCode:(NSInteger)statusCode;

/**
 *  @brief Creates an HTTP redirect response to the specified URL.
 *
 *  Sets the @c Location header to the absolute string of @c location and
 *  configures the status code based on the @c permanent flag.
 *
 *  @param location  The target URL for the redirect. Its absolute string
 *                   representation is used as the @c Location header value.
 *  @param permanent If @c YES, uses status code 301 (Moved Permanently).
 *                   If @c NO, uses status code 307 (Temporary Redirect).
 *  @return A new autoreleased redirect response instance.
 */
+ (instancetype)responseWithRedirect:(NSURL*)location permanent:(BOOL)permanent;

/**
 *  @brief Initializes an empty response with the specified HTTP status code.
 *
 *  The response has no body (@c contentType is @c nil). All other properties
 *  retain their default values from the designated initializer.
 *
 *  @param statusCode The HTTP status code for the response. Use constants from
 *                    @c DZWebServerHTTPStatusCodes.h.
 *  @return A newly initialized response instance with the given status code.
 *
 *  @see DZWebServerHTTPStatusCodes.h
 */
- (instancetype)initWithStatusCode:(NSInteger)statusCode;

/**
 *  @brief Initializes an HTTP redirect response to the specified URL.
 *
 *  Sets the @c Location header to the absolute string of @c location and
 *  configures the status code based on the @c permanent flag.
 *
 *  @param location  The target URL for the redirect. Its absolute string
 *                   representation is used as the @c Location header value.
 *  @param permanent If @c YES, uses status code 301 (Moved Permanently).
 *                   If @c NO, uses status code 307 (Temporary Redirect).
 *  @return A newly initialized redirect response instance.
 */
- (instancetype)initWithRedirect:(NSURL*)location permanent:(BOOL)permanent;

@end

NS_ASSUME_NONNULL_END
