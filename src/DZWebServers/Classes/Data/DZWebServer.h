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

#import <TargetConditionals.h>

#import "DZWebServerRequest.h"
#import "DZWebServerResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief Block used to determine whether a handler can handle an incoming HTTP request.
 *
 *  Called for every registered handler whenever a new HTTP request has started
 *  (i.e. HTTP headers have been received). The block receives the basic request
 *  metadata and must decide whether it wants to handle the request.
 *
 *  Handlers are evaluated in LIFO order (most recently added first). The first
 *  handler whose match block returns a non-nil request object wins.
 *
 *  @param requestMethod The HTTP method of the request (e.g. @c "GET", @c "POST").
 *  @param requestURL    The full URL of the request.
 *  @param requestHeaders A dictionary of HTTP header name/value pairs.
 *  @param urlPath       The percent-decoded path component of the URL.
 *  @param urlQuery      A dictionary of parsed query string key/value pairs.
 *
 *  @return A new @c DZWebServerRequest instance (or subclass) initialized with the
 *          provided request info if this handler can handle the request, or @c nil
 *          to pass the request to the next handler.
 */
typedef DZWebServerRequest* _Nullable (^DZWebServerMatchBlock)(NSString* requestMethod, NSURL* requestURL, NSDictionary<NSString*, NSString*>* requestHeaders, NSString* urlPath, NSDictionary<NSString*, NSString*>* urlQuery);

/**
 *  @brief Block used to synchronously generate an HTTP response for a fully received request.
 *
 *  Called after the entire HTTP body has been read. The block receives the
 *  @c DZWebServerRequest instance that was created by the corresponding
 *  @c DZWebServerMatchBlock during the matching phase.
 *
 *  @param request The fully received request object (including body data).
 *
 *  @return A @c DZWebServerResponse to send back to the client, or @c nil to
 *          return a 500 Internal Server Error. Prefer returning a
 *          @c DZWebServerErrorResponse on error for more descriptive error information.
 *
 *  @see DZWebServerAsyncProcessBlock
 */
typedef DZWebServerResponse* _Nullable (^DZWebServerProcessBlock)(__kindof DZWebServerRequest* request);

/**
 *  @brief Completion block used to deliver an asynchronously generated HTTP response.
 *
 *  @param response The @c DZWebServerResponse to send back to the client, or @c nil
 *                  to return a 500 Internal Server Error.
 *
 *  @see DZWebServerAsyncProcessBlock
 */
typedef void (^DZWebServerCompletionBlock)(DZWebServerResponse* _Nullable response);

/**
 *  @brief Block used to asynchronously generate an HTTP response for a fully received request.
 *
 *  Works like @c DZWebServerProcessBlock except the response can be delivered at
 *  a later time via the provided completion block, allowing for asynchronous
 *  operations (e.g. database queries, network requests) before responding.
 *
 *  @param request         The fully received request object (including body data).
 *  @param completionBlock A block that must eventually be called exactly once with a
 *                         @c DZWebServerResponse or @c nil. Passing @c nil results in
 *                         a 500 Internal Server Error. Prefer passing a
 *                         @c DZWebServerErrorResponse for more descriptive error information.
 *
 *  @warning The @p completionBlock must be called exactly once. Failing to call it
 *           will leave the connection open indefinitely.
 *
 *  @see DZWebServerProcessBlock
 */
typedef void (^DZWebServerAsyncProcessBlock)(__kindof DZWebServerRequest* request, DZWebServerCompletionBlock completionBlock);

/**
 *  @brief Block used to override the built-in logger at runtime.
 *
 *  When set via @c +setBuiltInLogger:, this block receives all log messages
 *  instead of the default stderr output.
 *
 *  @param level   The log level of the message. When using the built-in logging
 *                 facility: 0 = DEBUG, 1 = VERBOSE, 2 = INFO, 3 = WARNING, 4 = ERROR.
 *  @param message The pre-formatted log message string.
 *
 *  @note This block is only effective when the built-in logging facility is active.
 *        It has no effect if a custom logging header is specified via the
 *        @c __DZWEBSERVER_LOGGING_HEADER__ preprocessor constant.
 *
 *  @see +[DZWebServer setBuiltInLogger:]
 *  @see +[DZWebServer setLogLevel:]
 */
typedef void (^DZWebServerBuiltInLoggerBlock)(int level, NSString* message);

/**
 *  @brief Option key specifying the TCP port for the server (@c NSNumber / @c NSUInteger).
 *
 *  When set to 0, the operating system selects an available port automatically.
 *  The actual port can be retrieved from the @c port property after the server starts.
 *
 *  The default value is @c 0.
 *
 *  @see DZWebServer.port
 */
extern NSString* const DZWebServerOption_Port;

/**
 *  @brief Option key specifying the Bonjour name for service registration (@c NSString).
 *
 *  - If set to a non-empty string, that string is used as the Bonjour service name.
 *  - If set to an empty string (@c @@""), the value of
 *    @c DZWebServerOption_ServerName is used instead.
 *  - If set to @c nil (or omitted), Bonjour registration is disabled entirely.
 *
 *  The default value is @c nil (Bonjour disabled).
 *
 *  @see DZWebServerOption_ServerName
 *  @see DZWebServerOption_BonjourType
 *  @see DZWebServer.bonjourName
 */
extern NSString* const DZWebServerOption_BonjourName;

/**
 *  @brief Option key specifying Bonjour TXT record data (@c NSDictionary<NSString *, NSString *>).
 *
 *  A dictionary of key/value pairs to publish as TXT record data alongside
 *  the Bonjour service registration. TXT records allow advertising additional
 *  metadata about the service to clients on the local network.
 *
 *  The default value is @c nil (no TXT record data).
 *
 *  @note This option has no effect if Bonjour is disabled
 *        (i.e. @c DZWebServerOption_BonjourName is @c nil).
 *
 *  @see DZWebServerOption_BonjourName
 */
