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

#import "DZWebServerRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief A request subclass that stores the entire HTTP body in memory.
 *
 *  @discussion DZWebServerDataRequest accumulates all received body data into an
 *  in-memory @c NSData buffer. When the @c Content-Length header is present, the
 *  internal buffer is pre-allocated with that capacity for efficiency. When
 *  @c Content-Length is absent (e.g. chunked transfer encoding), the buffer grows
 *  dynamically as data arrives.
 *
 *  Use this class for requests with reasonably sized bodies. For large uploads
 *  where memory pressure is a concern, consider using @c DZWebServerFileRequest
 *  instead, which streams the body to a temporary file on disk.
 *
 *  The @c Extensions category provides convenience accessors for interpreting
 *  the raw body data as text or JSON.
 *
 *  @see DZWebServerRequest
 *  @see DZWebServerFileRequest
 */
@interface DZWebServerDataRequest : DZWebServerRequest

/**
 *  @brief The raw body data of the HTTP request.
 *
 *  @discussion Returns the complete body payload as an @c NSData object. The data
 *  is available after the connection has finished receiving the request body
 *  (i.e. after the @c DZWebServerBodyWriter protocol methods have completed).
 *
 *  If the request has no body, this returns an empty @c NSData instance.
 */
@property(nonatomic, copy, readonly) NSData* data;

@end

/**
 *  @brief Convenience accessors for interpreting the body data of a
 *  @c DZWebServerDataRequest as text or JSON.
 *
 *  @discussion These properties lazily decode the raw body data on first access
 *  and cache the result for subsequent reads. Each property validates the
 *  request's @c Content-Type before attempting decoding and returns @c nil if
 *  the content type does not match or if a decoding error occurs.
 */
@interface DZWebServerDataRequest (Extensions)

/**
 *  @brief The body data interpreted as a text string, or @c nil if unavailable.
 *
 *  @discussion Decodes the raw body data into an @c NSString using the character
 *  encoding specified in the @c charset parameter of the @c Content-Type header.
 *  If no charset is specified, UTF-8 is assumed.
 *
 *  This property requires the @c Content-Type to have a @c text/ prefix
 *  (e.g. @c text/plain, @c text/html). If the content type is not a text type,
 *  or if the data cannot be decoded with the determined encoding, @c nil is
 *  returned.
 *
 *  The result is lazily computed on first access and cached for subsequent reads.
 *
 *  @note The encoding is extracted from the @c Content-Type header's @c charset
 *  parameter (e.g. @c "text/plain; charset=iso-8859-1").
 */
@property(nonatomic, copy, readonly, nullable) NSString* text;

/**
 *  @brief The body data parsed as a JSON object, or @c nil if unavailable.
 *
 *  @discussion Deserializes the raw body data into a Foundation object
 *  (typically an @c NSDictionary or @c NSArray) using @c NSJSONSerialization.
 *
 *  This property requires the @c Content-Type to be one of the following MIME types:
 *  - @c application/json
 *  - @c text/json
 *  - @c text/javascript
 *
 *  If the content type does not match any of the above, or if the data is not
 *  valid JSON, @c nil is returned.
 *
 *  The result is lazily computed on first access and cached for subsequent reads.
 *
 *  @return An @c NSDictionary, @c NSArray, or other JSON-compatible Foundation
 *  object, or @c nil on failure.
 */
@property(nonatomic, readonly, nullable) id jsonObject;

@end

NS_ASSUME_NONNULL_END
