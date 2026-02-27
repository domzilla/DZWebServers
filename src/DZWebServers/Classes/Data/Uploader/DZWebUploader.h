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

@class DZWebUploader;

/**
 *  @brief Delegate protocol for receiving notifications about file operations performed through the DZWebUploader web interface.
 *
 *  @discussion Conforming objects receive callbacks whenever a user performs a file operation
 *  (upload, download, move, delete, or create directory) through the browser-based interface.
 *  All methods are optional and extend the @c DZWebServerDelegate protocol, so a single
 *  delegate object can handle both server lifecycle events and uploader file operation events.
 *
 *  @warning These methods are always called on the main thread in a serialized way.
 *
 *  @see DZWebUploader
 *  @see DZWebServerDelegate
 */
@protocol DZWebUploaderDelegate <DZWebServerDelegate>
@optional

/**
 *  @brief Called after a file has been successfully downloaded by a client through the web interface.
 *
 *  @discussion This method is dispatched asynchronously on the main queue after the server
 *  has begun sending the file response to the client. Use this to update your UI or track
 *  download activity.
 *
 *  @param uploader The @c DZWebUploader instance that served the download.
 *  @param path     The absolute file system path of the file that was downloaded.
 */
- (void)webUploader:(DZWebUploader*)uploader didDownloadFileAtPath:(NSString*)path;

/**
 *  @brief Called after a file has been successfully uploaded and saved to the upload directory.
 *
 *  @discussion This method is dispatched asynchronously on the main queue after the uploaded
 *  file has been moved from its temporary location to its final destination within the upload
 *  directory. If a file with the same name already existed, the new file is automatically
 *  renamed with a numeric suffix (e.g. "file (1).txt") to avoid overwriting.
 *
 *  @param uploader The @c DZWebUploader instance that received the upload.
 *  @param path     The absolute file system path where the uploaded file was saved.
 */
- (void)webUploader:(DZWebUploader*)uploader didUploadFileAtPath:(NSString*)path;

/**
 *  @brief Called after a file or directory has been successfully moved (renamed).
 *
 *  @discussion This method is dispatched asynchronously on the main queue after the item
 *  has been moved on disk. If an item already exists at the destination path, the moved
 *  item is automatically renamed with a numeric suffix to avoid conflicts.
 *
 *  @param uploader The @c DZWebUploader instance that performed the move.
 *  @param fromPath The absolute file system path the item was moved from.
 *  @param toPath   The absolute file system path the item was moved to.
 */
- (void)webUploader:(DZWebUploader*)uploader didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath;

/**
 *  @brief Called after a file or directory has been successfully deleted.
 *
 *  @discussion This method is dispatched asynchronously on the main queue after the item
 *  has been removed from disk. For directories, the deletion is recursive and all contained
 *  items are also removed.
 *
 *  @param uploader The @c DZWebUploader instance that performed the deletion.
 *  @param path     The absolute file system path of the item that was deleted.
 */
- (void)webUploader:(DZWebUploader*)uploader didDeleteItemAtPath:(NSString*)path;

/**
 *  @brief Called after a new directory has been successfully created.
 *
 *  @discussion This method is dispatched asynchronously on the main queue after the directory
 *  has been created on disk. If a directory with the same name already existed, the new
 *  directory is automatically renamed with a numeric suffix.
 *
 *  @param uploader The @c DZWebUploader instance that created the directory.
 *  @param path     The absolute file system path of the newly created directory.
 */
