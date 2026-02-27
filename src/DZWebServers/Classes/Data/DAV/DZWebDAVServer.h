/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DZWebServer.h"

NS_ASSUME_NONNULL_BEGIN

@class DZWebDAVServer;

/**
 *  @brief Delegate protocol for receiving notifications about WebDAV file operations.
 *
 *  Conforming objects are notified after the server completes file-level operations
 *  such as downloads, uploads, moves, copies, deletions, and directory creation.
 *  All methods are optional and extend the base @c DZWebServerDelegate protocol.
 *
 *  @warning These methods are always called on the main thread in a serialized way.
 *           They are dispatched asynchronously after the corresponding file operation
 *           has completed successfully.
 *
 *  @see DZWebDAVServer
 *  @see DZWebServerDelegate
 */
@protocol DZWebDAVServerDelegate <DZWebServerDelegate>
@optional

/**
 *  @brief Called after a file has been successfully downloaded (served) via a GET request.
 *
 *  This method is invoked when a client retrieves a file from the WebDAV server.
 *  It is not called for directory listings or HEAD requests.
 *
 *  @param server The WebDAV server instance that served the file.
 *  @param path   The absolute file system path of the file that was downloaded.
 */
- (void)davServer:(DZWebDAVServer*)server didDownloadFileAtPath:(NSString*)path;

/**
 *  @brief Called after a file has been successfully uploaded via a PUT request.
 *
 *  This method is invoked after the uploaded file has been moved from its temporary
 *  location to its final destination within the upload directory. Both new file
 *  creation and overwrites of existing files trigger this callback.
 *
 *  @param server The WebDAV server instance that received the upload.
 *  @param path   The absolute file system path where the uploaded file was saved.
 */
- (void)davServer:(DZWebDAVServer*)server didUploadFileAtPath:(NSString*)path;

/**
 *  @brief Called after a file or directory has been successfully moved via a MOVE request.
 *
 *  This method is invoked after the item has been relocated from its source path to
 *  its destination path. If an item already existed at the destination, it is replaced.
 *
 *  @param server   The WebDAV server instance that performed the move.
 *  @param fromPath The absolute file system path the item was moved from.
 *  @param toPath   The absolute file system path the item was moved to.
 */
- (void)davServer:(DZWebDAVServer*)server didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath;

/**
 *  @brief Called after a file or directory has been successfully copied via a COPY request.
 *
 *  This method is invoked after the item has been duplicated from its source path to
 *  its destination path. The original item remains unchanged at its source location.
 *
 *  @param server   The WebDAV server instance that performed the copy.
 *  @param fromPath The absolute file system path of the original item.
 *  @param toPath   The absolute file system path of the newly created copy.
 */
- (void)davServer:(DZWebDAVServer*)server didCopyItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath;

/**
 *  @brief Called after a file or directory has been successfully deleted via a DELETE request.
 *
 *  For directories, this indicates that the entire directory tree has been removed
 *  (the DELETE method uses @c "infinity" depth).
 *
 *  @param server The WebDAV server instance that performed the deletion.
 *  @param path   The absolute file system path of the item that was deleted.
 */
- (void)davServer:(DZWebDAVServer*)server didDeleteItemAtPath:(NSString*)path;

/**
 *  @brief Called after a directory has been successfully created via a MKCOL request.
 *
 *  This method is only invoked for single-level directory creation. All intermediate
 *  parent directories must already exist; otherwise the MKCOL request fails with a
 *  409 Conflict status before this callback is reached.
 *
 *  @param server The WebDAV server instance that created the directory.
 *  @param path   The absolute file system path of the newly created directory.
 */
- (void)davServer:(DZWebDAVServer*)server didCreateDirectoryAtPath:(NSString*)path;

@end

