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
 *  @brief A response subclass that serves an in-memory HTTP response body.
 *
 *  DZWebServerDataResponse reads the entire body of the HTTP response from an
 *  @c NSData object held in memory. Use this class when the response payload is
 *  small enough to fit comfortably in memory (e.g., JSON payloads, short HTML
 *  pages, or small binary blobs).
 *
 *  The Extensions category provides additional convenience initializers for
 *  common content types such as plain text, HTML, HTML templates, and JSON.
 *
 *  @see DZWebServerResponse
 *  @see DZWebServerFileResponse
 *  @see DZWebServerStreamedResponse
 */
@interface DZWebServerDataResponse : DZWebServerResponse

/**
 *  @brief The MIME content type of the response body.
 *
 *  Redeclared from the superclass as non-null because a data response always
 *  carries a body and therefore must always have a content type.
 */
@property(nonatomic, copy) NSString* contentType;

- (instancetype)init NS_UNAVAILABLE;

/**
 *  @brief Creates a response with the given in-memory data and content type.
 *
 *  @param data The response body data. Must not be @c nil.
 *  @param type The MIME content type for the response (e.g., @c "application/octet-stream" ).
 *
 *  @return A new autoreleased data response instance.
 *
 *  @see -initWithData:contentType:
 */
+ (instancetype)responseWithData:(NSData*)data contentType:(NSString*)type;

/**
 *  @brief Initializes a response with the given in-memory data and content type.
 *
 *  This is the designated initializer for the class. The response's
 *  @c contentLength is automatically set to the length of @a data.
 *
 *  @param data The response body data. Must not be @c nil.
 *  @param type The MIME content type for the response (e.g., @c "application/octet-stream" ).
 *
 *  @return An initialized data response instance.
 */
- (instancetype)initWithData:(NSData*)data contentType:(NSString*)type NS_DESIGNATED_INITIALIZER;

@end

/**
 *  @brief Convenience factory methods and initializers for common content types.
 *
 *  This category extends DZWebServerDataResponse with helpers for creating
 *  responses from plain text, HTML strings, HTML template files, and JSON
 *  objects. All text-based methods use UTF-8 encoding.
 */
@interface DZWebServerDataResponse (Extensions)

/**
 *  @brief Creates a data response from a plain-text string encoded as UTF-8.
 *
 *  The content type is set to @c "text/plain; charset=utf-8".
 *
 *  @param text The plain-text string to use as the response body.
 *
 *  @return A new data response, or @c nil if the string cannot be encoded as UTF-8.
 *
 *  @see -initWithText:
 */
+ (nullable instancetype)responseWithText:(NSString*)text;

/**
 *  @brief Creates a data response from an HTML string encoded as UTF-8.
 *
 *  The content type is set to @c "text/html; charset=utf-8".
 *
 *  @param html The HTML string to use as the response body.
 *
 *  @return A new data response, or @c nil if the string cannot be encoded as UTF-8.
 *
 *  @see -initWithHTML:
 */
+ (nullable instancetype)responseWithHTML:(NSString*)html;

/**
 *  @brief Creates a data response from an HTML template file with variable substitution.
 *
 *  @param path      The absolute file path to an HTML template file (UTF-8 encoded).
 *  @param variables A dictionary mapping placeholder names to replacement values.
 *                   All occurrences of @c \%variable\% in the template are replaced
 *                   with the corresponding dictionary value.
 *
 *  @return A new data response, or @c nil if the template cannot be read or encoded.
 *
 *  @see -initWithHTMLTemplate:variables:
 */
+ (nullable instancetype)responseWithHTMLTemplate:(NSString*)path variables:(NSDictionary<NSString*, NSString*>*)variables;

/**
 *  @brief Creates a data response from a JSON-serializable object.
 *
 *  The content type is set to the default @c "application/json".
 *
 *  @param object A JSON-serializable object (e.g., @c NSDictionary, @c NSArray).
 *               Must be valid for @c NSJSONSerialization.
 *
 *  @return A new data response, or @c nil if the object cannot be serialized to JSON.
 *
 *  @see -initWithJSONObject:
 */
+ (nullable instancetype)responseWithJSONObject:(id)object;

/**
 *  @brief Creates a data response from a JSON-serializable object with a custom content type.
 *
 *  @param object A JSON-serializable object (e.g., @c NSDictionary, @c NSArray).
 *               Must be valid for @c NSJSONSerialization.
 *  @param type   The MIME content type to use instead of the default @c "application/json"
 *               (e.g., @c "application/vnd.api+json" ).
 *
 *  @return A new data response, or @c nil if the object cannot be serialized to JSON.
 *
 *  @see -initWithJSONObject:contentType:
 */
+ (nullable instancetype)responseWithJSONObject:(id)object contentType:(NSString*)type;

/**
 *  @brief Initializes a data response from a plain-text string encoded as UTF-8.
 *
 *  The content type is set to @c "text/plain; charset=utf-8".
 *
 *  @param text The plain-text string to use as the response body.
 *
 *  @return An initialized data response, or @c nil if the string cannot be encoded as UTF-8.
 */
- (nullable instancetype)initWithText:(NSString*)text;

/**
 *  @brief Initializes a data response from an HTML string encoded as UTF-8.
 *
 *  The content type is set to @c "text/html; charset=utf-8".
 *
 *  @param html The HTML string to use as the response body.
 *
 *  @return An initialized data response, or @c nil if the string cannot be encoded as UTF-8.
 */
- (nullable instancetype)initWithHTML:(NSString*)html;

/**
 *  @brief Initializes a data response from an HTML template file with variable substitution.
 *
 *  The template file is read from disk using UTF-8 encoding. All occurrences of
 *  @c \%variable\% in the template content are replaced with the corresponding
 *  value from the @a variables dictionary. For example, a template containing
 *  @c \%title\% with a dictionary of @c \@{"title":@"Hello"} would produce
 *  HTML with @c "Hello" substituted in place of each @c \%title\% token.
 *
 *  The content type is set to @c "text/html; charset=utf-8".
 *
 *  @param path      The absolute file path to an HTML template file (UTF-8 encoded).
 *  @param variables A dictionary mapping placeholder names to replacement values.
 *
 *  @return An initialized data response, or @c nil if the template cannot be read or encoded.
 */
- (nullable instancetype)initWithHTMLTemplate:(NSString*)path variables:(NSDictionary<NSString*, NSString*>*)variables;

/**
 *  @brief Initializes a data response from a JSON-serializable object.
 *
 *  The object is serialized using @c NSJSONSerialization and the content type
 *  is set to the default @c "application/json".
 *
 *  @param object A JSON-serializable object (e.g., @c NSDictionary, @c NSArray).
 *               Must be valid for @c NSJSONSerialization.
 *
 *  @return An initialized data response, or @c nil if the object cannot be serialized to JSON.
 *
 *  @see -initWithJSONObject:contentType:
 */
- (nullable instancetype)initWithJSONObject:(id)object;

/**
 *  @brief Initializes a data response from a JSON-serializable object with a custom content type.
 *
 *  The object is serialized using @c NSJSONSerialization. Use this method when
 *  you need a non-standard JSON content type such as @c "application/vnd.api+json".
 *
 *  @param object A JSON-serializable object (e.g., @c NSDictionary, @c NSArray).
 *               Must be valid for @c NSJSONSerialization.
 *  @param type   The MIME content type for the response.
 *
 *  @return An initialized data response, or @c nil if the object cannot be serialized to JSON.
 */
- (nullable instancetype)initWithJSONObject:(id)object contentType:(NSString*)type;

@end

NS_ASSUME_NONNULL_END
