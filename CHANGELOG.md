# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Documentation for all public APIs.
- Test suite covering the server, connection, request and response classes, the web uploader, and WebDAV server.
- Swift-friendly non-variadic alternatives for the C variadic logging methods on `DZWebServer` and the error response factory methods.

### Changed
- Tightened Swift interoperability across all public headers, including nullability, copy semantics, and Swift-friendly naming.
- Modernized `DZWebServerOption_DispatchQueuePriority` default to `QOS_CLASS_DEFAULT`; legacy priority values continue to work.

## [November 2025]

### Changed
- Set deployment targets back to iOS 15 / macOS 12.

## [April 2025]

### Fixed
- Silenced a compiler warning with an explicit type cast.

## [September 2024]

### Changed
- Updated project configuration.

## [February 2024]

### Added
- macOS target support.
- Privacy manifest.

### Changed
- Updated umbrella header and directory structure.

## [July 2020]

### Changed
- Replaced deprecated MobileCoreServices with CoreServices.

## [March 2020]

### Changed
- Updated to Xcode 11.

### Fixed
- Silenced `CC_MD5` deprecation warning on iOS 13+ and macOS 10.15+.
- Fixed `Info.plist` and Clang build warnings.

## [December 2019]

### Added
- Support for setting `txtData` on the Bonjour service.

## [August 2019]

### Added
- Hidden file and extension restrictions are now enforced when moving and copying files in uploaders.

### Changed
- Updated to Swift 5.

### Fixed
- `GCDWebServerBodyReaderCompletionBlock` now accepts null data.

## [March 2019]

### Added
- Support for building and running in app extensions.

## [January 2019]

### Added
- `GCDWebServerNormalizePath()` API.
- Explicit modulemap for frameworks.

### Changed
- Use a module in the iOS and tvOS test apps.
- Converted iOS and tvOS test apps to Swift.

### Fixed
- Bug in `_CreateHTTPMessageFromPerformingRequest()`.
- Handle `CFHTTPMessageCopyBody()` returning NULL for valid messages without a body.
- Directories are listed in deterministic order.

## [December 2018]

### Added
- Lightweight generics on collection types.

## [May 2018]

### Added
- Override the built-in logger at runtime.

## [August 2017]

### Added
- Return 501 Not Implemented for requests without a matching handler.

### Changed
- Removed CocoaLumberjack support.

### Fixed
- `CFURLCopyPath()` returning NULL for "//" paths.

## [June 2017]

### Added
- Customize MIME types used by `GCDWebServerFileResponse`.

### Fixed
- Data race in `GCDWebServerGetMimeTypeForExtension()`.

## [January 2017]

### Changed
- Raised minimum iOS deployment target to 8.0.
- Resolved signing and build issues for dynamic frameworks.

## [June 2016]

### Changed
- Removed partial exception handling.

### Fixed
- Typo in `GCDWebServerGZipDecoder:open`.

## [April 2016]

### Added
- Option to set the priority of the dispatch queue.

## [January 2016]

### Added
- Byte range support for WebDAV GET requests.

### Fixed
- `NSRangeException` by checking the range of `NSTextCheckingResult`.
- WebDAV test response files for byte-range responses.

## [November 2015]

### Added
- tvOS support.
- `serverURL` may be assigned on tvOS over Wi-Fi.

## [September 2015]

### Added
- NAT port mapping support.
- CocoaPods `use_frameworks!` support.
- Version in framework `Info.plist`.

### Changed
- Increased Bonjour resolution timeout to 5 seconds.

## [July 2015]

### Added
- Carthage documentation.

### Fixed
- Buffer overflow when retrieving socket addresses.

## [May 2015]

### Added
- Carthage support.

### Changed
- Allow harmless `Content-Type` headers on requests.

## [April 2015]

### Added
- Remote and local addresses on `GCDWebServerRequest`.
- Generated frameworks.

### Fixed
- `serverURL` honors `GCDWebServerOption_BindToLocalhost`.
- Don't start a background task while the app is already in background.

