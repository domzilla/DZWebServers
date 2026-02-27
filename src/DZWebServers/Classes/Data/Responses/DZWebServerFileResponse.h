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
 *  @brief A response that streams its body from a file on disk.
 *
 *  @discussion DZWebServerFileResponse is a concrete subclass of DZWebServerResponse
 *  that reads its HTTP body data from a file at a given path. It supports serving
 *  entire files or specific byte ranges (for resumable downloads and HTTP Range
 *  requests), and can optionally set the @c Content-Disposition header to trigger
 *  a file download in the client's browser.
 *
 *  Upon initialization, the following properties are automatically populated
 *  from the file's metadata:
 *
 *  - @c contentType -- derived from the file extension using a built-in MIME type
 *    mapping (customizable via MIME type overrides).
 *  - @c lastModifiedDate -- set to the file's last-modification timestamp.
 *  - @c eTag -- computed from the file's inode number and modification time.
 *  - @c contentLength -- set to the number of bytes that will be served (which
 *    may be less than the full file size when a byte range is specified).
 *
 *  When a byte range is provided, the response automatically sets the HTTP status
 *  code to @c 206 (Partial Content) and includes the appropriate @c Content-Range
 *  header.
 *
 *  The file is opened for reading only when the connection calls @c -open: and is
 *  read incrementally in 32 KB chunks via @c -readData: to keep memory usage low,
 *  even for very large files. Symbolic links are not followed when opening the file.
 *
 *  @note Initialization returns @c nil if the file does not exist, is not a regular
 *  file, or if the requested byte range resolves to zero bytes.
 *
 *  @see DZWebServerResponse
 *  @see DZWebServerRequest
 */
@interface DZWebServerFileResponse : DZWebServerResponse

/**
 *  @brief The MIME type of the response body.
 *
 *  @discussion Redeclared as non-null. This property is automatically set during
 *  initialization based on the file's extension using the built-in MIME type mapping.
 *  Custom mappings can be provided via the @c mimeTypeOverrides parameter of the
 *  designated initializer.
 *
 *  @see DZWebServerGetMimeTypeForExtension
 */
@property(nonatomic, copy) NSString* contentType;

/**
 *  @brief The last-modification date of the served file.
 *
 *  @discussion Redeclared as non-null. This property is automatically set during
 *  initialization from the file's filesystem modification timestamp (@c st_mtimespec).
 *  It is sent to the client via the @c Last-Modified HTTP header and can be used
 *  for conditional request handling (e.g., @c If-Modified-Since).
 */
@property(nonatomic) NSDate* lastModifiedDate;

/**
 *  @brief The entity tag for the served file.
 *
 *  @discussion Redeclared as non-null. This property is automatically set during
 *  initialization and is computed from the file's inode number and modification
 *  timestamp (seconds and nanoseconds). It is sent to the client via the @c ETag
 *  HTTP header and can be used for conditional request handling (e.g.,
 *  @c If-None-Match).
 */
@property(nonatomic, copy) NSString* eTag;

/**
 *  @brief Default initialization is not available.
 *
 *  @discussion Use one of the file-based initializers instead.
 *
 *  @see -initWithFile:
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  @brief Creates a response with the full contents of a file.
 *
 *  @discussion This is a convenience factory method equivalent to calling
 *  @c -initWithFile: . The response will serve the entire file with no byte
 *  range restriction and no @c Content-Disposition attachment header.
 *
 *  @param path The absolute path to the file on disk.
 *
 *  @return A new file response, or @c nil if the file does not exist or is not
 *  a regular file.
 *
 *  @see -initWithFile:
 */
+ (nullable instancetype)responseWithFile:(NSString*)path;

