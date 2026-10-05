# DZWebServers - AGENTS.md

## Project Overview
Lightweight, GCD-based HTTP 1.1 server framework for embedding in iOS and macOS apps. Based on GCDWebServer by Pierre-Olivier Latour. Provides a 4-core architecture (server, connection, request, response) with built-in WebDAV and file uploader extensions. Pure Objective-C, no third-party dependencies.

## Tech Stack
- **Language**: Objective-C
- **Type**: Xcode Framework
- **Target-Platforms**: iOS / macOS

## Guides (MANDATORY)
Read `~/Agents/Guides/xcode-project-guide.md` in full before planning or editing anything.

Read these in full before touching the matching code:
- Swift style (`.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`
- Objective-C style (`.h`, `.m`): `~/Agents/Style/objc-style-guide.md`
- Accessibility (UI code, XIBs, storyboards): `~/Agents/Guides/accessibility-guide.md`

## Framework Dependencies
No third-party or local framework dependencies. System frameworks/libraries only: Foundation, CoreServices, UIKit (iOS) / AppKit (macOS), SystemConfiguration, CommonCrypto, libxml2 (WebDAV) and zlib (gzip encoding).

## Logging (MANDATORY)
This framework uses its own built-in logging system via macros defined in `DZWebServerPrivate.h`. This is a deliberate exception to the shared logging rule — keep using the `DWS_LOG_*` macros here.

```objc
DWS_LOG_DEBUG(@"...");    // Debug only (stripped in release)
DWS_LOG_VERBOSE(@"...");  // Verbose
DWS_LOG_INFO(@"...");     // Info
DWS_LOG_WARNING(@"...");  // Warning
DWS_LOG_ERROR(@"...");    // Error
```

Custom logging headers can be injected via `__DZWEBSERVER_LOGGING_HEADER__`. XLFacility is auto-detected if available. With the built-in facility only `DWS_LOG_DEBUG` is stripped in release; VERBOSE/INFO/WARNING/ERROR are compiled into release builds and filtered at runtime by `DZWebServerLogLevel` (release default: Info).

## Localization (MANDATORY)
- The framework supports 1 language (en) — `DZWebUploader.bundle` strings only

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
# iOS
xcodebuild test -project src/DZWebServers.xcodeproj -scheme DZWebServersTests \
  -destination 'platform=iOS Simulator,name=<available iPhone>' -configuration Debug

# macOS
xcodebuild test -project src/DZWebServers.xcodeproj -scheme DZWebServersTests \
  -destination 'platform=macOS' -configuration Debug
```

## Notes
- Internal macro prefix is `DWS`
