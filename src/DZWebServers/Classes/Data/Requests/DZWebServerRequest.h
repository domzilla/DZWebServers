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
 *  @brief Attribute key for retrieving regex capture groups from a request.
 *
 *  Use this key with @c -attributeForKey: to retrieve an @c NSArray of @c NSString
 *  objects containing the capture groups matched by the regular expression that was
 *  used to route the request.
 *
 *  The value stored under this key is @c NSArray<NSString *> where index 0 is the
 *  first capture group, index 1 the second, and so on.
 *
 *  @warning This attribute is only present on requests matched by handlers registered
 *  via @c -addHandlerForMethod:pathRegex:requestClass:processBlock:. For handlers
 *  registered with a literal path, this attribute will not be set.
 *
 *  @see -[DZWebServerRequest attributeForKey:]
 *  @see -[DZWebServer addHandlerForMethod:pathRegex:requestClass:processBlock:]
 */
extern NSString* const DZWebServerRequestAttribute_RegexCaptures;

/**
 *  @brief Protocol for receiving HTTP request body data from a connection.
 *
 *  @c DZWebServerBodyWriter is used by @c DZWebServerConnection to stream
 *  the received HTTP body data into a @c DZWebServerRequest (or one of its
 *  subclasses). The protocol follows a strict open-write-close lifecycle:
 *
 *  1. @c -open: is called once before any body data arrives.
 *  2. @c -writeData:error: is called zero or more times as data chunks arrive.
 *  3. @c -close: is called once after all body data has been received.
 *
 *  @discussion Multiple @c DZWebServerBodyWriter objects can be chained together
 *  internally to form a processing pipeline. For example, when the request
 *  includes @c Content-Encoding: @c gzip, an internal gzip decoder is inserted
 *  in the chain to transparently decompress the body before passing it to the
 *  request object.
 *
 *  @warning These methods can be called on any GCD thread. Implementations must
 *  be safe for use outside the main thread.
 */
@protocol DZWebServerBodyWriter <NSObject>

/**
 *  @brief Called once before any body data is received.
 *
 *  Implementations should perform any setup required for receiving body data
 *  (e.g., opening a file handle, allocating buffers).
 *
 *  @param error On failure, set to an @c NSError describing what went wrong.
 *               The pointer is guaranteed to be non-NULL.
 *  @return @c YES on success, @c NO on failure.
 */
- (BOOL)open:(NSError**)error;

/**
 *  @brief Called each time a chunk of body data has been received.
 *
 *  This method may be called multiple times as the body arrives incrementally.
 *  Implementations should process or store the data accordingly.
 *
 *  @param data  The received body data chunk. Never @c nil or empty.
 *  @param error On failure, set to an @c NSError describing what went wrong.
 *               The pointer is guaranteed to be non-NULL.
 *  @return @c YES on success, @c NO on failure.
 */
- (BOOL)writeData:(NSData*)data error:(NSError**)error;

/**
 *  @brief Called once after all body data has been received.
 *
 *  Implementations should finalize processing (e.g., close file handles,
 *  flush buffers, validate the received data).
 *
 *  @param error On failure, set to an @c NSError describing what went wrong.
 *               The pointer is guaranteed to be non-NULL.
 *  @return @c YES on success, @c NO on failure.
 */
- (BOOL)close:(NSError**)error;

@end