extern NSString* const DZWebServerOption_BonjourTXTData;

/**
 *  @brief Option key specifying the Bonjour service type (@c NSString).
 *
 *  The default value is @c @@"_http._tcp", the standard service type for HTTP
 *  web servers.
 *
 *  @note This option has no effect if Bonjour is disabled
 *        (i.e. @c DZWebServerOption_BonjourName is @c nil).
 *
 *  @see DZWebServerOption_BonjourName
 */
extern NSString* const DZWebServerOption_BonjourType;

/**
 *  @brief Option key to request a NAT port mapping via the gateway (@c NSNumber / @c BOOL).
 *
 *  When enabled, the server uses the @c DNSService API to request a port mapping
 *  in the NAT gateway, making the server reachable from outside the local network.
 *  Only IPv4 mappings are supported.
 *
 *  Use the @c publicServerURL property to retrieve the externally reachable address
 *  after the mapping is established.
 *
 *  The default value is @c NO.
 *
 *  @warning The external port set up by the NAT gateway may differ from the
 *           server's local listening port.
 *
 *  @see DZWebServer.publicServerURL
 */
extern NSString* const DZWebServerOption_RequestNATPortMapping;

/**
 *  @brief Option key to restrict the server to localhost connections only (@c NSNumber / @c BOOL).
 *
 *  When enabled, the server binds to the loopback interface (@c INADDR_LOOPBACK /
 *  @c in6addr_loopback) on both IPv4 and IPv6, rejecting connections from the
 *  outside network.
 *
 *  The default value is @c NO.
 *
 *  @warning Bonjour and NAT port mapping should be disabled when using this option,
 *           since the server will not be reachable from the outside network anyway.
 *
 *  @see DZWebServerOption_BonjourName
 *  @see DZWebServerOption_RequestNATPortMapping
 */
extern NSString* const DZWebServerOption_BindToLocalhost;

/**
 *  @brief Option key specifying the maximum pending connection backlog (@c NSNumber / @c NSUInteger).
 *
 *  Controls the @c listen() backlog parameter for both the IPv4 and IPv6
 *  listening sockets. Incoming connections exceeding this limit are dropped
 *  by the operating system.
 *
 *  The default value is @c 16.
 */
extern NSString* const DZWebServerOption_MaxPendingConnections;

/**
 *  @brief Option key specifying the value for the @c "Server" HTTP response header (@c NSString).
 *
 *  Also used as the Bonjour service name when @c DZWebServerOption_BonjourName
 *  is set to an empty string, and as the default authentication realm.
 *
 *  The default value is the class name of the server instance
 *  (e.g. @c @@"DZWebServer" or the subclass name).
 *
 *  @see DZWebServerOption_BonjourName
 *  @see DZWebServerOption_AuthenticationRealm
 */
extern NSString* const DZWebServerOption_ServerName;

/**
 *  @brief Option key specifying the HTTP authentication method (@c NSString).
 *
 *  Must be one of the @c DZWebServerAuthenticationMethod_* constants, or @c nil
 *  to disable authentication entirely.
 *
 *  The default value is @c nil (authentication disabled).
 *
 *  @see DZWebServerAuthenticationMethod_Basic
 *  @see DZWebServerAuthenticationMethod_DigestAccess
 *  @see DZWebServerOption_AuthenticationAccounts
 *  @see DZWebServerOption_AuthenticationRealm
 */
extern NSString* const DZWebServerOption_AuthenticationMethod;

/**
 *  @brief Option key specifying the HTTP authentication realm (@c NSString).
 *
 *  The realm string is sent to the client in the @c WWW-Authenticate header and
 *  is typically displayed in the browser's authentication dialog.
 *
 *  The default value is the value of @c DZWebServerOption_ServerName.
 *
 *  @note This option has no effect if @c DZWebServerOption_AuthenticationMethod
 *        is @c nil.
 *
 *  @see DZWebServerOption_AuthenticationMethod
 *  @see DZWebServerOption_ServerName
 */
extern NSString* const DZWebServerOption_AuthenticationRealm;

/**
 *  @brief Option key specifying the authentication credentials
 *         (@c NSDictionary<NSString *, NSString *>).
 *
 *  A dictionary mapping usernames to plaintext passwords. For Basic
 *  authentication, credentials are stored as Base64-encoded strings internally.
 *  For Digest Access authentication, they are stored as MD5 hashes.
 *
 *  The default value is @c nil (no accounts).
 *
 *  @note This option has no effect if @c DZWebServerOption_AuthenticationMethod
 *        is @c nil.
 *
 *  @see DZWebServerOption_AuthenticationMethod
 */
extern NSString* const DZWebServerOption_AuthenticationAccounts;

/**
 *  @brief Option key specifying the connection class to instantiate (@c Class).
 *
 *  Must be @c DZWebServerConnection or a subclass thereof. Allows customizing
 *  connection-level behavior (e.g. custom request parsing or response handling).
 *
 *  The default value is @c [DZWebServerConnection class].
 *
 *  @see DZWebServerConnection
 */
extern NSString* const DZWebServerOption_ConnectionClass;

/**
 *  @brief Option key to automatically handle HEAD requests as GET requests
 *         (@c NSNumber / @c BOOL).
 *
 *  When enabled, incoming @c HEAD requests are treated as @c GET requests
 *  internally, and the HTTP response body is automatically discarded before
 *  sending. This allows handlers to only implement @c GET and still correctly
 *  respond to @c HEAD requests per the HTTP specification.
 *
 *  The default value is @c YES.
 */
