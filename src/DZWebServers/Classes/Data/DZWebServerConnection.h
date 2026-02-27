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

#import "DZWebServer.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief Handles a single HTTP connection from a remote client.
 *
 *  @discussion DZWebServerConnection is instantiated internally by DZWebServer
 *  for each incoming TCP connection. Each instance manages the full lifecycle of
 *  one HTTP request/response exchange: reading headers, reading the body,
 *  dispatching to a matching handler, and writing the response. The instance
 *  stays alive until the underlying socket is closed.
 *
 *  You cannot create instances of this class directly. Instead, subclass it and
 *  override the hooks declared in the @c DZWebServerConnection(Subclassing)
 *  category. Pass your subclass via the @c DZWebServerOption_ConnectionClass
 *  option when starting the server.
 *
 *  All I/O is performed asynchronously on GCD global concurrent queues whose
 *  priority is configured by @c DZWebServerOption_DispatchQueuePriority.
 *
 *  @warning The connection retains its owning @c DZWebServer for its entire
 *  lifetime. The server is only released when the connection is deallocated.
 *
 *  @see DZWebServer
 *  @see DZWebServerOption_ConnectionClass
 */
@interface DZWebServerConnection : NSObject

/**
 *  @brief The @c DZWebServer instance that owns this connection.
 *
 *  @discussion The connection retains the server for its entire lifetime.
 *  This property is set during initialization and never changes.
 */
@property(nonatomic, readonly) DZWebServer* server;

/**
 *  @brief Whether the connection uses IPv6.
 *
 *  @discussion Determined by inspecting the @c sa_family field of the local
 *  socket address. Returns @c YES when the family is @c AF_INET6, @c NO for
 *  @c AF_INET (IPv4).
 */
@property(nonatomic, readonly, getter=isUsingIPv6) BOOL usingIPv6;

/**
 *  @brief The local (server-side) socket address as raw @c struct @c sockaddr data.
 *
 *  @discussion The returned @c NSData wraps a @c struct @c sockaddr (either
 *  @c sockaddr_in for IPv4 or @c sockaddr_in6 for IPv6). This value is set at
 *  connection initialization and does not change.
 *
 *  @see localAddressString
 */
@property(nonatomic, copy, readonly) NSData* localAddressData;

/**
 *  @brief The local (server-side) socket address as a human-readable string.
 *
 *  @discussion Formatted from @c localAddressData using
 *  @c DZWebServerStringFromSockAddr with the service (port) included.
 *  Typical format: @c "192.168.1.10:8080" or @c "[::1]:8080".
 *
 *  @see localAddressData
 */
@property(nonatomic, copy, readonly) NSString* localAddressString;

/**
 *  @brief The remote (client-side) socket address as raw @c struct @c sockaddr data.
 *
 *  @discussion The returned @c NSData wraps a @c struct @c sockaddr (either
 *  @c sockaddr_in for IPv4 or @c sockaddr_in6 for IPv6). This value is set at
 *  connection initialization and does not change.
 *
 *  @see remoteAddressString
 */
@property(nonatomic, copy, readonly) NSData* remoteAddressData;

/**
 *  @brief The remote (client-side) socket address as a human-readable string.
 *
 *  @discussion Formatted from @c remoteAddressData using
 *  @c DZWebServerStringFromSockAddr with the service (port) included.
 *  Typical format: @c "10.0.0.5:52341" or @c "[::1]:52341".
 *
 *  @see remoteAddressData
 */
@property(nonatomic, copy, readonly) NSString* remoteAddressString;

/**
 *  @brief The cumulative number of bytes received from the remote client.
 *
 *  @discussion Incremented each time raw data is read from the socket via
 *  @c -didReadBytes:length:. Includes HTTP headers and body. The value is
 *  @c 0 immediately after the connection is opened and grows monotonically.
 */
@property(nonatomic, readonly) NSUInteger totalBytesRead;

/**
 *  @brief The cumulative number of bytes sent to the remote client.
 *
 *  @discussion Incremented each time raw data is written to the socket via
 *  @c -didWriteBytes:length:. Includes HTTP response headers and body. The
 *  value is @c 0 immediately after the connection is opened and grows
 *  monotonically.
 */
@property(nonatomic, readonly) NSUInteger totalBytesWritten;

@end