/**
 *  @brief A WebDAV server that serves files from a local upload directory.
 *
 *  @c DZWebDAVServer is a subclass of @c DZWebServer that implements a class 1
 *  compliant WebDAV server as defined by RFC 4918. It supports the full set of
 *  class 1 methods: OPTIONS, GET, PUT, DELETE, MKCOL, COPY, MOVE, PROPFIND,
 *  LOCK, and UNLOCK.
 *
 *  The server is also partially class 2 compliant (locking support), but only
 *  when the client is the macOS Finder WebDAV implementation (identified by the
 *  @c "WebDAVFS/" or @c "WebDAVLib/" user agent prefix). For all other clients,
 *  the server advertises class 1 compliance only and rejects LOCK/UNLOCK requests.
 *
 *  @discussion File operations can be filtered via @c allowedFileExtensions and
 *  @c allowHiddenItems properties, and further controlled by overriding the
 *  subclassing hook methods in the @c DZWebDAVServer(Subclassing) category.
 *
 *  @note The LOCK/UNLOCK implementation is a compatibility shim for macOS Finder.
 *        It does not maintain actual lock state; it responds with valid lock tokens
 *        but does not enforce exclusivity.
 *
 *  @see DZWebDAVServerDelegate
 *  @see DZWebServer
 */
@interface DZWebDAVServer : DZWebServer

/**
 *  @brief The root directory from which files are served and to which files are uploaded.
 *
 *  This is the absolute file system path that was provided during initialization via
 *  @c initWithUploadDirectory:. All WebDAV operations (GET, PUT, DELETE, MKCOL,
 *  COPY, MOVE, PROPFIND) are scoped to this directory and its subdirectories.
 *
 *  @note This property is immutable after initialization.
 */
@property(nonatomic, readonly, copy) NSString* uploadDirectory;

/**
 *  @brief The delegate that receives notifications about WebDAV file operations.
 *
 *  The delegate is notified after successful file downloads, uploads, moves, copies,
 *  deletions, and directory creations. All delegate callbacks are dispatched
 *  asynchronously on the main thread.
 *
 *  @discussion This property redeclares the superclass @c delegate property with the
 *  more specific @c DZWebDAVServerDelegate protocol type.
 *
 *  @see DZWebDAVServerDelegate
 */
@property(nonatomic, weak, nullable) id<DZWebDAVServerDelegate> delegate;

/**
 *  @brief An array of lowercase file extensions that are permitted for file operations.
 *
 *  When set, only files whose path extension (compared case-insensitively) matches one
 *  of the strings in this array will be allowed for upload, download, delete, copy, and
 *  move operations. Files with non-matching extensions will receive a 403 Forbidden response.
 *  Directory operations are not affected by this filter.
 *
 *  @note Extensions should be provided without a leading dot (e.g. @c @"pdf", @c @"txt").
 *        Comparison is performed using the lowercase form of the file's path extension.
 *
 *  The default value is @c nil, meaning all file extensions are allowed.
 */
@property(nonatomic, copy, nullable) NSArray<NSString*>* allowedFileExtensions;

/**
 *  @brief Controls whether hidden files and directories (names starting with a period) are accessible.
 *
 *  When set to @c NO, any WebDAV request targeting a file or directory whose name
 *  begins with @c "." will be rejected with a 403 Forbidden response. This applies
 *  to all operations including GET, PUT, DELETE, COPY, MOVE, MKCOL, and PROPFIND.
 *  Hidden items are also excluded from PROPFIND directory listings.
 *
 *  The default value is @c NO.
 */
@property(nonatomic) BOOL allowHiddenItems;

/**
 *  @brief Initializes a new WebDAV server with the specified upload directory.
 *
 *  This is the designated initializer. It registers handlers for all supported WebDAV
 *  HTTP methods: OPTIONS, GET, PUT, DELETE, MKCOL, COPY, MOVE, PROPFIND, LOCK, and UNLOCK.
 *
 *  The directory at @a path must exist before starting the server. The server will
 *  serve existing files from this directory and store uploaded files into it.
 *
 *  @param path The absolute file system path to the directory that will serve as the
 *              WebDAV root. This path is stored in the @c uploadDirectory property.
 *
 *  @return A newly initialized @c DZWebDAVServer instance.
 *
 *  @see uploadDirectory
 */