extern NSString* const DZWebServerOption_AutomaticallyMapHEADToGET;

/**
 *  @brief Option key specifying the connected-state coalescing interval in seconds
 *         (@c NSNumber / @c double).
 *
 *  After the last active connection closes, the server waits this many seconds
 *  before calling @c -webServerDidDisconnect: on the delegate. If a new connection
 *  opens within that interval, the disconnect callback is suppressed, effectively
 *  coalescing rapid connect/disconnect cycles into a single session.
 *
 *  Set to @c 0.0 or a negative value to disable coalescing (disconnect is
 *  reported immediately).
 *
 *  The default value is @c 1.0 second.
 *
 *  @see DZWebServerDelegate
 */
extern NSString* const DZWebServerOption_ConnectedStateCoalescingInterval;

/**
 *  @brief Option key specifying the GCD global queue priority for handling connections
 *         (@c NSNumber / @c long).
 *
 *  Determines the priority of the global dispatch queue on which incoming
 *  connections are accepted and processed. Must be one of the
 *  @c DISPATCH_QUEUE_PRIORITY_* constants.
 *
 *  The default value is @c DISPATCH_QUEUE_PRIORITY_DEFAULT.
 */
extern NSString* const DZWebServerOption_DispatchQueuePriority;

#if TARGET_OS_IPHONE

/**
 *  @brief Option key to automatically suspend the server when the app backgrounds
 *         (@c NSNumber / @c BOOL). iOS only.
 *
 *  When enabled, the server automatically stops its listening sockets when the
 *  iOS app enters the background and the last active connection completes. It
 *  resumes listening when the app returns to the foreground. A background task
 *  is used to keep the server alive while connections are still being served.
 *
 *  The default value is @c YES.
 *
 *  @warning While suspended, the @c running property remains @c YES but the
 *           server is not accepting new connections. The listening sockets are
 *           only re-created when the app re-enters the foreground.
 */
extern NSString* const DZWebServerOption_AutomaticallySuspendInBackground;

#endif

/**
 *  @brief Authentication method constant for HTTP Basic Authentication (RFC 2617).
 *
 *  Pass this value for the @c DZWebServerOption_AuthenticationMethod option key
 *  to enable Basic authentication.
 *
 *  @warning Credentials are transmitted as Base64-encoded plaintext. Do not use
 *           this scheme over unencrypted HTTP in production environments.
 *
 *  @see DZWebServerOption_AuthenticationMethod
 *  @see DZWebServerAuthenticationMethod_DigestAccess
 */
extern NSString* const DZWebServerAuthenticationMethod_Basic;

/**
 *  @brief Authentication method constant for HTTP Digest Access Authentication (RFC 2617).
 *
 *  Pass this value for the @c DZWebServerOption_AuthenticationMethod option key
 *  to enable Digest Access authentication. Credentials are verified using an
 *  MD5-based challenge-response mechanism, avoiding plaintext password transmission.
 *
 *  @see DZWebServerOption_AuthenticationMethod
 *  @see DZWebServerAuthenticationMethod_Basic
 */
extern NSString* const DZWebServerAuthenticationMethod_DigestAccess;

@class DZWebServer;

/**
 *  @brief Delegate protocol for receiving lifecycle and connectivity events from a DZWebServer.
 *
 *  All methods are optional and are always called on the main thread in a
 *  serialized manner.
 *
 *  @warning These methods are dispatched asynchronously to the main queue. They
 *           may fire shortly after the actual event occurs.
 */
@protocol DZWebServerDelegate <NSObject>
@optional

/**
 *  @brief Called after the server has successfully started listening for connections.
 *
 *  At this point, the @c port, @c serverURL, and @c running properties are valid.
 *
 *  @param server The server instance that started.
 */
- (void)webServerDidStart:(DZWebServer*)server;

/**
 *  @brief Called after Bonjour registration and resolution have successfully completed.
 *
 *  Use the @c bonjourServerURL property to retrieve the Bonjour address of the server.
 *  This may take up to a few seconds after the server starts.
 *
 *  @param server The server instance that completed Bonjour registration.
 *
 *  @see DZWebServer.bonjourServerURL
 */
- (void)webServerDidCompleteBonjourRegistration:(DZWebServer*)server;

/**
 *  @brief Called when the NAT port mapping has been created or updated.
 *
 *  Use the @c publicServerURL property to retrieve the externally reachable
 *  address of the server. This method is also called if the mapping fails,
 *  in which case @c publicServerURL returns @c nil.
 *
 *  @param server The server instance whose NAT mapping was updated.
 *
 *  @see DZWebServer.publicServerURL
 */
- (void)webServerDidUpdateNATPortMapping:(DZWebServer*)server;

/**
 *  @brief Called when the first connection opens, beginning a series of HTTP requests.
 *
 *  A "connected" session is considered ongoing as long as new connections keep
 *  opening. The session ends when the last connection closes (subject to the
 *  coalescing interval).
 *
 *  On iOS, a background task is automatically started when this is called from
 *  the foreground, ensuring in-flight requests complete when the app backgrounds.
 *
 *  @param server The server instance that received a connection.
 *
 *  @see DZWebServerOption_ConnectedStateCoalescingInterval
 */
- (void)webServerDidConnect:(DZWebServer*)server;

/**
 *  @brief Called when the last connection closes, ending a series of HTTP requests.
 *
 *  If @c DZWebServerOption_ConnectedStateCoalescingInterval is greater than 0,
 *  the server waits that many seconds after the last connection closes before
 *  calling this method. If a new connection opens during that interval, this
 *  callback is suppressed.
 *
 *  On iOS, the background task (if any) is ended after this callback.
 *
 *  @param server The server instance that disconnected.
 *
 *  @see DZWebServerOption_ConnectedStateCoalescingInterval
 */
