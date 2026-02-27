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

#import "DZWebServerDataRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A request subclass that automatically parses URL-encoded form bodies.
 *
 * @discussion @c DZWebServerURLEncodedFormRequest extends @c DZWebServerDataRequest to
 * handle HTTP requests whose body is encoded as @c application/x-www-form-urlencoded
 * (the default encoding for HTML form submissions).
 *
 * When the connection finishes receiving the request body, this class decodes the raw
 * data into a dictionary of unescaped control names and values using
 * @c DZWebServerParseURLEncodedForm(). The text encoding is determined from the
 * @c charset parameter of the @c Content-Type header, falling back to UTF-8 if absent.
 *
 * The parsed key-value pairs are accessible through the @c arguments property.
 *
 * @note This class is intended for bodies encoded as
 *       @c application/x-www-form-urlencoded. For multipart form data, use
 *       @c DZWebServerMultiPartFormRequest instead.
 *
 * @see DZWebServerDataRequest
 * @see DZWebServerMultiPartFormRequest
 * @see DZWebServerParseURLEncodedForm
 */
@interface DZWebServerURLEncodedFormRequest : DZWebServerDataRequest

/**
 * @brief Returns the parsed form fields as a dictionary of unescaped control names and values.
 *
 * @discussion The dictionary keys are the form control names and the values are their
 * corresponding submitted values, both fully percent-decoded.
 *
 * The text encoding used to interpret the raw body data is extracted from the
 * @c charset parameter of the @c Content-Type header. If no charset is specified,
 * UTF-8 is used as the default.
 *
 * This property is populated after the request body has been fully received and
 * processed (i.e., after @c -close: completes successfully). Accessing it before
 * that point returns @c nil.
 *
 * @note Duplicate form control names are not supported; if the encoded form contains
 *       multiple values for the same name, only one will be retained.
 *
 * @see DZWebServerParseURLEncodedForm
 */
@property(nonatomic, copy, readonly) NSDictionary<NSString*, NSString*>* arguments;

/**
 * @brief Returns the MIME type for URL-encoded form submissions.
 *
 * @discussion Always returns @c "application/x-www-form-urlencoded". This value can
 * be used when registering a handler with @c DZWebServer to match incoming requests
 * whose body is a URL-encoded form.
 *
 * @return The string @c "application/x-www-form-urlencoded".
 */
+ (NSString*)mimeType;

@end

NS_ASSUME_NONNULL_END
