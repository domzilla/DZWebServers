//
//  TestBootstrap.m
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

@import DZWebServers;

// Forces DZWebServer +initialize onto the main thread via +load: it asserts isMainThread in DEBUG,
// but Swift Testing runs tests on background threads. +initialize runs once per class, so every
// subclass must be referenced here.
@interface DZTestBootstrap : NSObject
@end

@implementation DZTestBootstrap

+ (void)load
{
    // Trigger +initialize for DZWebServer and all subclasses on the
    // main thread.  After this, no further +initialize calls will
    // occur for these classes.
    [DZWebServer class];
    [DZWebDAVServer class];
    [DZWebUploader class];
}

@end