- (void)webServerDidDisconnect:(DZWebServer*)server;

/**
 *  @brief Called after the server has fully stopped.
 *
 *  At this point, the listening sockets are closed and the @c running property
 *  returns @c NO.
 *
 *  @param server The server instance that stopped.
 */
- (void)webServerDidStop:(DZWebServer*)server;

@end

/**
 *  @brief A lightweight, GCD-based HTTP 1.1 server for embedding in iOS and macOS apps.
 *
 *  @c DZWebServer listens for incoming HTTP requests on a given port using both
 *  IPv4 and IPv6 sockets, then dispatches each request to a matching "handler"
 *  that generates an HTTP response. Handlers are evaluated in LIFO order
 *  (most recently added first).
 *
 *  The server supports:
 *  - Synchronous and asynchronous response generation
 *  - HTTP Basic and Digest Access authentication
 *  - Bonjour service registration and NAT port mapping
 *  - Automatic HEAD-to-GET mapping
 *  - Automatic background suspension on iOS
 *
 *  Instances can be created and used from any thread. The main thread's run loop
 *  should be running so that internal callbacks (Bonjour registration, delegate
 *  notifications, NAT port mapping) are dispatched correctly.
 *
 *  @note The server cannot be deallocated while running due to internal retain
 *        cycles with dispatch sources. Always call @c -stop before releasing.
 */
@interface DZWebServer : NSObject

/**
 *  @brief The delegate that receives server lifecycle and connectivity events.
 *
 *  Delegate methods are always called on the main thread.
 *
 *  The default value is @c nil.
 *
 *  @see DZWebServerDelegate
 */
@property(nonatomic, weak, nullable) id<DZWebServerDelegate> delegate;

/**
 *  @brief Indicates whether the server is currently running.
 *
 *  Returns @c YES after a successful call to @c -startWithOptions:error: and
 *  until @c -stop is called. On iOS, this property remains @c YES even while the
 *  server is suspended in the background (if auto-suspend is enabled), though the
 *  server is not actively accepting connections in that state.
 */
@property(nonatomic, readonly, getter=isRunning) BOOL running;

/**
 *  @brief The TCP port the server is listening on.
 *
 *  If port @c 0 was specified in the options (the default), this property returns
 *  the actual port selected by the operating system.
 *
 *  @warning This property is only valid while the server is running. Returns @c 0
 *           when the server is stopped.
 */
@property(nonatomic, readonly) NSUInteger port;

/**
 *  @brief The Bonjour service name the server registered with.
 *
 *  Returns @c nil if Bonjour is disabled or if registration has not yet completed.
 *
 *  @warning This property is only valid while the server is running and Bonjour
 *           registration has successfully completed, which can take several seconds.
 *
 *  @see DZWebServerOption_BonjourName
 */
@property(nonatomic, readonly, copy, nullable) NSString* bonjourName;

/**
 *  @brief The Bonjour service type the server registered with (e.g. @c @@"_http._tcp.").
 *
 *  Returns @c nil if Bonjour is disabled or if registration has not yet completed.
 *
 *  @warning This property is only valid while the server is running and Bonjour
 *           registration has successfully completed, which can take several seconds.
 *
 *  @see DZWebServerOption_BonjourType
 */
@property(nonatomic, readonly, copy, nullable) NSString* bonjourType;

/**
 *  @brief Creates a new server instance with no handlers or configuration.
 *
 *  The server is not started after initialization. Add handlers via the
 *  @c -addHandlerWithMatchBlock:processBlock: family of methods, then call
 *  @c -startWithOptions:error: or one of the convenience start methods.
 *
 *  @return A new @c DZWebServer instance.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 *  @brief Adds a handler with custom match logic and synchronous response generation.
 *
 *  This is the most flexible handler registration method. The match block is
 *  called for every incoming request to determine if this handler should process
 *  it. If the match block returns a non-nil request object, the process block
 *  is called to generate the response.
 *
 *  Handlers are evaluated in LIFO order: the most recently added handler that
 *  matches a request wins.
 *
 *  Internally, the synchronous process block is wrapped in an asynchronous block
 *  that calls the completion handler immediately.
 *
 *  @param matchBlock   A block that inspects the incoming request metadata and
 *                      returns a @c DZWebServerRequest instance if this handler
 *                      should process it, or @c nil to pass.
 *  @param processBlock A block that receives the fully loaded request and returns
 *                      a @c DZWebServerResponse synchronously.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *
 *  @see -addHandlerWithMatchBlock:asyncProcessBlock:
 */
- (void)addHandlerWithMatchBlock:(DZWebServerMatchBlock)matchBlock processBlock:(DZWebServerProcessBlock)processBlock;

/**
 *  @brief Adds a handler with custom match logic and asynchronous response generation.
 *
 *  The match block is called for every incoming request. If it returns a non-nil
 *  request object, the async process block is called to generate the response.
 *  The process block must eventually call its completion block exactly once.
 *
 *  Handlers are evaluated in LIFO order: the most recently added handler that
 *  matches a request wins. Internally, the handler is inserted at index 0 of
 *  the handler array.
 *
 *  @param matchBlock   A block that inspects the incoming request metadata and
 *                      returns a @c DZWebServerRequest instance if this handler
 *                      should process it, or @c nil to pass.
 *  @param processBlock A block that receives the fully loaded request and must
 *                      call the provided completion block with a response.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *
 *  @see -addHandlerWithMatchBlock:processBlock:
 */
- (void)addHandlerWithMatchBlock:(DZWebServerMatchBlock)matchBlock asyncProcessBlock:(DZWebServerAsyncProcessBlock)processBlock;

/**
 *  @brief Removes all handlers previously added to the server.
 *
 *  @warning Removing handlers while the server is running is not allowed.
 */
