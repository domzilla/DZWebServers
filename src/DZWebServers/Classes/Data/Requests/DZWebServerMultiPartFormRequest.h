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
 *  @brief Abstract base class representing a single part within a multipart form data body.
 *
 *  @discussion DZWebServerMultiPart is the abstract superclass for multipart form data parts.
 *  Each part corresponds to one field in an HTTP @c multipart/form-data submission and carries
 *  a control name, content type, and MIME type extracted from the part's headers.
 *
 *  This class is not intended to be instantiated directly. Use the concrete subclasses
 *  @c DZWebServerMultiPartArgument (for in-memory data parts) and @c DZWebServerMultiPartFile
 *  (for file parts stored on disk) instead.
 *
 *  @see DZWebServerMultiPartArgument
 *  @see DZWebServerMultiPartFile
 *  @see DZWebServerMultiPartFormRequest
 */
@interface DZWebServerMultiPart : NSObject

/**
 *  @brief The form control name for this part.
 *
 *  @discussion Extracted from the @c Content-Disposition header's @c name parameter.
 *  This corresponds to the HTML form field name (e.g., the @c name attribute of an
 *  @c \<input\> element).
 */
@property(nonatomic, copy, readonly) NSString* controlName;

/**
 *  @brief The full content type string for this part.
 *
 *  @discussion Extracted from the @c Content-Type header of the part. If no @c Content-Type
 *  header is present, this defaults to @c "text/plain" per the HTTP specification
 *  (RFC 2388). May include parameters such as @c charset (e.g., @c "text/plain; charset=utf-8" ).
 *
 *  @see mimeType
 */
@property(nonatomic, copy, readonly) NSString* contentType;

/**
 *  @brief The MIME type component of the content type, without parameters.
 *
 *  @discussion Derived from @c contentType by stripping any parameters (e.g., @c charset ).
 *  For example, if @c contentType is @c "text/plain; charset=utf-8" , this property
 *  returns @c "text/plain" .
 *
 *  @see contentType
 */
@property(nonatomic, copy, readonly) NSString* mimeType;

@end

/**
 *  @brief Concrete multipart part subclass that holds its content as in-memory data.
 *
 *  @discussion DZWebServerMultiPartArgument represents a non-file field from a
 *  @c multipart/form-data submission. The raw body bytes of the part are stored in
 *  the @c data property, and a convenience @c string property is provided for
 *  text-typed parts.
 *
 *  Instances of this class are created automatically by @c DZWebServerMultiPartFormRequest
 *  during body parsing and are accessible via its @c arguments property.
 *
 *  @see DZWebServerMultiPartFormRequest
 *  @see DZWebServerMultiPart
 */
@interface DZWebServerMultiPartArgument : DZWebServerMultiPart

/**
 *  @brief The raw data bytes of this part's body.
 */
@property(nonatomic, copy, readonly) NSData* data;

/**
 *  @brief The part's body data interpreted as a string, or @c nil if conversion fails.
 *
 *  @discussion This property attempts to decode the raw @c data into an @c NSString.
 *  Conversion is only attempted when the part's @c contentType has a @c "text/" prefix.
 *  The text encoding is determined from the @c charset parameter of the @c Content-Type
 *  header; if no charset is specified, UTF-8 is assumed.
 *
 *  Returns @c nil if:
 *  - The content type is not a text type (i.e., does not start with @c "text/" ).
 *  - The data cannot be decoded using the determined encoding.
 */
@property(nonatomic, copy, readonly, nullable) NSString* string;

@end

/**
 *  @brief Concrete multipart part subclass that holds its content as a temporary file on disk.
 *
 *  @discussion DZWebServerMultiPartFile represents a file upload field from a
 *  @c multipart/form-data submission. The uploaded file's bytes are written to a
 *  uniquely named temporary file in @c NSTemporaryDirectory() during body parsing.
 *
 *  Instances of this class are created automatically by @c DZWebServerMultiPartFormRequest
 *  during body parsing and are accessible via its @c files property.
 *
 *  @warning The temporary file is automatically deleted when this object is deallocated.
 *  If you need to keep the file, move or copy it to a permanent location before this
 *  object is released.
 *
 *  @see DZWebServerMultiPartFormRequest
 *  @see DZWebServerMultiPart
 */
@interface DZWebServerMultiPartFile : DZWebServerMultiPart

/**
 *  @brief The original file name as provided by the client.
 *
 *  @discussion Extracted from the @c filename parameter of the @c Content-Disposition
 *  header. This is the name the client used for the file on their local system
 *  (e.g., @c "photo.jpg" ).
 */
@property(nonatomic, copy, readonly) NSString* fileName;

