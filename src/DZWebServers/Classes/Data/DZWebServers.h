/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 Copyright (c) 2024, Dominic Rodemer
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

/**
 *  @brief Umbrella header for the DZWebServers framework.
 *
 *  @discussion DZWebServers is a lightweight, GCD-based HTTP 1.1 server framework
 *  designed for embedding directly in iOS and macOS applications. It requires no
 *  third-party dependencies — only Foundation and CoreServices.
 *
 *  The framework provides three main capabilities:
 *
 *  - **HTTP Server** — @c DZWebServer is the core server class. It listens for
 *    incoming connections on a configurable port and dispatches requests to
 *    registered handler blocks. @c DZWebServerConnection manages individual
 *    client connections.
 *
 *  - **WebDAV Server** — @c DZWebDAVServer extends @c DZWebServer with a
 *    fully functional WebDAV interface, allowing clients to browse, upload,
 *    download, move, copy, and delete files over the network.
 *
 *  - **File Upload UI** — @c DZWebUploader extends @c DZWebServer with a
 *    browser-based file management interface (bundled HTML/CSS/JS), enabling
 *    users to upload, download, and organize files from any web browser on
 *    the local network.
 *
 *  Requests and responses are modeled as a class hierarchy:
 *
 *  - **Requests:** @c DZWebServerRequest (base), @c DZWebServerDataRequest,
 *    @c DZWebServerFileRequest, @c DZWebServerMultiPartFormRequest,
 *    @c DZWebServerURLEncodedFormRequest.
 *
 *  - **Responses:** @c DZWebServerResponse (base), @c DZWebServerDataResponse,
 *    @c DZWebServerFileResponse, @c DZWebServerStreamedResponse,
 *    @c DZWebServerErrorResponse.
 *
 *  To get started, import this umbrella header:
 *
 *  @code
 *  #import <DZWebServers/DZWebServers.h>
 *  @endcode
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//! Project version number for BGFoundation.
FOUNDATION_EXPORT double DZWebServersVersionNumber;

//! Project version string for BGFoundation.
FOUNDATION_EXPORT const unsigned char DZWebServersVersionString[];

NS_ASSUME_NONNULL_END

// DZWebServer Core
#import "DZWebServer.h"
#import "DZWebServerConnection.h"
#import "DZWebServerFunctions.h"
#import "DZWebServerHTTPStatusCodes.h"
#import "DZWebServerResponse.h"
#import "DZWebServerRequest.h"

// DZWebServer Requests
#import "DZWebServerDataRequest.h"
#import "DZWebServerFileRequest.h"
#import "DZWebServerMultiPartFormRequest.h"
#import "DZWebServerURLEncodedFormRequest.h"

// DZWebServer Responses
#import "DZWebServerDataResponse.h"
#import "DZWebServerErrorResponse.h"
#import "DZWebServerFileResponse.h"
#import "DZWebServerStreamedResponse.h"

// DZWebUploader
#import "DZWebUploader.h"

// DZWebDAVServer
#import "DZWebDAVServer.h"
