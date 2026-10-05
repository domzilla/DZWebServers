# DZWebServers - AGENTS.md

## Project Overview
Lightweight, GCD-based HTTP 1.1 server framework for embedding in iOS and macOS apps. Based on GCDWebServer by Pierre-Olivier Latour. Provides a 4-core architecture (server, connection, request, response) with built-in WebDAV and file uploader extensions. Pure Objective-C, no third-party dependencies.

## Tech Stack
- **Language**: Objective-C
- **Type**: Xcode Framework
- **Target-Platforms**: iOS / macOS

## Guides (MANDATORY)
- Objective-C style: `~/Agents/Style/objc-style-guide.md`
- Swift style: `~/Agents/Style/swift-swiftui-style-guide.md`
- Accessibility: `~/Agents/Guides/accessibility-guide.md`
- Xcode projects: `~/Agents/Guides/xcode-project-guide.md`

## Framework Dependencies
None. This framework depends only on Foundation and CoreServices (system frameworks).

## Logging (MANDATORY)
This framework uses its own built-in logging system via macros defined in `DZWebServerPrivate.h`.

```objc
DWS_LOG_DEBUG(@"...");    // Debug only (stripped in release)
DWS_LOG_VERBOSE(@"...");  // Verbose
DWS_LOG_INFO(@"...");     // Info
DWS_LOG_WARNING(@"...");  // Warning
DWS_LOG_ERROR(@"...");    // Error
```

Custom logging headers can be injected via `__DZWEBSERVER_LOGGING_HEADER__`. XLFacility is auto-detected if available.

**Do NOT use:**
- `print()` / `NSLog()` for debug output
- `os.Logger` instances

## Build Commands
```bash
# Build (iOS)
xcodebuild -project src/DZWebServers.xcodeproj -scheme DZWebServers \
  -destination 'generic/platform=iOS' \
  -configuration Debug build

# Build (macOS)
xcodebuild -project src/DZWebServers.xcodeproj -scheme DZWebServers \
  -destination 'generic/platform=macOS' \
  -configuration Debug build

# Clean
xcodebuild -project src/DZWebServers.xcodeproj -scheme DZWebServers clean
```

## Testing (MANDATORY)
**Run tests after every code change:**
```bash
xcodebuild test -project src/DZWebServers.xcodeproj -scheme DZWebServersTests \
  -destination 'platform=macOS' -configuration Debug
```

## Notes
- Class prefix is `DZ`, internal macro prefix is `DWS`
- The framework is pure Objective-C — no Swift source files in the framework (tests are Swift)