/**
 *  @brief Subclassing hooks to customize the HTTP connection lifecycle.
 *
 *  @discussion Override these methods in a @c DZWebServerConnection subclass to
 *  intercept, inspect, or modify the request/response pipeline. Register your
 *  subclass with @c DZWebServerOption_ConnectionClass when starting the server.
 *
 *  The hooks are called in the following order for a successful request:
 *  1. @c -open
 *  2. @c -didReadBytes:length: (one or more times)
 *  3. @c -rewriteRequestURL:withMethod:headers:
 *  4. @c -preflightRequest:
 *  5. @c -processRequest:completion:
 *  6. @c -overrideResponse:forRequest:
 *  7. @c -didWriteBytes:length: (one or more times)
 *  8. @c -close
 *
 *  If the request is invalid or processing fails, @c -abortRequest:withStatusCode:
 *  is called instead of steps 4-6.
 *
 *  @warning These methods can be called on any GCD thread. Always call @c super
 *  when overriding them.
 *
 *  @see DZWebServerOption_ConnectionClass
 */
@interface DZWebServerConnection (Subclassing)

/**
 *  @brief Called when the connection is first opened, before any data is read.
 *
 *  @discussion Override this method to perform early validation (e.g. checking
 *  the remote address against an allow-list). If you return @c NO, the
 *  underlying socket is immediately closed and the connection is discarded.
 *
 *  The default implementation returns @c YES.
 *
 *  @return @c YES to accept the connection, @c NO to reject and close it.
 *
 *  @warning Always call @c [super open] when overriding.
 */
- (BOOL)open;

/**
 *  @brief Called after data has been read from the remote client.
 *
 *  @discussion Invoked each time a chunk of raw data is received from the
 *  socket. The default implementation increments @c totalBytesRead by
 *  @p length. Override to monitor or log incoming traffic.
 *
 *  @param bytes  Pointer to the raw bytes that were read. The buffer is valid
 *                only for the duration of this call.
 *  @param length Number of bytes in @p bytes.
 *
 *  @warning Do not modify the contents of @p bytes. Always call @c super.
 */
- (void)didReadBytes:(const void*)bytes length:(NSUInteger)length;

/**
 *  @brief Called after data has been written to the remote client.
 *
 *  @discussion Invoked each time a chunk of raw data is sent over the socket.
 *  The default implementation increments @c totalBytesWritten by @p length.
 *  Override to monitor or log outgoing traffic.
 *
 *  @param bytes  Pointer to the raw bytes that were written. The buffer is
 *                valid only for the duration of this call.
 *  @param length Number of bytes in @p bytes.
 *
 *  @warning Do not modify the contents of @p bytes. Always call @c super.
 */
- (void)didWriteBytes:(const void*)bytes length:(NSUInteger)length;

/**
 *  @brief Called after HTTP headers are received to optionally rewrite the
 *  request URL.
 *
 *  @discussion Use this hook to implement URL rewriting (e.g. virtual hosts,
 *  path redirects, or canonical URL normalization). The returned URL is used
 *  for all subsequent handler matching and request processing.
 *
 *  The default implementation returns @p url unchanged.
 *
 *  @param url     The original request URL parsed from the HTTP request line.
 *  @param method  The HTTP method verb (e.g. @c "GET", @c "POST"). Method verbs
 *                 are case-sensitive and uppercase. If the server has
 *                 @c DZWebServerOption_AutomaticallyMapHEADToGET enabled, a
 *                 @c "HEAD" request will already be mapped to @c "GET" here.
 *  @param headers The HTTP request headers. Header names are case-insensitive
 *                 but have been standardized by @c CFHTTPMessage.
 *
 *  @return A non-nil @c NSURL to use as the effective request URL.
 */
- (NSURL*)rewriteRequestURL:(NSURL*)url withMethod:(NSString*)method headers:(NSDictionary<NSString*, NSString*>*)headers;

/**
 *  @brief Called before a valid request is dispatched to the handler's process
 *  block, allowing early interception.
 *
 *  @discussion Return a non-nil @c DZWebServerResponse to short-circuit handler
 *  processing entirely. The returned response will be passed through
 *  @c -overrideResponse:forRequest: before being sent to the client.
 *
 *  The default implementation enforces HTTP authentication when the server is
 *  configured with @c DZWebServerOption_AuthenticationMethod. It checks for
 *  Basic (RFC 2617) or Digest Access (RFC 2617) credentials in the
 *  @c Authorization header and returns a 401 Unauthorized response with the
 *  appropriate @c WWW-Authenticate challenge header on failure. When
 *  authentication is not configured, the default implementation returns @c nil.
 *
 *  @param request The fully parsed HTTP request (headers and body have been
 *                 read).
 *
 *  @return A @c DZWebServerResponse to send immediately (bypassing handler
 *          processing), or @c nil to continue to @c -processRequest:completion:.
 *
 *  @see DZWebServerOption_AuthenticationMethod
 *  @see DZWebServerOption_AuthenticationAccounts
 */
