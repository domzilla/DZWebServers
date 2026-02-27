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

#if !__has_feature(objc_arc)
#error DZWebServer requires ARC
#endif

#import "DZWebServerPrivate.h"

@implementation DZWebServerErrorResponse

#pragma mark Public (Factory — Swift-friendly)
#pragma mark ---

+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message {
  return [(DZWebServerErrorResponse*)[self alloc] initWithClientError:errorCode formattedMessage:message];
}

+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message {
  return [(DZWebServerErrorResponse*)[self alloc] initWithServerError:errorCode formattedMessage:message];
}

+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError formattedMessage:(NSString*)message {
  return [(DZWebServerErrorResponse*)[self alloc] initWithClientError:errorCode underlyingError:underlyingError formattedMessage:message];
}

+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError formattedMessage:(NSString*)message {
  return [(DZWebServerErrorResponse*)[self alloc] initWithServerError:errorCode underlyingError:underlyingError formattedMessage:message];
}

#pragma mark Public (Factory — Variadic)
#pragma mark ---

+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self responseWithClientError:errorCode formattedMessage:message];
}

+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self responseWithServerError:errorCode formattedMessage:message];
}

+ (instancetype)responseWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self responseWithClientError:errorCode underlyingError:underlyingError formattedMessage:message];
}

+ (instancetype)responseWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self responseWithServerError:errorCode underlyingError:underlyingError formattedMessage:message];
}

#pragma mark Public (Init — Swift-friendly)
#pragma mark ---

static inline NSString* _EscapeHTMLString(NSString* string) {
  return [string stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode underlyingError:(NSError*)underlyingError formattedMessage:(NSString*)message {
  NSString* title = [NSString stringWithFormat:@"HTTP Error %i", (int)statusCode];
  NSString* error = underlyingError ? [NSString stringWithFormat:@"[%@] %@ (%li)", underlyingError.domain, _EscapeHTMLString(underlyingError.localizedDescription), (long)underlyingError.code] : @"";
  NSString* html = [NSString stringWithFormat:@"<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>%@</title></head><body><h1>%@: %@</h1><h3>%@</h3></body></html>",
                                              title, title, _EscapeHTMLString(message), error];
  if ((self = [self initWithHTML:html])) {
    self.statusCode = statusCode;
  }
  return self;
}

- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message {
  DWS_DCHECK(((NSInteger)errorCode >= 400) && ((NSInteger)errorCode < 500));
  return [self initWithStatusCode:errorCode underlyingError:nil formattedMessage:message];
}

- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode formattedMessage:(NSString*)message {
  DWS_DCHECK(((NSInteger)errorCode >= 500) && ((NSInteger)errorCode < 600));
  return [self initWithStatusCode:errorCode underlyingError:nil formattedMessage:message];
}

- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError formattedMessage:(NSString*)message {
  DWS_DCHECK(((NSInteger)errorCode >= 400) && ((NSInteger)errorCode < 500));
  return [self initWithStatusCode:errorCode underlyingError:underlyingError formattedMessage:message];
}

- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError formattedMessage:(NSString*)message {
  DWS_DCHECK(((NSInteger)errorCode >= 500) && ((NSInteger)errorCode < 600));
  return [self initWithStatusCode:errorCode underlyingError:underlyingError formattedMessage:message];
}

#pragma mark Public (Init — Variadic)
#pragma mark ---

- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self initWithClientError:errorCode formattedMessage:message];
}

- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self initWithServerError:errorCode formattedMessage:message];
}

- (instancetype)initWithClientError:(DZWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self initWithClientError:errorCode underlyingError:underlyingError formattedMessage:message];
}

- (instancetype)initWithServerError:(DZWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  return [self initWithServerError:errorCode underlyingError:underlyingError formattedMessage:message];
}

@end
