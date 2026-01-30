# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [November 2025]

### Changed
- Raised deployment target and then reverted to iOS 15 / macOS 12

## [April 2025]

### Fixed
- Added type cast to silence compiler warning

## [September 2024]

### Changed
- Updated project configuration

## [February 2024]

### Added
- macOS target support
- Privacy manifest

### Changed
- Updated umbrella header
- Updated directory structure
- Updated license
- Refactoring improvements

### Fixed
- Fixed compiler warning

## [July 2020]

### Changed
- Replaced deprecated MobileCoreServices with CoreServices

## [May 2020]

### Changed
- Replaced MobileCoreServices with CoreServices for compatibility

## [March 2020]

### Changed
- Updated to Xcode 11
- Updated Travis CI to Xcode 11.3

### Fixed
- Ignore deprecation warning for CC_MD5 on iOS 13+ and macOS 10.15+
- Fixed Info.plist build warnings
- Fixed Clang build warning

## [December 2019]

### Added
- Support for setting txtData in Bonjour service

## [August 2019]

### Added
- Enforced hidden and extensions restrictions when moving and copying files in uploaders

### Changed
- Updated to Swift 5
- Updated to Xcode 10.3
- Updated Travis CI to Xcode 10.3

### Fixed
- Fixed GCDWebServerBodyReaderCompletionBlock not allowing null data

## [July 2019]

### Changed
- Updated swebServer.swift hello world example

## [March 2019]

### Added
- Support for building and running GCDWebServer in app extensions
- Reverted app extensions merge (stability concerns)

## [January 2019]

### Added
- GCDWebServerNormalizePath() API
- Explicit modulemap for frameworks

### Changed
- Use module in test iOS and tvOS apps
- Changed iOS framework target family to "Universal"
- Switched tvOS targets to manual signing
- Use GCDWebServer framework for iOS and tvOS test apps
- Converted iOS and tvOS test apps to Swift
- Updated copyright years

### Fixed
- Fixed bug in _CreateHTTPMessageFromPerformingRequest()
- Fixed -stringByStandardizingPath handling on Mac CLT
- Only fallback to -[NSData base64Encoding] on macOS prior to 10.9
- Use @available() to check for API availability instead of -respondsToSelector:
- Fixed implicit-retain-self warnings
- Fixed strict-prototypes warning
- Handle CFHTTPMessageCopyBody() now returning NULL for valid messages without body
- Ensure directories are always listed in deterministic order
- Fall back to "CFBundleName" in GCDWebUploader footer if "CFBundleDisplayName" not defined

## [December 2018]

### Added
- Added types to collections (generics)

### Changed
- Updated to Xcode 10.10
- Updated to clang-format 7.0.0

### Fixed
- Fixed build warnings

## [October 2018]

### Changed
- PR comment-based improvements

## [July 2018]

### Changed
- Made changes based on PR comments

## [May 2018]

### Added
- Support to override built-in logger at runtime

## [November 2017]

### Changed
- Updated to Xcode 9.1

### Fixed
- Fixed NS_ASSUME_NONNULL_BEGIN not located at right place in GCDWebServerPrivate.h

## [August 2017]

### Added
- Return 501 Not Implemented error for requests without matching handlers

### Changed
- Simplified podspec
- Removed support for CocoaLumberJack

### Fixed
- Fixed CFURLCopyPath() returning NULL for "//" path
- Fixed static analyzer issues
- Fixed build warnings
- Updated project to Xcode 9

## [July 2017]

### Changed
- Increased CocoaLumberjack dependency to 3.x
- Changed minimal iOS version to 8.0

## [June 2017]

### Added
- Allow customization of MIME types used by GCDWebServerFileResponse
- Enable address sanitizer by default for Mac unit tests

### Changed
- Modernized Objective-C syntax
- Set default Xcode indentation to 2 spaces
- Updated to Xcode 8.3
- Updated to latest clang-format

