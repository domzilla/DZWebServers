//
//  TestSetup.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation

/// DZWebServerInitializeFunctions() must run on the main thread (DWS_DCHECK in DEBUG), but Swift
/// Testing runs tests on background threads, so the first DZWebServer allocation is dispatched to main.
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

    /// Call from each `@Suite` struct's `init()`; safe from any thread and repeatedly.
    static func ensureInitialized() {
        _ = self.initialized
    }
}
