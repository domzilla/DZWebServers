//
//  TestSetup.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation

/// Ensures the DZWebServers framework's internal dispatch queues and date
/// formatters are initialized before any test runs.
///
/// The framework requires `DZWebServerInitializeFunctions()` to be called on
/// the main thread (enforced by `DWS_DCHECK` in DEBUG builds). Since Swift
/// Testing runs tests on background threads, we must dispatch the first
/// `DZWebServer` allocation to the main queue so that `+initialize` (which
/// calls `DZWebServerInitializeFunctions()`) executes on the main thread.
enum DZWebServerTestSetup {
    private static let initialized: Bool = {
        if Thread.isMainThread {
            _ = DZWebServer()
        } else {
            DispatchQueue.main.sync {
                _ = DZWebServer()
            }
        }
        return true
    }()

    /// Call from each `@Suite` struct's `init()` to guarantee framework
    /// readiness. Safe to call from any thread and multiple times — the
    /// actual initialization runs only once.
    static func ensureInitialized() {
        _ = self.initialized
    }
}
