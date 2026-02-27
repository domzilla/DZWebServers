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
 *  @brief A request subclass that stores the HTTP body to a temporary file on disk.
 *
 *  @discussion DZWebServerFileRequest is a concrete subclass of DZWebServerRequest
 *  designed for handling requests with large bodies that should not be held entirely
 *  in memory. As the body data is received by the connection, it is written
 *  incrementally to a temporary file in the system's temporary directory.
 *
 *  The temporary file is created when the connection calls @c -open: and is
 *  populated as chunks arrive via @c -writeData:error:. The file uses POSIX
 *  permissions @c 0644 (owner read/write, group and others read-only).
 *
 *  The file is automatically deleted when this request object is deallocated.
 *  If you need to retain the file beyond the lifetime of the request, move or
 *  copy it to a permanent location before the request is released.
 *
 *  @note This class is typically used by registering it as the request class
 *  parameter in @c -addHandlerForMethod:path:requestClass:processBlock: or
 *  the regex-based equivalent on DZWebServer.
 *
 *  @see DZWebServerRequest
 *  @see DZWebServerDataRequest
 */
@interface DZWebServerFileRequest : DZWebServerRequest

/**
 *  @brief The file-system path to the temporary file containing the received request body.
 *
 *  @discussion The path points to a uniquely named file inside the system's temporary
 *  directory (@c NSTemporaryDirectory()). The file is created when the connection
 *  begins receiving body data and is populated incrementally as data arrives.
 *
 *  After the request handler has finished processing, this path remains valid
 *  until the DZWebServerFileRequest instance is deallocated.
 *
 *  @warning The temporary file is automatically deleted when this request object
 *  is deallocated. If you need to keep the file, you @b must move or copy it to
 *  a different location before the request is released.
 */
@property(nonatomic, copy, readonly) NSString* temporaryPath;

@end

NS_ASSUME_NONNULL_END