- (instancetype)initWithUploadDirectory:(NSString*)path NS_DESIGNATED_INITIALIZER;

/** Unavailable. Use @c initWithUploadDirectory: instead. */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable. Use @c initWithUploadDirectory: instead. */
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
 *  @brief Subclassing hooks for customizing WebDAV operation permissions.
 *
 *  Override these methods in a @c DZWebDAVServer subclass to implement custom
 *  authorization logic for file and directory operations. Each method is called
 *  after the server has validated the request (file extensions, hidden items, path
 *  existence) but before performing the actual file system operation.
 *
 *  All methods return @c YES by default, allowing the operation to proceed. Return
 *  @c NO to reject the operation, which will cause the server to respond with a
 *  403 Forbidden status.
 *
 *  @warning These methods can be called on any GCD thread. Ensure your implementations
 *           are thread-safe and avoid blocking the calling thread for extended periods.
 */
@interface DZWebDAVServer (Subclassing)

/**
 *  @brief Asks whether a file upload should be allowed to complete.
 *
 *  Called during a PUT request after the file has been fully received and written
 *  to a temporary location. The uploaded content is available for inspection at
 *  @a tempPath (e.g. to validate file contents, check size limits, or scan for
 *  prohibited content) before it is moved to its final destination.
 *
 *  @param path     The absolute file system path where the file will be stored if allowed.
 *  @param tempPath The absolute file system path to the temporary file containing the
 *                  uploaded data. This file will be deleted if the upload is rejected.
 *
 *  @return @c YES to allow the upload (default), or @c NO to reject it with a
 *          403 Forbidden response.
 */
- (BOOL)shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath;

/**
 *  @brief Asks whether a file or directory is allowed to be moved.
 *
 *  Called during a MOVE request after validating that both the source and destination
 *  paths are valid and accessible. If an item already exists at the destination and
 *  the @c Overwrite header permits replacement, this method is still consulted before
 *  proceeding.
 *
 *  @param fromPath The absolute file system path of the item to be moved.
 *  @param toPath   The absolute file system path of the intended destination.
 *
 *  @return @c YES to allow the move (default), or @c NO to reject it with a
 *          403 Forbidden response.
 */
- (BOOL)shouldMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath;

/**
 *  @brief Asks whether a file or directory is allowed to be copied.
 *
 *  Called during a COPY request after validating that both the source and destination
 *  paths are valid and accessible. The copy is performed with @c "infinity" depth,
 *  meaning directories are copied recursively.
 *
 *  @param fromPath The absolute file system path of the item to be copied.
 *  @param toPath   The absolute file system path of the intended copy destination.
 *
 *  @return @c YES to allow the copy (default), or @c NO to reject it with a
 *          403 Forbidden response.
 */
- (BOOL)shouldCopyItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath;

/**
 *  @brief Asks whether a file or directory is allowed to be deleted.
 *
 *  Called during a DELETE request after validating that the item exists and is
 *  accessible. For directories, the deletion is recursive (the DELETE method
 *  operates with @c "infinity" depth per RFC 4918).
 *
 *  @param path The absolute file system path of the item to be deleted.
 *
 *  @return @c YES to allow the deletion (default), or @c NO to reject it with a
 *          403 Forbidden response.
 */
- (BOOL)shouldDeleteItemAtPath:(NSString*)path;

/**
 *  @brief Asks whether a directory is allowed to be created.
 *
 *  Called during a MKCOL request after validating that the parent directory exists
 *  and the directory name passes hidden-item filtering. Only single-level directory
 *  creation is supported; intermediate directories are not created automatically.
 *
 *  @param path The absolute file system path of the directory to be created.
 *
 *  @return @c YES to allow the creation (default), or @c NO to reject it with a
 *          403 Forbidden response.
 */
- (BOOL)shouldCreateDirectoryAtPath:(NSString*)path;

@end

NS_ASSUME_NONNULL_END