- (void)removeAllHandlers;

/**
 *  @brief Starts the server with the specified options.
 *
 *  This is the designated start method. It opens IPv4 and IPv6 listening sockets,
 *  configures authentication (if requested), starts Bonjour registration and NAT
 *  port mapping (if requested), and begins accepting connections.
 *
 *  On iOS, if @c DZWebServerOption_AutomaticallySuspendInBackground is @c YES
 *  (the default), the server registers for app lifecycle notifications to
 *  automatically suspend and resume.
 *
 *  @param options A dictionary of @c DZWebServerOption_* keys and their values,
 *                 or @c nil to use all defaults.
 *  @param error   On failure, set to an @c NSError describing the cause (e.g.
 *                 POSIX error from @c socket(), @c bind(), or @c listen()).
 *                 Pass @c NULL if you do not need error information.
 *
 *  @return @c YES if the server started successfully, @c NO otherwise.
 *
 *  @warning Calling this method on a server that is already running triggers a
 *           debug assertion and returns @c NO.
 *
 *  @see -stop
 */
- (BOOL)startWithOptions:(nullable NSDictionary<NSString*, id>*)options error:(NSError** _Nullable)error;

/**
 *  @brief Stops the server and prevents it from accepting new HTTP requests.
 *
 *  Closes the listening sockets, cancels Bonjour registration and NAT port
 *  mapping, and removes app lifecycle observers (on iOS). The @c port property
 *  is reset to @c 0.
 *
 *  @warning Stopping the server does not abort @c DZWebServerConnection instances
 *           currently handling in-flight HTTP requests. Those connections will
 *           continue executing until completion.
 *
 *  @warning Calling this method on a server that is not running triggers a debug
 *           assertion.
 *
 *  @see -startWithOptions:error:
 */
- (void)stop;

@end

/**
 *  @brief Convenience methods for starting the server and accessing its URLs.
 */
@interface DZWebServer (Extensions)

/**
 *  @brief The URL at which the server is reachable on the local network.
 *
 *  Constructed from the device's primary IPv4 address and the server's port.
 *  If bound to localhost, the hostname is @c "localhost".
 *
 *  Returns @c nil if the server is not running or no suitable IP address is found.
 *
 *  @warning This property is only valid while the server is running.
 */
@property(nonatomic, readonly, nullable) NSURL* serverURL;

/**
 *  @brief The URL at which the server is reachable via its Bonjour hostname.
 *
 *  Derived from the Bonjour resolution target host. The trailing period in the
 *  Bonjour domain name is stripped.
 *
 *  Returns @c nil if Bonjour is disabled, the server is not running, or Bonjour
 *  resolution has not yet completed.
 *
 *  @warning This property will not automatically update if the Bonjour hostname
 *           changes dynamically after the server started (this should be rare).
 *
 *  @see DZWebServerOption_BonjourName
 */
@property(nonatomic, readonly, nullable) NSURL* bonjourServerURL;

/**
 *  @brief The externally reachable URL via NAT port mapping.
 *
 *  Constructed from the external IP address and port reported by the NAT gateway.
 *  Returns @c nil if NAT port mapping was not requested, the server is not
 *  running, or the mapping has not been established.
 *
 *  @warning The external port may differ from the local server port.
 *
 *  @see DZWebServerOption_RequestNATPortMapping
 */
@property(nonatomic, readonly, nullable) NSURL* publicServerURL;

/**
 *  @brief Starts the server with default settings.
 *
 *  Uses port 8080 on macOS and the iOS Simulator, or port 80 on iOS devices.
 *  Bonjour is enabled with the default name (the server class name).
 *
 *  @return @c YES if the server started successfully, @c NO otherwise.
 *
 *  @see -startWithPort:bonjourName:
 *  @see -startWithOptions:error:
 */
- (BOOL)start;

/**
 *  @brief Starts the server on a specific port with a given Bonjour name.
 *
 *  @param port The TCP port to listen on.
 *  @param name The Bonjour service name. Pass @c nil to disable Bonjour, or
 *              an empty string to use the default name (the server class name).
 *
 *  @return @c YES if the server started successfully, @c NO otherwise.
 *
 *  @see -startWithOptions:error:
 */
- (BOOL)startWithPort:(NSUInteger)port bonjourName:(nullable NSString*)name;

#if !TARGET_OS_IPHONE

/**
 *  @brief Runs the server synchronously until a SIGINT or SIGTERM signal is received.
 *
 *  Convenience wrapper that calls @c -startWithPort:bonjourName: and then blocks
 *  on the main run loop until Ctrl-C (or a termination signal) is sent. Intended
 *  for command-line tools.
 *
 *  @param port The TCP port to listen on.
 *  @param name The Bonjour service name. Pass @c nil to disable Bonjour, or
 *              an empty string to use the default name.
 *
 *  @return @c YES if the server ran and was stopped by a signal. @c NO if the
 *          server failed to start.
 *
 *  @warning This method must be called from the main thread only.
 *
 *  @see -runWithOptions:error:
 */
- (BOOL)runWithPort:(NSUInteger)port bonjourName:(nullable NSString*)name;

/**
 *  @brief Runs the server synchronously with full options until a SIGINT or SIGTERM
 *         signal is received.
 *
 *  Convenience wrapper that calls @c -startWithOptions:error: and then blocks on
 *  the main run loop until a termination signal is sent. Main thread run loop
 *  sources are drained after stopping to ensure all pending callbacks execute.
 *  Intended for command-line tools.
 *
 *  @param options A dictionary of @c DZWebServerOption_* keys, or @c nil for defaults.
 *  @param error   On failure, set to an @c NSError describing the cause. Pass @c NULL
 *                 if you do not need error information.
 *
 *  @return @c YES if the server ran and was stopped by a signal. @c NO if the
 *          server failed to start.
 *
 *  @warning This method must be called from the main thread only.
 *
 *  @see -startWithOptions:error:
 */
