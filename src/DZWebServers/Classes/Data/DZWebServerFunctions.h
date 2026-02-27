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

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Returns the MIME type corresponding to a file extension.
 *
 * @discussion Resolves a file extension to its MIME type using a three-tier lookup:
 * 1. The caller-provided @c overrides dictionary (highest priority).
 * 2. A built-in overrides table (e.g., @c "css" maps to @c "text/css" ).
 * 3. The system UTType registry via CoreServices.
 *
 * The extension is compared case-insensitively. If no match is found at any tier,
 * @c "application/octet-stream" is returned as the default.
 *
 * @param extension The file extension to look up, without a leading period (e.g., @c "html" ).
 * @param overrides An optional dictionary mapping lowercased file extensions (without periods)
 *                  to MIME type strings. Pass @c nil to use only built-in and system mappings.
 * @return The MIME type string for the given extension, or @c "application/octet-stream" if unknown.
 *
 * @note This function is thread-safe.
 */
NSString* DZWebServerGetMimeTypeForExtension(NSString* extension, NSDictionary<NSString*, NSString*>* _Nullable overrides)
    NS_SWIFT_NAME(DZWebServerGetMimeType(forExtension:overrides:));

/**
 * @brief Percent-encodes a string for safe inclusion in a URL.
 *
 * @discussion Applies percent-encoding using UTF-8 to all characters that are not
 * unreserved per RFC 3986. In addition, the normally-legal characters
 * @c :@/?&=+ are also escaped to ensure compatibility with URL-encoded form
 * values and query strings.
 *
 * Internally uses @c CFURLCreateStringByAddingPercentEscapes with UTF-8 encoding.
 *
 * @param string The string to percent-encode.
 * @return The percent-encoded string, or @c nil if encoding fails.
 *
 * @note This function is thread-safe.
 * @see DZWebServerUnescapeURLString
 */
NSString* _Nullable DZWebServerEscapeURLString(NSString* string);

/**
 * @brief Decodes a percent-encoded URL string.
 *
 * @discussion Replaces all percent-encoded sequences (e.g., @c %20 ) with their
 * corresponding UTF-8 characters. Internally uses
 * @c CFURLCreateStringByReplacingPercentEscapesUsingEncoding with UTF-8 encoding.
 *
 * @param string The percent-encoded string to decode.
 * @return The decoded string, or @c nil if decoding fails (e.g., malformed escape sequences).
 *
 * @note This function is thread-safe.
 * @see DZWebServerEscapeURLString
 */
NSString* _Nullable DZWebServerUnescapeURLString(NSString* string);

/**
 * @brief Parses an @c application/x-www-form-urlencoded form string into key-value pairs.
 *
 * @discussion Splits the form string on @c & delimiters, then splits each pair on the
 * first @c = character. Both keys and values are unescaped: @c + characters are replaced
 * with spaces, and percent-encoded sequences are decoded via @c DZWebServerUnescapeURLString.
 *
 * If a key or value cannot be decoded, that pair is skipped and a warning is logged.
 * Duplicate keys are resolved in favor of the last occurrence.
 *
 * @param form The URL-encoded form body string (e.g., @c "name=John&age=30" ).
 * @return A dictionary of decoded key-value pairs. Returns an empty dictionary if the
 *         form string contains no valid pairs.
 *
 * @note This function is thread-safe.
 * @see http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4.1
 */
NSDictionary<NSString*, NSString*>* DZWebServerParseURLEncodedForm(NSString* form);

/**
 * @brief Returns the IP address of the device's primary network interface.
 *
 * @discussion
 * **macOS:** Queries the SystemConfiguration dynamic store to determine the primary
 * connected network service, then returns its IPv4 or IPv6 address. Falls back to the
 * loopback interface ( @c lo0 ) if no primary interface is found.
 *
 * **iOS (device):** Returns the address of the Wi-Fi interface ( @c en0 ).
 *
 * **iOS Simulator / tvOS:** Checks both @c en0 (Ethernet) and @c en1 (Wi-Fi) since
 * SystemConfiguration is not available in the simulator.
 *
 * @param useIPv6 Pass @c YES to return an IPv6 address, or @c NO for IPv4.
 * @return The IP address as a human-readable string (e.g., @c "192.168.1.42" or
 *         @c "fe80::1" ), or @c nil if no matching interface is up or connected.
 *
 * @note This function is thread-safe. It uses @c getifaddrs internally and frees
 *       the allocated memory before returning.
 */
NSString* _Nullable DZWebServerGetPrimaryIPAddress(BOOL useIPv6);