## [January 2015]

### Added
- `asyncResponse2` mode.

## [November 2014]

### Added
- `GCDWebServerOption_BindToLocalhost` option.

### Changed
- Worked around Firefox and IE not showing the file selection dialog.
- Removed manual reference counting support.

### Fixed
- Behavior of the `GCDWebServerOption_BonjourName` option.

## [October 2014]

### Added
- IPv6 support.
- Third-party logging facility support.
- Async handler support.
- Attribute collection on `GCDWebServerRequest` with regex captures.

### Changed
- Updated iOS app for the iOS 8 SDK.
- Renamed `GCDWebServerStreamingBlock` to `GCDWebServerStreamBlock`.

### Fixed
- Rare race condition with the disconnection timer.
- Rare exception in `GCDWebServerParseURLEncodedForm()`.
- Truly asynchronous support in `GCDWebServerStreamedResponse` and `GCDWebServerBodyReader`.

## [September 2014]

### Changed
- Improved handling of symbolic links in directory GET handlers.

### Fixed
- `bonjourServerURL` returns the hostname instead of the service name.
- Fall back to `CFBundleName` when `CFBundleDisplayName` is unavailable.

## [July 2014]

### Fixed
- `isRunning` works as expected even with `GCDWebServerOption_AutomaticallySuspendInBackground` enabled.

## [June 2014]

### Added
- Path validation in `GCDWebDAVServer` and `GCDWebUploader` for security.

## [May 2014]

### Added
- Custom Bonjour service type support.

### Fixed
- Content types like `application/json; charset=utf-8`.
- `errno` corruption by `LOG_ERROR()`.
- `GCDWebServerParseURLEncodedForm` accepts empty values.
- Connected state is updated immediately after `-stop`.

## [April 2014]

### Added
- Travis CI integration.
- `multipart/mixed` parts inside `multipart/form-data`.
- `htmlFileUpload` mode and `GCDWebServerMIMEStreamParser`.
- Bonjour completion delegate callback.
- Basic and digest authentication.
- `preflightRequest:` and `overrideResponse:forRequest:` APIs.
- `GCDWebServerErrorResponse` and logging APIs.
- `hasByteRange` API.
- `GCDWebServerHTTPStatusCodes.h`.
- `abortRequest:withStatusCode:` API.
- `ETag`, `If-None-Match`, `If-Modified-Since`, `Accept-Encoding`, and `Last-Modified` header support.
- Chunked transfer encoding for request bodies and gzip body encoding.
- `GCDWebServerChunkedResponse` and `GCDWebServerBodyWriter` protocol.
- File move support.
- `GCDWebUploader` with drag-and-drop browser uploads.
- JSON support on `GCDWebServerDataResponse`.
- HTTP range request support.
- Hooks for monitoring bytes read and written.

### Changed
- Allow duplicate control names in `GCDWebServerMultiPart`.
- Multiple user accounts for authentication.
- Replaced subclassing with explicit options.
- Background mode support on iOS.
- Added `GCDWebServerDelegate`.
- Auto-handle `ETag` and `Last-Modified-Date` caching; auto-map HEAD requests to GET.
- First pass at a class 1 WebDAV server.

### Fixed
- Many parsing, memory, and logging fixes; see the original commits for details.

## [March 2014]

### Changed
- Default port is now 80 on iOS, 8080 on Mac and the iOS Simulator.
- Disabled `runWithPort:` on iOS.

## [February 2014]

### Fixed
- Additional build warnings.

## [January 2014]

### Added
- ARC support.
- `bonjourName` property.

### Changed
- Updated for arm64.
- Log to stderr instead of stdout.

## [October 2013]

### Changed
- Updated to Xcode 5.0.

## [April 2013]

### Changed
- Removed `CFSocket` dependency for a fully GCD-based implementation.

## [March 2013]

### Fixed
- Headers parsed correctly when not received all at once.
- Improved handling of port 0.

## [December 2012]

### Added
- Initial public release.
