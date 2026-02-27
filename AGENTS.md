# DZWebServers - AGENTS.md

## Project Overview
Lightweight, GCD-based HTTP 1.1 server framework for embedding in iOS and macOS apps. Based on GCDWebServer by Pierre-Olivier Latour. Provides a 4-core architecture (server, connection, request, response) with built-in WebDAV and file uploader extensions. Pure Objective-C, no third-party dependencies.

## Tech Stack
- **Language**: Objective-C
- **Type**: Xcode Framework
- **Target-Platforms**: iOS 15.6+ / macOS 12.4+

## Framework Dependencies
None. This framework depends only on Foundation and CoreServices (system frameworks).

## Source Layout
```
src/DZWebServers/
├── Classes/Data/
│   ├── DZWebServers.h                          # Umbrella header
│   ├── DZWebServer.h / .m                      # Core server class
│   ├── DZWebServerConnection.h / .m            # Connection handler
│   ├── DZWebServerFunctions.h / .m             # Utility C functions
│   ├── DZWebServerHTTPStatusCodes.h            # HTTP status constants
│   ├── DZWebServerPrivate.h                    # Private logging/macros
│   ├── Requests/                               # Request subclasses
│   │   ├── DZWebServerRequest.h / .m           # Base request
│   │   ├── DZWebServerDataRequest.h / .m       # In-memory body
│   │   ├── DZWebServerFileRequest.h / .m       # File-backed body
│   │   ├── DZWebServerMultiPartFormRequest.h / .m  # Multipart form
│   │   └── DZWebServerURLEncodedFormRequest.h / .m # URL-encoded form
│   ├── Responses/                              # Response subclasses
│   │   ├── DZWebServerResponse.h / .m          # Base response
│   │   ├── DZWebServerDataResponse.h / .m      # In-memory response
│   │   ├── DZWebServerFileResponse.h / .m      # File-backed response
│   │   ├── DZWebServerStreamedResponse.h / .m  # Streaming response
│   │   └── DZWebServerErrorResponse.h / .m     # Error responses
│   ├── Uploader/
│   │   └── DZWebUploader.h / .m                # Browser-based file upload UI
│   └── DAV/
│       └── DZWebDAVServer.h / .m               # WebDAV server extension
└── Resources/
    ├── DZWebUploader.bundle/                   # HTML/CSS/JS for uploader UI
    └── PrivacyInfo.xcprivacy                   # Privacy manifest
```

## Style & Conventions (MANDATORY)
Style guides are loaded automatically via `~/.claude/rules/` based on file type.
- **Objective-C** (`*.h`, `*.m`): `~/Agents/Style/objc-style-guide.md`
- **Swift** (`*.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`

## Changelog (MANDATORY)
**All important code changes** (fixes, additions, deletions, changes) have to written to CHANGELOG.md.
Changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Before writing to CHANGELOG.md:**
1. Check for new release tags: `git tag --sort=-creatordate | head -1`
2. Release tags are prefixed with `v` (e.g., `v2.0.1`)
3. If a new tag exists that isn't in CHANGELOG.md, create a new version section with that tag's version and date, moving relevant [Unreleased] content under it

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

## API Documentation
Local Apple API documentation is available at:
`~/Agents/API Documentation/Apple/`

```bash
~/Agents/API\ Documentation/Apple/search --help  # Run once per session
~/Agents/API\ Documentation/Apple/search "NSFilePresenter" --language objc
```

## Xcode Project Files (CATASTROPHIC — DO NOT TOUCH)
- **NEVER edit Xcode project files** (`.xcodeproj`, `.xcworkspace`, `project.pbxproj`, `.xcsettings`, etc.)
- Editing these files will corrupt the project — this is **catastrophic and unrecoverable**
- Only the user edits project settings, build phases, schemes, and file references manually in Xcode
- If a file needs to be added to the project, **stop and tell the user** — do not attempt it yourself
- Use `xcodebuild` for building/testing only — never for project manipulation
- **Exception**: Only proceed if the user gives explicit permission for a specific edit

## File System Synchronized Groups (Xcode 16+)
This project uses **File System Synchronized Groups** (internally `PBXFileSystemSynchronizedRootGroup`), introduced in Xcode 16. This means:
- The `Classes/` and `Resources/` directories are **directly synchronized** with the file system
- **You CAN freely create, move, rename, and delete files** in these directories
- Xcode automatically picks up all changes — no project file updates needed
- This is different from legacy Xcode groups, which required manual project file edits

**Bottom line:** Modify source files in `Classes/` and `Resources/` freely. Just never touch the `.xcodeproj` files themselves.

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
This project uses **Swift Testing** (`@Test`, `@Suite`, `#expect`). Tests live in `src/DZWebServersTests/`.

**Run tests after every code change:**
```bash
xcodebuild test -project src/DZWebServers.xcodeproj -scheme DZWebServersTests \
  -destination 'platform=macOS' -configuration Debug
```

**Rules:**
- Tests **must pass** before handoff for every supported platform — do not leave broken tests
- When adding or changing public API, **add or update corresponding tests**
- When removing public API, **remove the corresponding tests**
- One test file per public class

---

## Notes
- All public APIs must have documentation comments
- Class prefix is `DZ`, internal macro prefix is `DWS`
- The framework is pure Objective-C — no Swift source files in the framework (tests are Swift)