/**
 *  @brief Creates a response with the full contents of a file, optionally as a download attachment.
 *
 *  @discussion This is a convenience factory method equivalent to calling
 *  @c -initWithFile:isAttachment: . When @a attachment is @c YES, the response
 *  includes a @c Content-Disposition header with the filename, causing most
 *  browsers to prompt a file download dialog. The filename is encoded using both
 *  ISO Latin-1 (for legacy clients) and UTF-8 (via @c filename* per RFC 5987).
 *
 *  @param path       The absolute path to the file on disk.
 *  @param attachment If @c YES, the @c Content-Disposition header is set to
 *                    @c "attachment" with the file's name, triggering a download
 *                    in the client. If @c NO, no such header is added.
 *
 *  @return A new file response, or @c nil if the file does not exist or is not
 *  a regular file.
 *
 *  @see -initWithFile:isAttachment:
 */
+ (nullable instancetype)responseWithFile:(NSString*)path isAttachment:(BOOL)attachment;

/**
 *  @brief Creates a response with a byte range of a file's contents.
 *
 *  @discussion This is a convenience factory method equivalent to calling
 *  @c -initWithFile:byteRange: . The byte range is automatically clamped to the
 *  actual file size, and the response is configured with HTTP status @c 206
 *  (Partial Content) and the appropriate @c Content-Range header when a valid
 *  range is provided.
 *
 *  @param path  The absolute path to the file on disk.
 *  @param range The byte range to serve. Use @c NSMakeRange(NSUIntegerMax, 0) for the
 *               full file, @c NSMakeRange(offset, length) for a range from the beginning,
 *               or @c NSMakeRange(NSUIntegerMax, length) for a range from the end.
 *
 *  @return A new file response, or @c nil if the file does not exist, is not a
 *  regular file, or the resolved byte range has zero length.
 *
 *  @see -initWithFile:byteRange:
 */
+ (nullable instancetype)responseWithFile:(NSString*)path byteRange:(NSRange)range;

/**
 *  @brief Creates a response with a byte range of a file's contents, optionally as a download attachment.
 *
 *  @discussion This is a convenience factory method that combines byte-range serving
 *  with the @c Content-Disposition attachment header. Equivalent to calling the
 *  designated initializer with @c nil MIME type overrides.
 *
 *  @param path       The absolute path to the file on disk.
 *  @param range      The byte range to serve. See @c -initWithFile:byteRange: for the
 *                    range encoding conventions.
 *  @param attachment If @c YES, the @c Content-Disposition header is set to
 *                    @c "attachment" with the file's name. If @c NO, no such header
 *                    is added.
 *
 *  @return A new file response, or @c nil if the file does not exist, is not a
 *  regular file, or the resolved byte range has zero length.
 *
 *  @see -initWithFile:byteRange:isAttachment:mimeTypeOverrides:
 */
+ (nullable instancetype)responseWithFile:(NSString*)path byteRange:(NSRange)range isAttachment:(BOOL)attachment;

/**
 *  @brief Initializes a response with the full contents of a file.
 *
 *  @discussion Equivalent to calling the designated initializer with a byte range
 *  of @c NSMakeRange(NSUIntegerMax, 0) (full file), @a attachment set to @c NO,
 *  and @c nil MIME type overrides.
 *
 *  @param path The absolute path to the file on disk.
 *
 *  @return An initialized file response, or @c nil if the file does not exist or
 *  is not a regular file.
 *
 *  @see -initWithFile:byteRange:isAttachment:mimeTypeOverrides:
 */
- (nullable instancetype)initWithFile:(NSString*)path;

/**
 *  @brief Initializes a response with the full contents of a file, optionally as a download attachment.
 *
 *  @discussion Equivalent to calling the designated initializer with a byte range
 *  of @c NSMakeRange(NSUIntegerMax, 0) (full file), the given @a attachment flag,
 *  and @c nil MIME type overrides.
 *
 *  @param path       The absolute path to the file on disk.
 *  @param attachment If @c YES, the @c Content-Disposition header is set to
 *                    @c "attachment" with the file's name. If @c NO, no such header
 *                    is added.
 *
 *  @return An initialized file response, or @c nil if the file does not exist or
 *  is not a regular file.
 *
 *  @see -initWithFile:byteRange:isAttachment:mimeTypeOverrides:
 */
- (nullable instancetype)initWithFile:(NSString*)path isAttachment:(BOOL)attachment;