/**
 *  @brief Base class representing a single parsed HTTP request.
 *
 *  @c DZWebServerRequest is instantiated by @c DZWebServerConnection after the
 *  HTTP headers have been fully received and parsed. Each instance encapsulates
 *  the method, URL, headers, query parameters, and metadata for one HTTP request.
 *
 *  @discussion If the request carries a body (i.e., @c hasBody returns @c YES),
 *  the @c DZWebServerBodyWriter protocol methods are called by the connection to
 *  stream the body data into this object. The base class implementation of the
 *  @c DZWebServerBodyWriter methods is a no-op that silently discards all body
 *  data. Subclasses such as @c DZWebServerDataRequest, @c DZWebServerFileRequest,
 *  and @c DZWebServerMultiPartFormRequest override these methods to store the body
 *  in memory, on disk, or to parse multipart form data, respectively.
 *
 *  When the request includes @c Content-Encoding: @c gzip, the framework
 *  automatically inserts an internal gzip decoder in the body-writer chain so that
 *  subclasses receive decompressed data transparently.
 *
 *  @warning @c DZWebServerRequest instances can be created and used on any GCD
 *  thread. Do not assume main-thread access.
 *
 *  @see DZWebServerDataRequest
 *  @see DZWebServerFileRequest
 *  @see DZWebServerMultiPartFormRequest
 *  @see DZWebServerURLEncodedFormRequest
 */
@interface DZWebServerRequest : NSObject <DZWebServerBodyWriter>

/**
 *  @brief The HTTP method of the request (e.g., @c GET, @c POST, @c PUT, @c DELETE).
 *
 *  This value is set at initialization time and does not change.
 */
@property(nonatomic, copy, readonly) NSString* method;

/**
 *  @brief The full URL of the request, including scheme, host, path, and query string.
 *
 *  This value is set at initialization time and does not change.
 *
 *  @see path
 *  @see query
 */
@property(nonatomic, copy, readonly) NSURL* URL;

/**
 *  @brief The HTTP headers for the request as key-value pairs.
 *
 *  Header names are used as dictionary keys in their original form (e.g.,
 *  @c Content-Type, @c Accept-Encoding). Values are the raw header strings.
 *
 *  This dictionary is set at initialization time and does not change.
 */
@property(nonatomic, copy, readonly) NSDictionary<NSString*, NSString*>* headers;

/**
 *  @brief The path component of the request URL.
 *
 *  This is the URL path without the query string or fragment (e.g., @c /api/files ).
 *  It is set at initialization time and does not change.
 *
 *  @see URL
 */
@property(nonatomic, copy, readonly) NSString* path;

/**
 *  @brief The parsed and percent-decoded query parameters from the request URL.
 *
 *  The dictionary maps parameter names to their values. For example, the URL
 *  @c /search?q=hello&page=2 produces @c @{@"q":@"hello", @"page":@"2"} .
 *
 *  @note This property is @c nil if the URL contains no query string.
 *
 *  @see URL
 */
@property(nonatomic, copy, readonly, nullable) NSDictionary<NSString*, NSString*>* query;

/**
 *  @brief The MIME type of the request body, parsed from the @c Content-Type header.
 *
 *  @discussion Possible states:
 *  - @c nil -- The request has no body (neither @c Content-Length nor
 *    @c Transfer-Encoding: @c chunked is present). A @c Content-Type header
 *    without a corresponding body indicator is ignored and this property
 *    remains @c nil.
 *  - @c "application/octet-stream" -- A body is present (via @c Content-Length
 *    or chunked encoding) but no @c Content-Type header was provided.
 *  - Otherwise, the normalized value of the @c Content-Type header.
 *
 *  Use @c -hasBody to test whether the request carries a body.
 *
 *  @see hasBody
 *  @see contentLength
 */
@property(nonatomic, copy, readonly, nullable) NSString* contentType;

/**
 *  @brief The content length of the request body in bytes, parsed from the
 *  @c Content-Length header.
 *
 *  @discussion Possible states:
 *  - A concrete value (>= 0) -- The @c Content-Length header was present and valid.
 *  - @c NSUIntegerMax -- Either the request has no body, or a body is present but
 *    uses chunked transfer encoding (no @c Content-Length header).
 *
 *  @note A negative @c Content-Length value or a @c Content-Length header combined
 *  with chunked transfer encoding is treated as invalid and causes initialization
 *  to fail (returning @c nil).
 *
 *  @see contentType
 *  @see hasBody
 */
