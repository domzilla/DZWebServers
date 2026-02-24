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

#import <os/object.h>
#import <sys/socket.h>

/**
 *  All DZWebServer headers.
 */

#import "DZWebServerHTTPStatusCodes.h"
#import "DZWebServerFunctions.h"

#import "DZWebServer.h"
#import "DZWebServerConnection.h"

#import "DZWebServerDataRequest.h"
#import "DZWebServerFileRequest.h"
#import "DZWebServerMultiPartFormRequest.h"
#import "DZWebServerURLEncodedFormRequest.h"

#import "DZWebServerDataResponse.h"
#import "DZWebServerErrorResponse.h"
#import "DZWebServerFileResponse.h"
#import "DZWebServerStreamedResponse.h"

/**
 *  Check if a custom logging facility should be used instead.
 */

#if defined(__DZWEBSERVER_LOGGING_HEADER__)

#define __DZWEBSERVER_LOGGING_FACILITY_CUSTOM__

#import __DZWEBSERVER_LOGGING_HEADER__

/**
 *  Automatically detect if XLFacility is available and if so use it as a
 *  logging facility.
 */

#elif defined(__has_include) && __has_include("XLFacilityMacros.h")

#define __DZWEBSERVER_LOGGING_FACILITY_XLFACILITY__

#undef XLOG_TAG
#define XLOG_TAG @"gcdwebserver.internal"

#import "XLFacilityMacros.h"

#define GWS_LOG_DEBUG(...) XLOG_DEBUG(__VA_ARGS__)
#define GWS_LOG_VERBOSE(...) XLOG_VERBOSE(__VA_ARGS__)
#define GWS_LOG_INFO(...) XLOG_INFO(__VA_ARGS__)
#define GWS_LOG_WARNING(...) XLOG_WARNING(__VA_ARGS__)
#define GWS_LOG_ERROR(...) XLOG_ERROR(__VA_ARGS__)

#define GWS_DCHECK(__CONDITION__) XLOG_DEBUG_CHECK(__CONDITION__)
#define GWS_DNOT_REACHED() XLOG_DEBUG_UNREACHABLE()

/**
 *  If all of the above fail, then use DZWebServer built-in
 *  logging facility.
 */

#else

#define __DZWEBSERVER_LOGGING_FACILITY_BUILTIN__

typedef NS_ENUM(int, DZWebServerLoggingLevel) {
  kDZWebServerLoggingLevel_Debug = 0,
  kDZWebServerLoggingLevel_Verbose,
  kDZWebServerLoggingLevel_Info,
  kDZWebServerLoggingLevel_Warning,
  kDZWebServerLoggingLevel_Error
};

extern DZWebServerLoggingLevel DZWebServerLogLevel;
extern void DZWebServerLogMessage(DZWebServerLoggingLevel level, NSString* _Nonnull format, ...) NS_FORMAT_FUNCTION(2, 3);

#if DEBUG
#define GWS_LOG_DEBUG(...)                                                                                                             \
  do {                                                                                                                                 \
    if (DZWebServerLogLevel <= kDZWebServerLoggingLevel_Debug) DZWebServerLogMessage(kDZWebServerLoggingLevel_Debug, __VA_ARGS__); \
  } while (0)
#else
#define GWS_LOG_DEBUG(...)
#endif
#define GWS_LOG_VERBOSE(...)                                                                                                               \
  do {                                                                                                                                     \
    if (DZWebServerLogLevel <= kDZWebServerLoggingLevel_Verbose) DZWebServerLogMessage(kDZWebServerLoggingLevel_Verbose, __VA_ARGS__); \
  } while (0)
#define GWS_LOG_INFO(...)                                                                                                            \
  do {                                                                                                                               \
    if (DZWebServerLogLevel <= kDZWebServerLoggingLevel_Info) DZWebServerLogMessage(kDZWebServerLoggingLevel_Info, __VA_ARGS__); \
  } while (0)
#define GWS_LOG_WARNING(...)                                                                                                               \
  do {                                                                                                                                     \
    if (DZWebServerLogLevel <= kDZWebServerLoggingLevel_Warning) DZWebServerLogMessage(kDZWebServerLoggingLevel_Warning, __VA_ARGS__); \
  } while (0)
#define GWS_LOG_ERROR(...)                                                                                                             \
  do {                                                                                                                                 \
    if (DZWebServerLogLevel <= kDZWebServerLoggingLevel_Error) DZWebServerLogMessage(kDZWebServerLoggingLevel_Error, __VA_ARGS__); \
  } while (0)