- (void)webUploader:(DZWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path;

@end

/**
 *  @brief A browser-based file management server that provides an HTML 5 web interface
 *  for uploading, downloading, moving, and deleting files and directories.
 *
 *  @discussion @c DZWebUploader is a subclass of @c DZWebServer that automatically registers
 *  HTTP handlers for a complete file management web application. When started, it serves an
 *  HTML 5 interface that allows users to:
 *
 *  - Upload files via drag-and-drop or a file picker
 *  - Download files from the upload directory
 *  - Move and rename files and directories
 *  - Delete files and directories
 *  - Create new directories
 *  - Browse the directory hierarchy
 *
 *  The web interface assets are loaded from @c DZWebUploader.bundle, which is included in the
 *  framework resources. The interface appearance can be customized using the @c title, @c header,
 *  @c prologue, @c epilogue, and @c footer properties.
 *
 *  File operations can be filtered using @c allowedFileExtensions and @c allowHiddenItems,
 *  and further controlled by overriding the subclassing hooks in the @c DZWebUploader(Subclassing)
 *  category.
 *
 *  When a file with the same name already exists at the destination, the uploader automatically
 *  appends a numeric suffix (e.g. "file (1).txt") to prevent overwriting.
 *
 *  @warning For @c DZWebUploader to work, @c DZWebUploader.bundle must be added to the
 *  resources of the Xcode target. Initialization will fail and return @c nil if the bundle
 *  cannot be found.
 *
 *  @see DZWebServer
 *  @see DZWebUploaderDelegate
 */
@interface DZWebUploader : DZWebServer

/**
 *  @brief The root directory path that the uploader serves and manages.
 *
 *  @discussion This is the absolute file system path specified during initialization via
 *  @c initWithUploadDirectory:. All file operations (uploads, downloads, moves, deletions,
 *  and directory creation) are scoped to this directory and its subdirectories.
 */
@property(nonatomic, readonly, copy) NSString* uploadDirectory;

/**
 *  @brief The delegate object that receives notifications about file operations.
 *
 *  @discussion The delegate is notified whenever a file operation (upload, download, move,
 *  delete, or directory creation) completes successfully through the web interface. Delegate
 *  methods are always dispatched asynchronously on the main queue.
 *
 *  This property redeclares the @c delegate from @c DZWebServer with the more specific
 *  @c DZWebUploaderDelegate protocol type.
 *
 *  @see DZWebUploaderDelegate
 */
@property(nonatomic, weak, nullable) id<DZWebUploaderDelegate> delegate;

/**
 *  @brief An array of lowercase file extensions that are allowed for file operations.
 *
 *  @discussion When set, only files whose extension (compared case-insensitively) matches
 *  one of the strings in this array can be uploaded, downloaded, moved, or deleted.
 *  Directories are not affected by this filter.
 *
 *  For example, setting this to @c \@[\@"jpg", \@"png", \@"pdf"] would restrict all file
 *  operations to JPEG, PNG, and PDF files only.
 *
 *  The default value is @c nil, meaning all file extensions are allowed.
 */
@property(nonatomic, copy, nullable) NSArray<NSString*>* allowedFileExtensions;

/**
 *  @brief Controls whether hidden files and directories (names starting with a period) are visible
 *  and operable through the web interface.
 *
 *  @discussion When set to @c NO, hidden items are excluded from directory listings and all
 *  file operations (upload, download, move, delete) are denied for items whose name starts
 *  with a period character. This applies to both files and directories.
 *
 *  The default value is @c NO.
 */
@property(nonatomic) BOOL allowHiddenItems;

/**
 *  @brief The title displayed in the browser tab and page heading of the web interface.
 *
 *  @discussion This value is used as the HTML @c \<title\> element and is injected into the
 *  web interface template. It is also used as the default value for the @c header property
 *  if that property has not been explicitly set.
 *
 *  The default value is the application's display name (@c CFBundleDisplayName), falling
 *  back to the bundle name (@c CFBundleName), and on macOS further falling back to the
 *  process name.
 *
 *  @warning Any reserved HTML characters in the string value for this property must have
 *  been replaced by character entities (e.g. "&" becomes "&amp;amp;").
 */
@property(nonatomic, copy) NSString* title;

/**
 *  @brief The header text displayed prominently at the top of the web interface page.
 *
 *  @discussion This value is injected into the web interface template as the main heading
 *  visible to users when they open the uploader in a browser.
 *
 *  The default value is the same as the @c title property.
 *
 *  @warning Any reserved HTML characters in the string value for this property must have
 *  been replaced by character entities (e.g. "&" becomes "&amp;amp;").
 */
@property(nonatomic, copy) NSString* header;

/**
 *  @brief Raw HTML content displayed between the header and the file listing in the web interface.
 *
 *  @discussion Use this to provide instructions, help text, or any introductory content to
 *  users accessing the uploader. The value is inserted directly into the HTML template without
 *  escaping.
 *
 *  The default value is a localized short help text loaded from @c DZWebUploader.bundle.
 *
 *  @warning The string value for this property must be raw HTML
 *  (e.g. @c "\<p\>Some text\</p\>").
 */
@property(nonatomic, copy) NSString* prologue;

/**
 *  @brief Raw HTML content displayed after the file listing in the web interface.
 *
 *  @discussion Use this to provide supplementary information, disclaimers, or any
 *  closing content below the file management area. The value is inserted directly
 *  into the HTML template without escaping.
 *
 *  The default value is @c nil, meaning no epilogue is displayed.
 *
 *  @warning The string value for this property must be raw HTML
 *  (e.g. @c "\<p\>Some text\</p\>").
 */
@property(nonatomic, copy, nullable) NSString* epilogue;

/**
 *  @brief The footer text displayed at the bottom of the web interface page.
 *
 *  @discussion This value is injected into the web interface template as the page footer.
 *  Typically used to display branding or version information.
 *
 *  The default value is a formatted string combining the application's display name
 *  (or bundle name) with its short version string (@c CFBundleShortVersionString).
 *  On macOS, if neither is available, it falls back to "OS X" and the operating system
 *  version string.
 *
 *  @warning Any reserved HTML characters in the string value for this property must have
 *  been replaced by character entities (e.g. "&" becomes "&amp;amp;").
 */
@property(nonatomic, copy) NSString* footer;

/**
 *  @brief Initializes the uploader with the specified directory as the root for all file operations.
 *
 *  @discussion This is the designated initializer for @c DZWebUploader. It loads the web interface
 *  assets from @c DZWebUploader.bundle and registers all necessary HTTP handlers for serving
 *  the web page, listing directories, downloading files, uploading files, moving items,
 *  deleting items, and creating directories.
 *
 *  The following HTTP endpoints are registered:
 *  - @c GET @c /        — Serves the main HTML page
 *  - @c GET @c /list    — Returns a JSON directory listing
 *  - @c GET @c /download — Downloads a file as an attachment
 *  - @c POST @c /upload  — Handles multipart file uploads
 *  - @c POST @c /move    — Moves (renames) a file or directory
 *  - @c POST @c /delete  — Deletes a file or directory
 *  - @c POST @c /create  — Creates a new directory
 *
 *  Static resources from the bundle (CSS, JavaScript, images) are served with a 1-hour cache age.
 *
 *  @param path The absolute file system path to the directory that will serve as the root for
 *              all file operations. This directory must already exist on disk.
 *
 *  @return An initialized @c DZWebUploader instance, or @c nil if @c DZWebUploader.bundle
 *          could not be found in the framework bundle.
 */
- (instancetype)initWithUploadDirectory:(NSString*)path NS_DESIGNATED_INITIALIZER;

/** Unavailable. Use @c initWithUploadDirectory: instead. */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable. Use @c initWithUploadDirectory: instead. */
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
 *  @brief Subclassing hooks for customizing file operation authorization in @c DZWebUploader.
 *
 *  @discussion Override these methods in a @c DZWebUploader subclass to implement custom
 *  authorization logic for file operations. Each method acts as a gatekeeper: returning @c YES
 *  allows the operation to proceed, while returning @c NO causes the server to respond with
 *  an HTTP 403 Forbidden error.
 *
 *  All default implementations return @c YES, permitting all operations. These hooks are
 *  called after the built-in checks for @c allowedFileExtensions and @c allowHiddenItems
 *  have already passed.
 *
 *  @warning These methods can be called on any GCD thread. Ensure your implementations
 *  are thread-safe.
 *
 *  @see DZWebUploader
 */
@interface DZWebUploader (Subclassing)

/**
 *  @brief Called to determine whether an uploaded file should be accepted and saved.
 *
 *  @discussion This hook is invoked after the file has been fully received and written to a
 *  temporary location on disk. You can inspect the temporary file (e.g. check its size, validate
 *  its content, or scan for malware) before deciding whether to allow the upload to complete.
 *
 *  If this method returns @c NO, the upload is rejected with an HTTP 403 Forbidden response
 *  and the temporary file is not moved to the upload directory.
 *
 *  The default implementation returns @c YES.
 *
 *  @param path     The absolute destination path where the file will be saved if the upload
 *                  is accepted. This path has already been de-duplicated if necessary.
 *  @param tempPath The absolute path to the temporary file containing the uploaded data.
 *                  This file is available for inspection but will be cleaned up automatically.
 *
 *  @return @c YES to accept the upload and move the file to @a path, or @c NO to reject it.
 */
- (BOOL)shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath;

/**
 *  @brief Called to determine whether a file or directory move (rename) operation should proceed.
 *
 *  @discussion This hook is invoked before the item is moved on disk. Use it to enforce
 *  custom authorization rules, such as preventing items from being moved outside certain
 *  directories or restricting renames.
 *
 *  If this method returns @c NO, the move is rejected with an HTTP 403 Forbidden response.
 *
 *  The default implementation returns @c YES.
 *
 *  @param fromPath The absolute file system path of the item to be moved.
 *  @param toPath   The absolute destination path. This path has already been de-duplicated
 *                  if an item with the same name exists at the destination.
 *
 *  @return @c YES to allow the move, or @c NO to reject it.
 */
- (BOOL)shouldMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath;

/**
 *  @brief Called to determine whether a file or directory deletion should proceed.
 *
 *  @discussion This hook is invoked before the item is removed from disk. Use it to enforce
 *  custom authorization rules, such as protecting certain files or directories from deletion.
 *
 *  If this method returns @c NO, the deletion is rejected with an HTTP 403 Forbidden response.
 *
 *  The default implementation returns @c YES.
 *
 *  @note For directories, the deletion is recursive -- all contained items are also removed.
 *
 *  @param path The absolute file system path of the item to be deleted.
 *
 *  @return @c YES to allow the deletion, or @c NO to reject it.
 */
- (BOOL)shouldDeleteItemAtPath:(NSString*)path;

/**
 *  @brief Called to determine whether a new directory creation should proceed.
 *
 *  @discussion This hook is invoked before the directory is created on disk. Use it to enforce
 *  custom authorization rules, such as limiting directory nesting depth or restricting
 *  directory names.
 *
 *  If this method returns @c NO, the creation is rejected with an HTTP 403 Forbidden response.
 *
 *  The default implementation returns @c YES.
 *
 *  @param path The absolute file system path where the directory will be created. This path
 *              has already been de-duplicated if a directory with the same name already exists.
 *
 *  @return @c YES to allow the directory creation, or @c NO to reject it.
 */
- (BOOL)shouldCreateDirectoryAtPath:(NSString*)path;

@end

NS_ASSUME_NONNULL_END