/**
 *  @brief The absolute path to the temporary file containing the uploaded data.
 *
 *  @discussion The temporary file is created in @c NSTemporaryDirectory() with a
 *  globally unique name. The file contains the raw bytes of the uploaded part body.
 *
 *  @warning This temporary file is automatically deleted when the
 *  @c DZWebServerMultiPartFile instance is deallocated. You must move or copy
 *  the file to a different location before releasing this object if you wish
 *  to preserve its contents.
 */
@property(nonatomic, copy, readonly) NSString* temporaryPath;

@end

/**
 *  @brief Request subclass that parses an HTTP body encoded as @c multipart/form-data .
 *
 *  @discussion DZWebServerMultiPartFormRequest automatically decodes the MIME multipart
 *  boundary-delimited body as it is received, splitting it into individual parts.
 *  Non-file fields are stored as @c DZWebServerMultiPartArgument objects (in memory),
 *  while file uploads are streamed to temporary files on disk and wrapped as
 *  @c DZWebServerMultiPartFile objects.
 *
 *  The parser supports nested @c multipart/mixed parts (used by some clients to attach
 *  multiple files to a single form field) and handles chunked transfer encoding
 *  transparently through the base class.
 *
 *  @b Usage: Register this class as the request class when adding a handler for routes
 *  that accept file uploads or form submissions with @c enctype="multipart/form-data" .
 *
 *  @note The MIME boundary is extracted from the @c Content-Type header's @c boundary
 *  parameter during the @c open phase. If the boundary is missing or malformed,
 *  parsing will fail with an error.
 *
 *  @see DZWebServerMultiPartArgument
 *  @see DZWebServerMultiPartFile
 *  @see DZWebServerRequest
 */
@interface DZWebServerMultiPartFormRequest : DZWebServerRequest

/**
 *  @brief All non-file parts parsed from the multipart form body.
 *
 *  @discussion An ordered array of @c DZWebServerMultiPartArgument instances, one for each
 *  non-file field in the submitted form. The array preserves the order in which the
 *  parts appeared in the request body. Multiple arguments may share the same
 *  @c controlName if the form contains repeated fields.
 *
 *  This property is populated during body parsing and is available after the
 *  request has been fully received.
 *
 *  @see firstArgumentForControlName:
 */
@property(nonatomic, copy, readonly) NSArray<DZWebServerMultiPartArgument*>* arguments;

/**
 *  @brief All file upload parts parsed from the multipart form body.
 *
 *  @discussion An ordered array of @c DZWebServerMultiPartFile instances, one for each
 *  file upload field in the submitted form. The array preserves the order in which
 *  the parts appeared in the request body. Multiple files may share the same
 *  @c controlName if the form uses a multi-file upload field or nested
 *  @c multipart/mixed encoding.
 *
 *  This property is populated during body parsing and is available after the
 *  request has been fully received.
 *
 *  @warning Each file's temporary path is only valid for the lifetime of its
 *  @c DZWebServerMultiPartFile object. Move or copy files before releasing the request.
 *
 *  @see firstFileForControlName:
 */
@property(nonatomic, copy, readonly) NSArray<DZWebServerMultiPartFile*>* files;

/**
 *  @brief Returns the MIME type string for multipart form data submissions.
 *
 *  @return The string @c "multipart/form-data" .
 *
 *  @discussion This convenience method returns the content type that this request class
 *  handles. It can be used when registering handlers to match incoming requests
 *  with the appropriate request class.
 */
+ (NSString*)mimeType;

/**
 *  @brief Finds the first argument part matching a given control name.
 *
 *  @param name The form control name to search for. Compared using exact string equality.
 *
 *  @return The first @c DZWebServerMultiPartArgument whose @c controlName matches @a name,
 *          or @c nil if no matching argument exists.
 *
 *  @discussion Performs a linear search through the @c arguments array and returns the
 *  first match. If the form may contain multiple values for the same control name,
 *  iterate the @c arguments array directly to retrieve all of them.
 *
 *  @see arguments
 */
- (nullable DZWebServerMultiPartArgument*)firstArgumentForControlName:(NSString*)name;

/**
 *  @brief Finds the first file part matching a given control name.
 *
 *  @param name The form control name to search for. Compared using exact string equality.
 *
 *  @return The first @c DZWebServerMultiPartFile whose @c controlName matches @a name,
 *          or @c nil if no matching file exists.
 *
 *  @discussion Performs a linear search through the @c files array and returns the
 *  first match. If the form may contain multiple files for the same control name,
 *  iterate the @c files array directly to retrieve all of them.
 *
 *  @see files
 */
- (nullable DZWebServerMultiPartFile*)firstFileForControlName:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