@property(nonatomic, readonly) NSUInteger contentLength;

/**
 *  @brief The parsed value of the @c If-Modified-Since header as an @c NSDate.
 *
 *  Used for conditional GET requests. The date is parsed from RFC 822 format.
 *  Returns @c nil if the header is absent or could not be parsed.
 *
 *  @see ifNoneMatch
 */
@property(nonatomic, readonly, nullable) NSDate* ifModifiedSince;

/**
 *  @brief The raw value of the @c If-None-Match header (typically an ETag string).
 *
 *  Used for conditional GET requests based on entity tags. Returns @c nil if the
 *  header is absent.
 *
 *  @see ifModifiedSince
 */
@property(nonatomic, copy, readonly, nullable) NSString* ifNoneMatch;

/**
 *  @brief The parsed byte range from the @c Range header.
 *
 *  @discussion The @c Range header is parsed according to RFC 7233 @c bytes= syntax.
 *  Only single-range requests are supported; multi-range requests are ignored.
 *
 *  The value encodes three distinct cases:
 *  - <b>From beginning:</b> @c "bytes=500-999" produces @c {.location=500, .length=500}.
 *    Open-ended ranges like @c "bytes=9500-" produce @c {.location=9500, .length=NSUIntegerMax}.
 *  - <b>From end (suffix):</b> @c "bytes=-500" produces @c {.location=NSUIntegerMax, .length=500}.
 *  - <b>Absent or invalid:</b> @c {.location=NSUIntegerMax, .length=0}. This is the default.
 *
 *  Use @c -hasByteRange to check whether a valid range was parsed.
 *
 *  @see hasByteRange
 */
@property(nonatomic, readonly) NSRange byteRange;

/**
 *  @brief Whether the client advertises support for gzip content encoding.
 *
 *  Returns @c YES if the @c Accept-Encoding header contains the string @c "gzip".
 *  When this is @c YES, response handlers may choose to send gzip-compressed
 *  response bodies for bandwidth savings.
 *
 *  Defaults to @c NO if the @c Accept-Encoding header is absent.
 */
@property(nonatomic, readonly) BOOL acceptsGzipContentEncoding;

/**
 *  @brief The local (server-side) socket address as raw @c struct @c sockaddr data.
 *
 *  The @c NSData object wraps a @c struct @c sockaddr (either @c sockaddr_in for
 *  IPv4 or @c sockaddr_in6 for IPv6). You can cast @c localAddressData.bytes to
 *  the appropriate sockaddr type to extract the address and port.
 *
 *  @warning This property is set by the @c DZWebServerConnection after the request
 *  is initialized. It will be @c nil if accessed before the connection assigns it.
 *
 *  @see localAddressString
 */
@property(nonatomic, copy, readonly, nullable) NSData* localAddressData;

/**
 *  @brief The local (server-side) socket address as a human-readable string.
 *
 *  Computed from @c localAddressData. The format includes both the IP address
 *  and the port number (e.g., @c "192.168.1.10:8080" or @c "[::1]:8080").
 *
 *  @note This is a computed property. Each access converts @c localAddressData
 *  into a string representation.
 *
 *  @return @c nil if @c localAddressData has not been set yet.
 *
 *  @see localAddressData
 */
@property(nonatomic, copy, readonly, nullable) NSString* localAddressString;

/**
 *  @brief The remote (client-side) socket address as raw @c struct @c sockaddr data.
 *
 *  The @c NSData object wraps a @c struct @c sockaddr (either @c sockaddr_in for
 *  IPv4 or @c sockaddr_in6 for IPv6). You can cast @c remoteAddressData.bytes to
 *  the appropriate sockaddr type to extract the client address and port.
 *
 *  @warning This property is set by the @c DZWebServerConnection after the request
 *  is initialized. It will be @c nil if accessed before the connection assigns it.
 *
 *  @see remoteAddressString
 */