/**
 * @brief Formats a date as an RFC 822 / RFC 1123 date string.
 *
 * @discussion Produces a string in the format @c "EEE, dd MMM yyyy HH:mm:ss GMT"
 * using the @c en_US locale and the GMT time zone, suitable for HTTP headers such as
 * @c Date , @c Last-Modified , and @c Expires .
 *
 * The underlying @c NSDateFormatter is shared and access is serialized on a private
 * serial dispatch queue.
 *
 * @param date The date to format.
 * @return A date string in RFC 822 format (e.g., @c "Mon, 27 Feb 2026 12:00:00 GMT" ).
 *
 * @note This function is thread-safe.
 * @see DZWebServerParseRFC822
 * @see https://tools.ietf.org/html/rfc822#section-5
 * @see https://tools.ietf.org/html/rfc1123#section-5.2.14
 */
NSString* DZWebServerFormatRFC822(NSDate* date);

/**
 * @brief Parses an RFC 822 / RFC 1123 date string into an @c NSDate.
 *
 * @discussion Expects a string in the format @c "EEE, dd MMM yyyy HH:mm:ss GMT" .
 * The parser uses the @c en_US locale and is hardcoded to the GMT time zone.
 *
 * The underlying @c NSDateFormatter is shared and access is serialized on a private
 * serial dispatch queue.
 *
 * @param string The RFC 822 date string to parse (e.g., @c "Mon, 27 Feb 2026 12:00:00 GMT" ).
 * @return The parsed date, or @c nil if the string does not match the expected format.
 *
 * @warning Only the GMT time zone is supported. Strings with other time zone designators
 *          will fail to parse. RFC 850 and ANSI C @c asctime() formats are not supported.
 *
 * @note This function is thread-safe.
 * @see DZWebServerFormatRFC822
 * @see https://tools.ietf.org/html/rfc822#section-5
 * @see https://tools.ietf.org/html/rfc1123#section-5.2.14
 */
NSDate* _Nullable DZWebServerParseRFC822(NSString* string);

/**
 * @brief Formats a date as an ISO 8601 / RFC 3339 date-time string.
 *
 * @discussion Produces a string in the format @c "yyyy-MM-dd'T'HH:mm:ss+00:00"
 * using the @c en_US locale and the GMT time zone. The offset is always @c +00:00
 * (UTC). Suitable for WebDAV property values and JSON payloads.
 *
 * The underlying @c NSDateFormatter is shared and access is serialized on a private
 * serial dispatch queue.
 *
 * @param date The date to format.
 * @return A date-time string in ISO 8601 format (e.g., @c "2026-02-27T12:00:00+00:00" ).
 *
 * @note This function is thread-safe.
 * @see DZWebServerParseISO8601
 * @see http://tools.ietf.org/html/rfc3339#section-5.6
 */
NSString* DZWebServerFormatISO8601(NSDate* date);

/**
 * @brief Parses an ISO 8601 / RFC 3339 date-time string into an @c NSDate.
 *
 * @discussion Expects a string in the format @c "yyyy-MM-dd'T'HH:mm:ss+00:00" .
 * The parser uses the @c en_US locale and is hardcoded to the GMT time zone.
 *
 * The underlying @c NSDateFormatter is shared and access is serialized on a private
 * serial dispatch queue.
 *
 * @param string The ISO 8601 date-time string to parse (e.g., @c "2026-02-27T12:00:00+00:00" ).
 * @return The parsed date, or @c nil if the string does not match the expected format.
 *
 * @warning Only the "calendar" date-time variant ( @c yyyy-MM-ddTHH:mm:ss ) is supported.
 *          Ordinal dates, week dates, and duration formats are not recognized.
 *          Only the @c +00:00 (GMT) time zone offset is supported; other offsets will
 *          cause parsing to fail.
 *
 * @note This function is thread-safe.
 * @see DZWebServerFormatISO8601
 * @see http://tools.ietf.org/html/rfc3339#section-5.6
 */
NSDate* _Nullable DZWebServerParseISO8601(NSString* string);

/**
 * @brief Normalizes a URL path by resolving relative segments and removing redundancies.
 *
 * @discussion Processes the path component-by-component (split on @c / ):
 * - @c "." segments are removed.
 * - @c ".." segments remove the preceding component (parent traversal).
 * - Empty segments (from consecutive slashes) are collapsed.
 * - A trailing slash is removed from the result.
 *
 * If the original path begins with a leading @c / , the normalized result preserves it.
 * This is useful for sanitizing request paths before mapping them to the file system.
 *
 * @param path The URL path to normalize (e.g., @c "/a/b/../c/./d/" ).
 * @return The normalized path (e.g., @c "/a/c/d" ). Returns an empty string if all
 *         components are resolved away.
 *
 * @note This function is thread-safe and does not access the file system.
 */
NSString* DZWebServerNormalizePath(NSString* path);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