/**
 *  @brief Initializes a response with a specific byte range of a file's contents.
 *
 *  @discussion Equivalent to calling the designated initializer with the given
 *  @a path and @a range, @a attachment set to @c NO, and @c nil MIME type overrides.
 *
 *  The @a range parameter encodes the desired byte range using the following conventions:
 *
 *  - @c NSMakeRange(NSUIntegerMax, 0) -- serve the full file (no range restriction).
 *  - @c NSMakeRange(offset, length) -- serve @a length bytes starting at @a offset
 *    from the beginning of the file.
 *  - @c NSMakeRange(NSUIntegerMax, length) -- serve the last @a length bytes of the file.
 *
 *  The offset and length values are automatically clamped to the actual file size.
 *  When a valid byte range is provided, the response sets its status code to @c 206
 *  (Partial Content) and includes a @c Content-Range header.
 *
 *  @note This parameter would typically be set to the value of the
 *  @c byteRange property on the current @c DZWebServerRequest.
 *
 *  @param path  The absolute path to the file on disk.
 *  @param range The byte range to serve, encoded as described above.
 *
 *  @return An initialized file response, or @c nil if the file does not exist,
 *  is not a regular file, or the resolved byte range has zero length.
 *
 *  @see -initWithFile:byteRange:isAttachment:mimeTypeOverrides:
 *  @see DZWebServerRequest.byteRange
 */
- (nullable instancetype)initWithFile:(NSString*)path byteRange:(NSRange)range;

/**
 *  @brief Designated initializer. Creates a response from a file with full control over
 *  byte range, attachment disposition, and MIME type mapping.
 *
 *  @discussion This is the designated initializer for @c DZWebServerFileResponse.
 *  All other initializers and factory methods ultimately call this method.
 *
 *  The initializer performs the following steps:
 *
 *  1. Verifies the file at @a path exists and is a regular file (not a directory,
 *     symlink, or special file) via @c lstat.
 *  2. Clamps the requested byte range to the actual file size and, if a valid
 *     range is provided, sets the status code to @c 206 (Partial Content) and
 *     adds the @c Content-Range header.
 *  3. If @a attachment is @c YES, sets the @c Content-Disposition header with the
 *     filename encoded in both ISO Latin-1 and UTF-8 (per RFC 5987).
 *  4. Sets @c contentType from the file extension (using @a overrides if provided),
 *     @c contentLength from the resolved byte count, @c lastModifiedDate from the
 *     file's modification timestamp, and @c eTag from the inode and modification time.
 *
 *  @param path       The absolute path to the file on disk.
 *  @param range      The byte range to serve. Use @c NSMakeRange(NSUIntegerMax, 0) for
 *                    the full file, @c NSMakeRange(offset, length) for a range from the
 *                    beginning, or @c NSMakeRange(NSUIntegerMax, length) for a range from
 *                    the end. Values are clamped to the file size.
 *  @param attachment If @c YES, the @c Content-Disposition header is set to @c "attachment"
 *                    with the file's name, triggering a download in the client. If @c NO,
 *                    no such header is added.
 *  @param overrides  An optional dictionary mapping lowercased file extensions (without
 *                    the leading period) to MIME type strings. These override the built-in
 *                    extension-to-MIME-type mapping. Pass @c nil to use the defaults.
 *
 *  @return An initialized file response, or @c nil if the file does not exist, is not a
 *  regular file, exceeds 4 GiB on 32-bit platforms, or the resolved byte range has zero
 *  length.
 *
 *  @warning On 32-bit platforms, files larger than 4 GiB are not supported and will
 *  cause initialization to return @c nil.
 *
 *  @see -initWithFile:
 *  @see -initWithFile:byteRange:
 *  @see DZWebServerGetMimeTypeForExtension
 */
- (nullable instancetype)initWithFile:(NSString*)path byteRange:(NSRange)range isAttachment:(BOOL)attachment mimeTypeOverrides:(nullable NSDictionary<NSString*, NSString*>*)overrides NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