@property(nonatomic, copy, readonly, nullable) NSData* remoteAddressData;

/**
 *  @brief The remote (client-side) socket address as a human-readable string.
 *
 *  Computed from @c remoteAddressData. The format includes both the IP address
 *  and the port number (e.g., @c "10.0.0.5:54321" or @c "[fe80::1]:54321").
 *
 *  @note This is a computed property. Each access converts @c remoteAddressData
 *  into a string representation.
 *
 *  @return @c nil if @c remoteAddressData has not been set yet.
 *
 *  @see remoteAddressData
 */
@property(nonatomic, copy, readonly, nullable) NSString* remoteAddressString;

/**
 *  @brief Initializes a new request with the given HTTP method, URL, headers, path,
 *  and query parameters.
 *
 *  This is the designated initializer. During initialization, the following headers
 *  are parsed automatically:
 *  - @c Content-Type and @c Content-Length -- to determine @c contentType and
 *    @c contentLength. A @c Content-Length with chunked transfer encoding or a
 *    negative value causes initialization to fail (returns @c nil).
 *  - @c Transfer-Encoding -- to detect chunked transfer encoding.
 *  - @c If-Modified-Since -- parsed as an RFC 822 date into @c ifModifiedSince.
 *  - @c If-None-Match -- stored as-is into @c ifNoneMatch.
 *  - @c Range -- parsed into @c byteRange. Only single byte ranges in the
 *    @c bytes= format are supported.
 *  - @c Accept-Encoding -- checked for @c "gzip" to set @c acceptsGzipContentEncoding.
 *
 *  @param method  The HTTP method string (e.g., @c @"GET", @c @"POST").
 *  @param url     The full request URL.
 *  @param headers A dictionary of HTTP header name-value pairs.
 *  @param path    The path component of the URL.
 *  @param query   The parsed query parameters, or @c nil if no query string is present.
 *  @return An initialized request, or @c nil if the headers contain contradictory
 *          or invalid values (e.g., negative @c Content-Length with chunked encoding).
 */
- (instancetype)initWithMethod:(NSString*)method url:(NSURL*)url headers:(NSDictionary<NSString*, NSString*>*)headers path:(NSString*)path query:(nullable NSDictionary<NSString*, NSString*>*)query NS_DESIGNATED_INITIALIZER;

/** Unavailable. Use @c initWithMethod:url:headers:path:query: instead. */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  @brief Returns whether this request has an HTTP body.
 *
 *  This is a convenience method that checks whether @c contentType is non-nil.
 *  A request has a body when a @c Content-Length header or chunked transfer
 *  encoding is present.
 *
 *  @return @c YES if the request carries a body, @c NO otherwise.
 *
 *  @see contentType
 *  @see contentLength
 */
- (BOOL)hasBody;

/**
 *  @brief Returns whether the request includes a valid @c Range header.
 *
 *  This is a convenience method that checks whether @c byteRange represents a
 *  valid byte range (i.e., not the default @c {NSUIntegerMax, 0} sentinel).
 *
 *  @return @c YES if a syntactically valid single byte range was parsed from the
 *          @c Range header, @c NO otherwise.
 *
 *  @see byteRange
 */
- (BOOL)hasByteRange;

/**
 *  @brief Retrieves a custom attribute associated with this request.
 *
 *  Attributes are arbitrary key-value pairs attached to the request by the
 *  framework or by handler matching logic. For example, when a handler is
 *  registered with a path regex, the framework stores the capture groups under
 *  the @c DZWebServerRequestAttribute_RegexCaptures key.
 *
 *  @param key The attribute key to look up. Must not be @c nil.
 *  @return The attribute value associated with @a key, or @c nil if no attribute
 *          exists for that key.
 *
 *  @see DZWebServerRequestAttribute_RegexCaptures
 */
- (nullable id)attributeForKey:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
