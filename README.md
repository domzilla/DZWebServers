Overview
========

DZWebServers is based on GCDWebserver by Pierre-Olivier Latour.

DZWebServers is a modern and lightweight GCD based HTTP 1.1 server designed to be embedded in iOS and macOS apps. It was written from scratch with the following goals in mind:
* Elegant and easy to use architecture with only 4 core classes: server, connection, request and response (see "Understanding DZWebServers's Architecture" below)
* Well designed API with fully documented headers for easy integration and customization
* Entirely built with an event-driven design using [Grand Central Dispatch](http://en.wikipedia.org/wiki/Grand_Central_Dispatch) for best performance and concurrency
* No dependencies on third-party source code
* Available under a friendly [New BSD License](LICENSE)

Extra built-in features:
* Allow implementation of fully asynchronous handlers of incoming HTTP requests
* Minimize memory usage with disk streaming of large HTTP request or response bodies
* Parser for [web forms](http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4) submitted using "application/x-www-form-urlencoded" or "multipart/form-data" encodings (including file uploads)
* [JSON](http://www.json.org/) parsing and serialization for request and response HTTP bodies
* [Chunked transfer encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding) for request and response HTTP bodies
* [HTTP compression](https://en.wikipedia.org/wiki/HTTP_compression) with gzip for request and response HTTP bodies
* [HTTP range](https://en.wikipedia.org/wiki/Byte_serving) support for requests of local files
* [Basic](https://en.wikipedia.org/wiki/Basic_access_authentication) and [Digest Access](https://en.wikipedia.org/wiki/Digest_access_authentication) authentications for password protection
* Automatically handle transitions between foreground, background and suspended modes in iOS apps
* Full support for both IPv4 and IPv6
* NAT port mapping (IPv4 only)

Included extensions:
* DZWebUploader: subclass of ```DZWebServer``` that implements an interface for uploading and downloading files using a web browser
* DZWebDAVServer: subclass of ```DZWebServer``` that implements a class 1 [WebDAV](https://en.wikipedia.org/wiki/WebDAV) server (with partial class 2 support for macOS Finder)

What's not supported (but not really required from an embedded HTTP server):
* Keep-alive connections
* HTTPS