### Fixed
- Fixed data race issue inside GCDWebServerGetMimeTypeForExtension()

## [January 2017]

### Changed
- Increased minimal iOS deployment target to 8.0
- Updated Travis CI to Xcode 8.2
- Resolves signing and building issue of dynamic frameworks

### Fixed
- Fixed build warning

## [December 2016]

### Changed
- Use clang-formatter to format source code
- Updated Xcode project format to 8.0
- Updated to Xcode 8.2

## [November 2016]

### Changed
- Documentation updates

## [September 2016]

### Changed
- Made "GCDWebUploader.bundle" non-flat to improve code-signing on OS X
- Updated for Xcode 8
- Removed executable bit from test and bundle files

## [July 2016]

### Changed
- Removed cs.default_subspec from subspecs (disallowed in CocoaPods)

## [June 2016]

### Changed
- Removed exception handling which was only partial

### Fixed
- Fixed typo in GCDWebServerGZipDecoder:open
- Fixed typo in Swift samples

## [May 2016]

### Fixed
- Minor documentation fix: "owns" -> "own"

## [April 2016]

### Added
- Added option to set the priority of the dispatch queue

### Changed
- Updated for Xcode 7.3

## [February 2016]

### Changed
- Removed guards around __kindof usage (project is Xcode 7 only)
- Added __kindof keyword where appropriate to avoid incompatible block pointer type errors

## [January 2016]

### Added
- Support WebDAV GET request byte ranges

### Changed
- Disabled address sanitizer

### Fixed
- Fixed build warning
- Fixed CocoaLumberjack dependencies
- Fixed NSRangeException by checking range of NSTextCheckingResult
- Fixed WebDAV test response files for byte-range responses

## [December 2015]

### Changed
- Set CFBundleVersion in Info.plist
- Updated to Xcode 7.2

## [November 2015]

### Added
- Added support for tvOS
- Allow serverURL to be assigned on tvOS with wifi connection

### Changed
- Updated iOS app to latest best practices
- Updated for Xcode 7.1
- Removed deprecation warnings on tvOS

## [October 2015]

### Added
- Enable support for tvOS

## [September 2015]

### Added
- Added support for NAT port mapping
- Enable support for Podfiles with use_frameworks!
- Added minimal tests for Mac framework
- Add version to framework Info.plist

### Changed
- Increased Bonjour resolution timeout to 5 seconds
- Turn 'buildForRunning' on for 'GCDWebServers' iOS and Mac Schemes
- Disable testing and running in shared schemes for frameworks
- Workaround for Swift 2 which fails to retain completion blocks passed as parameters

## [August 2015]

### Changed
- Documentation updates

## [July 2015]

### Added
- Carthage documentation

### Changed
- Updated for Xcode 7

### Fixed
- Fixed buffer overflow when retrieving socket addresses

## [June 2015]

### Changed
- Documentation updates

## [May 2015]

### Added
- Added Carthage support

### Changed
- Allow harmless 'Content-Type' headers on requests

## [April 2015]

### Added
- Added remote and local addresses to GCDWebServerRequest
- Generated Frameworks

### Changed
- Updated for CocoaLumberJack 2.0
- Removed Bot scheme

### Fixed
- Fixed -serverURL not taking into account GCDWebServerOption_BindToLocalhost
- Fixed Xcode 6.3 warnings
- Don't start a background task while app is already in background

## [March 2015]

### Changed
- Handle starting the server with nil options
- Made _CompareResources() easier to read

## [January 2015]

### Added
- Added asyncResponse2 mode
- Added Xcode bot scheme

### Fixed
- Only wipe GCDWebUploader.bundle on Debug to avoid issues on Xcode bot
- Addressed static analyzer warnings
- Fixed incorrect documentation for GCDWebServerAsyncStreamBlock

## [December 2014]

### Fixed
- Removed invalid check

## [November 2014]

### Added
- Added GCDWebServerOption_BindToLocalhost option