- (BOOL)runWithOptions:(nullable NSDictionary<NSString*, id>*)options error:(NSError** _Nullable)error;

#endif

@end

/**
 *  @brief Convenience methods for adding common handler patterns (by method, path, or regex).
 */
@interface DZWebServer (Handlers)

/**
 *  @brief Adds a catch-all handler for a given HTTP method with synchronous response generation.
 *
 *  Matches any request whose HTTP method equals @p method, regardless of the
 *  URL path. Useful as a fallback handler for a specific method.
 *
 *  @param method The HTTP method to match (e.g. @c @@"GET", @c @@"POST").
 *  @param aClass The @c DZWebServerRequest subclass to instantiate for matched
 *                requests (e.g. @c [DZWebServerDataRequest class]).
 *  @param block  A block that receives the fully loaded request and returns a
 *                response synchronously.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 */
- (void)addDefaultHandlerForMethod:(NSString*)method requestClass:(Class)aClass processBlock:(DZWebServerProcessBlock)block;

/**
 *  @brief Adds a catch-all handler for a given HTTP method with asynchronous response generation.
 *
 *  Matches any request whose HTTP method equals @p method, regardless of the
 *  URL path.
 *
 *  @param method The HTTP method to match (e.g. @c @@"GET", @c @@"POST").
 *  @param aClass The @c DZWebServerRequest subclass to instantiate for matched
 *                requests.
 *  @param block  A block that receives the fully loaded request and must call
 *                its completion block with a response.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 */
- (void)addDefaultHandlerForMethod:(NSString*)method requestClass:(Class)aClass asyncProcessBlock:(DZWebServerAsyncProcessBlock)block;

/**
 *  @brief Adds a handler for a specific HTTP method and exact path with synchronous
 *         response generation.
 *
 *  The path is compared case-insensitively. Only requests whose method and path
 *  both match will be handled.
 *
 *  @param method The HTTP method to match (e.g. @c @@"GET", @c @@"POST").
 *  @param path   The URL path to match (must start with @c @@"/"). Compared
 *                case-insensitively.
 *  @param aClass The @c DZWebServerRequest subclass to instantiate for matched
 *                requests.
 *  @param block  A block that receives the fully loaded request and returns a
 *                response synchronously.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *  @warning The @p path must start with @c @@"/" and @p aClass must be a subclass
 *           of @c DZWebServerRequest, or a debug assertion is triggered.
 */
- (void)addHandlerForMethod:(NSString*)method path:(NSString*)path requestClass:(Class)aClass processBlock:(DZWebServerProcessBlock)block;

/**
 *  @brief Adds a handler for a specific HTTP method and exact path with asynchronous
 *         response generation.
 *
 *  The path is compared case-insensitively. Only requests whose method and path
 *  both match will be handled.
 *
 *  @param method The HTTP method to match (e.g. @c @@"GET", @c @@"POST").
 *  @param path   The URL path to match (must start with @c @@"/"). Compared
 *                case-insensitively.
 *  @param aClass The @c DZWebServerRequest subclass to instantiate for matched
 *                requests.
 *  @param block  A block that receives the fully loaded request and must call
 *                its completion block with a response.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *  @warning The @p path must start with @c @@"/" and @p aClass must be a subclass
 *           of @c DZWebServerRequest, or a debug assertion is triggered.
 */
- (void)addHandlerForMethod:(NSString*)method path:(NSString*)path requestClass:(Class)aClass asyncProcessBlock:(DZWebServerAsyncProcessBlock)block;

/**
 *  @brief Adds a handler for a specific HTTP method and a path matching a regular
 *         expression, with synchronous response generation.
 *
 *  The regex is compiled with @c NSRegularExpressionCaseInsensitive. Capture groups
 *  in the regex are extracted and stored as an @c NSArray<NSString *> in the
 *  request's attributes under the key @c DZWebServerRequestAttribute_RegexCaptures.
 *
 *  @param method The HTTP method to match (e.g. @c @@"GET", @c @@"POST").
 *  @param regex  A regular expression pattern to match against the URL path.
 *  @param aClass The @c DZWebServerRequest subclass to instantiate for matched
 *                requests.
 *  @param block  A block that receives the fully loaded request and returns a
 *                response synchronously.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *  @warning The @p regex must be a valid @c NSRegularExpression pattern and
 *           @p aClass must be a subclass of @c DZWebServerRequest, or a debug
 *           assertion is triggered.
 */
- (void)addHandlerForMethod:(NSString*)method pathRegex:(NSString*)regex requestClass:(Class)aClass processBlock:(DZWebServerProcessBlock)block;

/**
 *  @brief Adds a handler for a specific HTTP method and a path matching a regular
 *         expression, with asynchronous response generation.
 *
 *  The regex is compiled with @c NSRegularExpressionCaseInsensitive. Capture groups
 *  in the regex are extracted and stored as an @c NSArray<NSString *> in the
 *  request's attributes under the key @c DZWebServerRequestAttribute_RegexCaptures.
 *
 *  @param method The HTTP method to match (e.g. @c @@"GET", @c @@"POST").
 *  @param regex  A regular expression pattern to match against the URL path.
 *  @param aClass The @c DZWebServerRequest subclass to instantiate for matched
 *                requests.
 *  @param block  A block that receives the fully loaded request and must call
 *                its completion block with a response.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *  @warning The @p regex must be a valid @c NSRegularExpression pattern and
 *           @p aClass must be a subclass of @c DZWebServerRequest, or a debug
 *           assertion is triggered.
 */
