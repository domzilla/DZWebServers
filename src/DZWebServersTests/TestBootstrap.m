//
//  TestBootstrap.m
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

@import DZWebServers;

/// Forces DZWebServer +initialize to run on the main thread at module-load
/// time, before any Swift Testing tests execute.
///
/// DZWebServerInitializeFunctions() asserts [NSThread isMainThread] in
/// DEBUG builds (via DWS_DCHECK). Since Swift Testing runs tests on
/// background threads, the first DZWebServer allocation inside a test
/// would trigger +initialize on a background thread, hitting the
/// assertion and calling abort().
///
/// By referencing the DZWebServer class and its subclasses inside +load
/// (which the ObjC runtime always dispatches on the main thread during
/// binary loading), we guarantee that +initialize fires on the main
/// thread before the test runner reaches any test case.
///
/// Note: The ObjC runtime calls +initialize once *per class*. If a
/// subclass does not override +initialize, the superclass implementation
/// is invoked again for that subclass. So we must reference every
/// DZWebServer subclass here to avoid a deferred +initialize call on a
/// background thread later.
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