### Changed
- Workaround Firefox and IE not showing file selection dialog
- Removed MRC (Manual Reference Counting) support entirely

### Fixed
- Fixed behavior of GCDWebServerOption_BonjourName option
- Adding check to _endBackgroundTask to verify application exists before calling GWS_DNOT_REACHED

## [October 2014]

### Added
- Added support for IPv6
- Added support for third-party logging facilities
- Added XLFacilityLogging.h
- Added support for async handlers
- Added attribute collection to GCDWebServerRequest with regex captures

### Changed
- Updated iOS app for iOS 8 SDK
- Lowered deployment targets
- Replaced preprocessor constant "NDEBUG" by "DEBUG" and flipped behavior
- Added README and podspec files to Xcode project
- Renamed GCDWebServerStreamingBlock to GCDWebServerStreamBlock
- Upgraded to Xcode 6.1

### Fixed
- Fixed rare race-condition with disconnection timer
- Fixed rare exception in GCDWebServerParseURLEncodedForm()
- Added truly asynchronous support to GCDWebServerStreamedResponse
- Added support for asynchronous reading in GCDWebServerBodyReader
- Enabled ENABLE_STRICT_OBJC_MSGSEND

## [September 2014]

### Changed
- Improved handling of symbolic links in -addGETHandlerForBasePath:directoryPath:indexFilename:cacheAge:allowRangeRequests:
- Improved automatic detection of when to use dispatch_retain() and dispatch_release()
- Run test against default and oldest supported deployment targets

### Fixed
- Fixed -bonjourServerURL to correctly return hostname instead of service name
- Fall back to CFBundleName if CFBundleDisplayName is not available
- Updated for Xcode 6

## [August 2014]

### Changed
- Improved automatic detection of dispatch_retain/dispatch_release usage

## [July 2014]

### Fixed
- Ensure -isRunning works as expected even if GCDWebServerOption_AutomaticallySuspendInBackground is enabled

## [June 2014]

### Added
- Validate paths passed to GCDWebDAVServer and GCDWebUploader for security

### Changed
- Adding instructions for Swift command line tool

## [May 2014]

### Added
- Can specify a custom Bonjour service type for the server

### Changed
- Removed unneeded API for custom Bonjour type

### Fixed
- Fix content-types like "application/json; charset=utf-8"
- Fixed errno being corrupted by LOG_ERROR()
- Fix GCDWebServerParseURLEncodedForm to allow empty values
- Ensure connected state is updated immediately after calling -stop

## [April 2014]

### Added
- Added Travis CI integration
- Added support for "multipart/mixed" parts inside "multipart/form-data"
- Added HTMLFileUpload and HTMLForm unit tests
- Added "htmlFileUpload" mode
- GCDWebServerMIMEStreamParser class
- Added -webServerDidCompleteBonjourRegistration:
- Added -logException: API
- Added support for digest authentication
- Added support for Basic Authentication
- Added -preflightRequest: and -overrideResponse:forRequest: APIs
- Added GCDWebServerErrorResponse
- Added logging APIs
- Added -hasByteRange API
- Added GCDWebServerHTTPStatusCodes.h
- Added -abortRequest:withStatusCode: API
- Added support for "ETag" and "If-None-Match" headers
- Added support for "If-Modified-Since" and "Accept-Encoding" headers
- Added support for "Last-Modified" response header
- Added support for chunked transfer encoding in request bodies
- Added support for gzip body encoding
- GCDWebServerBodyWriter protocol
- Added GCDWebServerChunkedResponse
- Added support for moving files
- Added GCDWebUploader
- GCDWebServerEscapeURLString()
- JSON support to GCDWebServerDataResponse
- Added Drag & Drop browser file upload demo
- HTTP range requests support
- Exposed hooks to monitor bytes read and written
- Added video streaming unit test

