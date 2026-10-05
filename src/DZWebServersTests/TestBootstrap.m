//
//  TestBootstrap.m
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

@import DZWebServers;

// DZWebServer's +initialize asserts isMainThread in DEBUG, but Swift Testing runs tests on background
// threads. +load runs on the main thread at bundle load, before any test. +initialize runs once per
// class, so every subclass must be referenced here.
@interface DZTestBootstrap : NSObject
@end

@implementation DZTestBootstrap

+ (void)load
{
    [DZWebServer class];
    [DZWebDAVServer class];
    [DZWebUploader class];
}

@end