- (nullable DZWebServerResponse*)preflightRequest:(DZWebServerRequest*)request;

/**
 *  @brief Called to process the request through the matched handler's async
 *  process block.
 *
 *  @discussion This method is invoked only when @c -preflightRequest: returns
 *  @c nil. The default implementation calls the matched handler's
 *  @c asyncProcessBlock with @p request and @p completion.
 *
 *  Override to add pre- or post-processing around the handler invocation.
 *  You must eventually call @p completion exactly once with either a
 *  @c DZWebServerResponse or @c nil (which triggers a 500 Internal Server
 *  Error).
 *
 *  @param request    The fully parsed HTTP request.
 *  @param completion A block that must be called exactly once with the response.
 *                    Passing @c nil results in a 500 status code.
 *
 *  @see DZWebServerAsyncProcessBlock
 */
- (void)processRequest:(DZWebServerRequest*)request completion:(DZWebServerCompletionBlock)completion;

/**
 *  @brief Called after a response has been generated, allowing last-minute
 *  modification or replacement.
 *
 *  @discussion This hook runs after either @c -preflightRequest: or
 *  @c -processRequest:completion: has produced a non-nil response and before
 *  the response headers are serialized and written to the socket.
 *
 *  You may modify properties of @p response and return it, or return an
 *  entirely new @c DZWebServerResponse instance.
 *
 *  The default implementation implements conditional-GET logic per RFC 2616
 *  sections 14.25 and 14.26. For 2xx responses, it compares the response's
 *  @c eTag and @c lastModifiedDate against the request's @c If-None-Match and
 *  @c If-Modified-Since headers. When the resource has not changed:
 *  - For @c GET and @c HEAD requests: returns a 304 Not Modified response.
 *  - For other methods: returns a 412 Precondition Failed response.
 *
 *  The replacement response preserves @c cacheControlMaxAge, @c lastModifiedDate,
 *  and @c eTag from the original response.
 *
 *  @param response The response produced by the handler or preflight step.
 *  @param request  The original HTTP request.
 *
 *  @return A @c DZWebServerResponse to send to the client. Must not be @c nil.
 */
- (DZWebServerResponse*)overrideResponse:(DZWebServerResponse*)response forRequest:(DZWebServerRequest*)request;

/**
 *  @brief Called when the request cannot be fulfilled and the connection must
 *  send an error response.
 *
 *  @discussion This method is invoked in several failure scenarios:
 *  - Malformed or unparseable HTTP headers.
 *  - No registered handler matched the request (status 501 Not Implemented).
 *  - The handler's process block returned @c nil (status 500).
 *  - Body read/write errors during request processing.
 *
 *  The default implementation sends a response consisting solely of the HTTP
 *  status line and standard headers (@c Connection: Close, @c Server, @c Date)
 *  with no body. The status code is always in the 4xx or 5xx range.
 *
 *  @param request    The partially or fully parsed request, or @c nil if the
 *                    HTTP headers could not be parsed.
 *  @param statusCode The HTTP status code to return (400-599).
 *
 *  @warning If the HTTP headers were malformed or incomplete, @p request
 *  will be @c nil.
 */
- (void)abortRequest:(nullable DZWebServerRequest*)request withStatusCode:(NSInteger)statusCode;

/**
 *  @brief Called when the connection is about to be closed and deallocated.
 *
 *  @discussion Invoked during @c -dealloc after the response has been fully
 *  written (or the request has been aborted). Use this hook to perform
 *  cleanup such as logging the final request/response summary.
 *
 *  The default implementation logs a verbose-level message containing the
 *  local address, remote address, HTTP status code, request method and path,
 *  and the total bytes read/written.
 *
 *  @warning Always call @c [super close] when overriding. This method is called
 *  on whatever thread triggers deallocation of the connection.
 */
- (void)close;

@end

NS_ASSUME_NONNULL_END