### Changed
- Modified GCDWebServerMultiPart to allow duplicate control names
- Exclude GCDWebServerPrivate.h from Podspec
- Allow multiple user accounts for authentication
- Cleaned up authentication options
- Updated run APIs to use options
- Added support for background mode on iOS
- Replaced GCDWebServer subclassing with explicit options
- Added connected state to GCDWebServer
- Added GCDWebServerDelegate
- Added +[GCDWebServer maxPendingConnections]
- Changed -[GCDWebServerConnection open] to return a BOOL
- Organized source code in subfolders
- Moved functions to GCDWebServerFunctions.[h/m]
- First pass at implementing class 1 WebDAV server
- Automatically handle ETag and Last-Modified-Date caching
- Automatically map HEAD requests to GET ones
- Added -replaceResponse:forRequest: hook
- Renamed GCDWebServerStreamResponse to GCDWebServerStreamingResponse
- Moved response body chunked transfer encoding to GCDWebServerConnection
- Split class files
- Updated to "instancetype" type
- Expose local and remote address on GCDWebServerConnection
- GCDWebServerGetMimeTypeForExtension() always returns a MIME type
- Allow customizing content type for JSON responses
- Exposed internal utility functions
- Updated handlers convenience API
- Enable -Weverything for Debug builds
- Updated API to expose range requests support
- Renamed "class" method arguments to "aClass" for C++ compatibility
- Updated to Xcode 5.1

### Fixed
- Unit tests finalized and expanded
- Allow non-ISO Latin 1 file names when downloading files
- Fixed parsing of 'multipart/form-data' with non-ASCII headers
- Fixed unit tests to work in any time zone
- Fixed source folder name typo
- Make header parsing more robust
- Don't cache GCDWebServerDataResponse
- Fixed linking issues with Podspec
- Static analyzer warning fix for unused variables when logging disabled
- Fixed memory corruption under non-ARC
- Fixed memory leak
- Improved CocoaPods integration
- Optimized logging
- Allow HEAD requests on collections
- Moved +shouldAutomaticallyMapHEADToGET to GCDWebServer class
- Cleaned up file servers error handling
- Added -description methods
- Only set "Cache-Control" on successful responses
- Fixed memory corruption
- Properly handle casing of header values
- Fix non-ARC build failure
- Fixed addDefaultHandlerForMethod:requestClass:processBlock: ignoring method
- Enable -Wshadow
- Fixed warning regarding shadowing local variables
- Enforce Content-Type and Content-Length consistency on requests
- Fixed rare exception

## [March 2014]

### Changed
- Changed default port to 80 on iOS but still 8080 on Mac & iOS Simulator
- Disable -runWithPort: on iOS
- Move ivars to class extensions
- Enabled -Wshorten-64-to-32
- Moved logging message function to GCDWebServer.m
- Switched to standard architectures on iOS

## [February 2014]

### Changed
- Updated copyright year

### Fixed
- Fixed more build warnings

## [January 2014]

### Added
- Added ARC support
- Added bonjourName property
- Added podspec for version 1.2

### Changed
- Updated for arm64
- Removed podspec file (moved to CocoaPods repo)
- Log to stderr instead of stdout
- Don't use deprecated dispatch_get_current_queue()
- Don't use dispatch_release() under ARC in OS X 10.8 or iOS 6.0 and later
- Check for main thread only during first +initialize call

### Fixed
- Make sure @bonjourName is not an empty string

## [December 2013]

### Changed
- Cleaned up .gitignore
- Fixed copyrights and placeholders

## [October 2013]

### Changed
- Updated to Xcode 5.0

## [April 2013]

### Changed
- Removed dependency on CFSocket to be 100% GCD based

### Fixed
- Small fixes

## [March 2013]

### Fixed
- Fixed headers not being parsed properly when not received all at once
- Removed unnecessary NSAssert
- Fixed double space typo
- Improved handling of port 0

## [December 2012]

### Added
- Initial public release
- Added test cases
- Moved GCDWebServerConnection to its own source files
- Updated Xcode project for Mac & iOS

### Changed
- Initial import of GCDWebServer