#endif

/**
 *  Consistency check macros used when building Debug only.
 */

#if !defined(GWS_DCHECK) || !defined(GWS_DNOT_REACHED)

#if DEBUG

#define GWS_DCHECK(__CONDITION__) \
  do {                            \
    if (!(__CONDITION__)) {       \
      abort();                    \
    }                             \
  } while (0)
#define GWS_DNOT_REACHED() abort()

#else

#define GWS_DCHECK(__CONDITION__)
#define GWS_DNOT_REACHED()

#endif

#endif

NS_ASSUME_NONNULL_BEGIN

/**
 *  DZWebServer internal constants and APIs.
 */

#define kDZWebServerDefaultMimeType @"application/octet-stream"
#define kDZWebServerErrorDomain @"DZWebServerErrorDomain"

static inline BOOL DZWebServerIsValidByteRange(NSRange range) {
  return ((range.location != NSUIntegerMax) || (range.length > 0));
}

static inline NSError* DZWebServerMakePosixError(int code) {
  return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : (NSString*)[NSString stringWithUTF8String:strerror(code)]}];
}

extern void DZWebServerInitializeFunctions(void);
extern NSString* _Nullable DZWebServerNormalizeHeaderValue(NSString* _Nullable value);
extern NSString* _Nullable DZWebServerTruncateHeaderValue(NSString* _Nullable value);
extern NSString* _Nullable DZWebServerExtractHeaderValueParameter(NSString* _Nullable value, NSString* attribute);
extern NSStringEncoding DZWebServerStringEncodingFromCharset(NSString* charset);
extern BOOL DZWebServerIsTextContentType(NSString* type);
extern NSString* DZWebServerDescribeData(NSData* data, NSString* contentType);
extern NSString* DZWebServerComputeMD5Digest(NSString* format, ...) NS_FORMAT_FUNCTION(1, 2);
extern NSString* DZWebServerStringFromSockAddr(const struct sockaddr* addr, BOOL includeService);

@interface DZWebServerConnection ()
- (instancetype)initWithServer:(DZWebServer*)server localAddress:(NSData*)localAddress remoteAddress:(NSData*)remoteAddress socket:(CFSocketNativeHandle)socket;
@end

@interface DZWebServer ()
@property(nonatomic, readonly) NSMutableArray<DZWebServerHandler*>* handlers;
@property(nonatomic, readonly, nullable) NSString* serverName;
@property(nonatomic, readonly, nullable) NSString* authenticationRealm;
@property(nonatomic, readonly, nullable) NSMutableDictionary<NSString*, NSString*>* authenticationBasicAccounts;
@property(nonatomic, readonly, nullable) NSMutableDictionary<NSString*, NSString*>* authenticationDigestAccounts;
@property(nonatomic, readonly) BOOL shouldAutomaticallyMapHEADToGET;
@property(nonatomic, readonly) dispatch_queue_priority_t dispatchQueuePriority;
- (void)willStartConnection:(DZWebServerConnection*)connection;
- (void)didEndConnection:(DZWebServerConnection*)connection;
@end

@interface DZWebServerHandler : NSObject
@property(nonatomic, readonly) DZWebServerMatchBlock matchBlock;
@property(nonatomic, readonly) DZWebServerAsyncProcessBlock asyncProcessBlock;
@end

@interface DZWebServerRequest ()
@property(nonatomic, readonly) BOOL usesChunkedTransferEncoding;
@property(nonatomic) NSData* localAddressData;
@property(nonatomic) NSData* remoteAddressData;
- (void)prepareForWriting;
- (BOOL)performOpen:(NSError**)error;
- (BOOL)performWriteData:(NSData*)data error:(NSError**)error;
- (BOOL)performClose:(NSError**)error;
- (void)setAttribute:(nullable id)attribute forKey:(NSString*)key;
@end

@interface DZWebServerResponse ()
@property(nonatomic, readonly) NSDictionary<NSString*, NSString*>* additionalHeaders;
@property(nonatomic, readonly) BOOL usesChunkedTransferEncoding;
- (void)prepareForReading;
- (BOOL)performOpen:(NSError**)error;
- (void)performReadDataWithCompletion:(DZWebServerBodyReaderCompletionBlock)block;
- (void)performClose;
@end

NS_ASSUME_NONNULL_END