- (void)addHandlerForMethod:(NSString*)method pathRegex:(NSString*)regex requestClass:(Class)aClass asyncProcessBlock:(DZWebServerAsyncProcessBlock)block;

@end

/**
 *  @brief High-level convenience methods for serving static content via GET requests.
 */
@interface DZWebServer (GETHandlers)

/**
 *  @brief Adds a GET handler that serves in-memory data at a specific path.
 *
 *  Responds to @c GET requests matching the given path (case-insensitive) with
 *  the provided static data. The response includes a @c Cache-Control header
 *  with the specified max-age.
 *
 *  @param path        The URL path to match (must start with @c @@"/").
 *  @param staticData  The data to serve as the response body.
 *  @param contentType The MIME type for the @c Content-Type header, or @c nil.
 *  @param cacheAge    The @c Cache-Control max-age value in seconds. Pass @c 0
 *                     to disable caching.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 */
- (void)addGETHandlerForPath:(NSString*)path staticData:(NSData*)staticData contentType:(nullable NSString*)contentType cacheAge:(NSUInteger)cacheAge;

/**
 *  @brief Adds a GET handler that serves a file at a specific path.
 *
 *  Responds to @c GET requests matching the given path (case-insensitive) with
 *  the contents of the specified file. When range requests are enabled, the
 *  @c Accept-Ranges: bytes header is included and partial content responses
 *  (HTTP 206) are supported.
 *
 *  @param path               The URL path to match (must start with @c @@"/").
 *  @param filePath           The absolute file system path to the file to serve.
 *  @param isAttachment       If @c YES, the response includes a
 *                            @c Content-Disposition: attachment header, prompting
 *                            the client to download rather than display inline.
 *  @param cacheAge           The @c Cache-Control max-age value in seconds. Pass
 *                            @c 0 to disable caching.
 *  @param allowRangeRequests If @c YES, the handler honors @c Range headers and
 *                            serves partial content.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 */
- (void)addGETHandlerForPath:(NSString*)path filePath:(NSString*)filePath isAttachment:(BOOL)isAttachment cacheAge:(NSUInteger)cacheAge allowRangeRequests:(BOOL)allowRangeRequests;

/**
 *  @brief Adds a GET handler that serves a local directory under a base URL path.
 *
 *  Responds to @c GET requests whose path begins with @p basePath by mapping the
 *  remaining path components to files inside @p directoryPath. If the resolved
 *  path is a directory and @p indexFilename is specified, the handler looks for
 *  that index file within the directory. If no matching file or directory is
 *  found, a 404 Not Found response is returned.
 *
 *  When a directory is requested and no index file is found (or none was
 *  specified), an auto-generated HTML directory listing is returned.
 *
 *  @param basePath           The URL base path (must start and end with @c @@"/",
 *                            e.g. @c @@"/files/").
 *  @param directoryPath      The absolute file system path to the directory to serve.
 *  @param indexFilename      The filename to use as a directory index
 *                            (e.g. @c @@"index.html"), or @c nil to serve a
 *                            generated directory listing.
 *  @param cacheAge           The @c Cache-Control max-age value in seconds. Pass
 *                            @c 0 to disable caching.
 *  @param allowRangeRequests If @c YES, file responses honor @c Range headers and
 *                            serve partial content.
 *
 *  @warning Adding handlers while the server is running is not allowed.
 *  @warning The @p basePath must start and end with @c @@"/", or a debug assertion
 *           is triggered.
 */
- (void)addGETHandlerForBasePath:(NSString*)basePath directoryPath:(NSString*)directoryPath indexFilename:(nullable NSString*)indexFilename cacheAge:(NSUInteger)cacheAge allowRangeRequests:(BOOL)allowRangeRequests;

@end

/**
 *  @brief Logging configuration and convenience methods.
 *
 *  @c DZWebServer provides a built-in logging facility that sends messages to
 *  @c stderr when connected to a terminal device. The default log level is
 *  @c INFO (or @c DEBUG when the @c DEBUG preprocessor constant evaluates to
 *  non-zero at compile time).
 *
 *  @discussion
 *  The logging backend is selected at compile time in the following priority order:
 *
 *  1. **Custom header**: Define @c __DZWEBSERVER_LOGGING_HEADER__ as a quoted header
 *     file name (e.g. @c \\"MyLogging.h\\") in your build settings. This header must
 *     define the macros @c DWS_LOG_DEBUG, @c DWS_LOG_VERBOSE, @c DWS_LOG_INFO,
 *     @c DWS_LOG_WARNING, and @c DWS_LOG_ERROR (with @c NSLog()-compatible signatures).
 *     @c DWS_LOG_DEBUG should be a no-op unless @c DEBUG is non-zero.
 *
 *  2. **XLFacility**: If @c XLFacilityMacros.h is available at compile time,
 *     it is used automatically.
 *
 *  3. **Built-in logger**: Logs to @c stderr in @c [LEVEL] message format. Can be
 *     overridden at runtime via @c +setBuiltInLogger:.
 *
 *  The instance logging methods below forward to the active logging facility and
 *  can be used in handler implementations for consistent log output.
 */
@interface DZWebServer (Logging)

/**
 *  @brief Sets the minimum log level; messages below this level are discarded.
 *
 *  For the built-in logging facility, the levels are:
 *  - @c 0 = DEBUG
 *  - @c 1 = VERBOSE
 *  - @c 2 = INFO (default in Release)
 *  - @c 3 = WARNING
 *  - @c 4 = ERROR
 *
 *  The default level is @c 0 (DEBUG) when @c DEBUG is defined, or @c 2 (INFO) otherwise.
 *
 *  @param level The minimum log level to display.
 *
 *  @warning The interpretation of @p level depends on the logging facility active
 *           at compile time. When using XLFacility, this sets
 *           @c XLSharedFacility.minLogLevel. When using a custom logging header,
 *           this method has no effect.
 */
+ (void)setLogLevel:(int)level;

/**
 *  @brief Replaces the built-in stderr logger with a custom block.
 *
 *  When set, all log messages that would normally be written to @c stderr are
 *  instead passed to the provided block. Pass @c nil to restore the default
 *  stderr output.
 *
 *  @param block A block that receives the log level and pre-formatted message,
 *               or @c nil to restore the default logger.
 *
 *  @warning This method only works when the built-in logging facility is active.
 *           If a custom logging header is specified via @c __DZWEBSERVER_LOGGING_HEADER__
 *           or if XLFacility is detected at compile time, this method triggers a
 *           debug assertion and has no effect.
 *
 *  @see DZWebServerBuiltInLoggerBlock
 */
+ (void)setBuiltInLogger:(nullable DZWebServerBuiltInLoggerBlock)block;

/**
 *  @brief Logs a formatted message at the VERBOSE level (level 1).
 *
 *  @param format A format string followed by a variable number of arguments.
 *
 *  @note Not available in Swift. Use @c logVerbose(_:) instead.
 */
- (void)logVerbose:(NSString*)format, ... NS_FORMAT_FUNCTION(1, 2) NS_SWIFT_UNAVAILABLE("Use logVerbose(_:) instead");

/**
 *  @brief Logs a pre-formatted message at the VERBOSE level (level 1).
 *
 *  Swift-friendly alternative to @c -logVerbose: that accepts a single
 *  pre-formatted string instead of a variadic format string.
 *
 *  @param message The message to log.
 */
- (void)logVerboseMessage:(NSString*)message NS_SWIFT_NAME(logVerbose(_:));

/**
 *  @brief Logs a formatted message at the INFO level (level 2).
 *
 *  @param format A format string followed by a variable number of arguments.
 *
 *  @note Not available in Swift. Use @c logInfo(_:) instead.
 */
- (void)logInfo:(NSString*)format, ... NS_FORMAT_FUNCTION(1, 2) NS_SWIFT_UNAVAILABLE("Use logInfo(_:) instead");

/**
 *  @brief Logs a pre-formatted message at the INFO level (level 2).
 *
 *  Swift-friendly alternative to @c -logInfo: that accepts a single
 *  pre-formatted string instead of a variadic format string.
 *
 *  @param message The message to log.
 */
- (void)logInfoMessage:(NSString*)message NS_SWIFT_NAME(logInfo(_:));

/**
 *  @brief Logs a formatted message at the WARNING level (level 3).
 *
 *  @param format A format string followed by a variable number of arguments.
 *
 *  @note Not available in Swift. Use @c logWarning(_:) instead.
 */
- (void)logWarning:(NSString*)format, ... NS_FORMAT_FUNCTION(1, 2) NS_SWIFT_UNAVAILABLE("Use logWarning(_:) instead");

/**
 *  @brief Logs a pre-formatted message at the WARNING level (level 3).
 *
 *  Swift-friendly alternative to @c -logWarning: that accepts a single
 *  pre-formatted string instead of a variadic format string.
 *
 *  @param message The message to log.
 */
- (void)logWarningMessage:(NSString*)message NS_SWIFT_NAME(logWarning(_:));

/**
 *  @brief Logs a formatted message at the ERROR level (level 4).
 *
 *  @param format A format string followed by a variable number of arguments.
 *
 *  @note Not available in Swift. Use @c logError(_:) instead.
 */
- (void)logError:(NSString*)format, ... NS_FORMAT_FUNCTION(1, 2) NS_SWIFT_UNAVAILABLE("Use logError(_:) instead");

/**
 *  @brief Logs a pre-formatted message at the ERROR level (level 4).
 *
 *  Swift-friendly alternative to @c -logError: that accepts a single
 *  pre-formatted string instead of a variadic format string.
 *
 *  @param message The message to log.
 */
- (void)logErrorMessage:(NSString*)message NS_SWIFT_NAME(logError(_:));

@end

#ifdef __DZWEBSERVER_ENABLE_TESTING__

/**
 *  @brief Recording and playback testing support.
 *
 *  Available only when @c __DZWEBSERVER_ENABLE_TESTING__ is defined at compile time.
 *  Provides methods to record raw HTTP traffic and replay it for automated
 *  regression testing.
 */
@interface DZWebServer (Testing)

/**
 *  @brief Controls whether HTTP request/response recording is active.
 *
 *  When enabled, raw data for all incoming HTTP requests and outgoing responses
 *  is written to files in the current working directory. These files can later
 *  be used with @c -runTestsWithOptions:inDirectory: for regression testing.
 *
 *  The default value is @c NO.
 *
 *  @warning The current working directory must not contain any prior recording
 *           files when enabling recording.
 */
@property(nonatomic, getter=isRecordingEnabled) BOOL recordingEnabled;

/**
 *  @brief Replays pre-recorded HTTP requests and validates the server's responses.
 *
 *  Starts the server with the given options, then reads @c .request files from
 *  the specified directory (sorted by name), sends them to the server, and
 *  compares the actual responses against corresponding @c .response files.
 *  Status codes, headers (except @c Date and @c Etag), and bodies are compared.
 *
 *  @param options A dictionary of @c DZWebServerOption_* keys, or @c nil for defaults.
 *  @param path    The directory containing pre-recorded @c .request and @c .response files.
 *
 *  @return The number of failed tests, or @c -1 if the server failed to start.
 *
 *  @warning This method must be called from the main thread only.
 */
- (NSInteger)runTestsWithOptions:(nullable NSDictionary<NSString*, id>*)options inDirectory:(NSString*)path;

@end

#endif

NS_ASSUME_NONNULL_END
