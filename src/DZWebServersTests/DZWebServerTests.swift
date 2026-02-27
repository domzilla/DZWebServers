//
//  DZWebServerTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

// MARK: - Helper

/// Standard options for starting a localhost-only test server on an ephemeral port.
private let localhostOptions: [String: Any] = [
    DZWebServerOption_Port: 0,
    DZWebServerOption_BindToLocalhost: true,
    DZWebServerOption_AutomaticallyMapHEADToGET: true,
]

/// Creates a URLRequest with the given HTTP method targeting a path on the server.
private func request(
    for server: DZWebServer,
    method: String = "GET",
    path: String,
    body: Data? = nil,
    headers: [String: String] = [:]
)
    -> URLRequest
{
    let url = server.serverURL!.appendingPathComponent(path)
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
    return request
}

/// URLSession configured to skip caches and redirects for deterministic test behavior.
private let testSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return URLSession(configuration: config)
}()

// MARK: - Root Suite

@Suite("DZWebServer", .serialized, .tags(.server))
struct DZWebServerTests {
    init() {
        DZWebServerTestSetup.ensureInitialized()
    }

    // MARK: - Lifecycle

    @Suite("Lifecycle", .serialized, .tags(.properties))
    struct Lifecycle {
        @Test("Newly created server is not running")
        func newServerIsNotRunning() {
            let server = DZWebServer()

            #expect(server.isRunning == false)
        }

        @Test("Newly created server reports port 0")
        func newServerPortIsZero() {
            let server = DZWebServer()

            #expect(server.port == 0)
        }

        @Test("Newly created server has nil delegate")
        func newServerDelegateIsNil() {
            let server = DZWebServer()

            #expect(server.delegate == nil)
        }

        @Test("Newly created server has nil bonjourName")
        func newServerBonjourNameIsNil() {
            let server = DZWebServer()

            #expect(server.bonjourName == nil)
        }

        @Test("Newly created server has nil bonjourType")
        func newServerBonjourTypeIsNil() {
            let server = DZWebServer()

            #expect(server.bonjourType == nil)
        }

        @Test("Starting with port 0 assigns an ephemeral port and sets running to true")
        func startWithPortZeroAssignsEphemeralPort() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            #expect(server.isRunning == true)
            #expect(server.port > 0)
        }

        @Test("Stopping the server resets running and port")
        func stopResetsRunningAndPort() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            server.stop()

            #expect(server.isRunning == false)
            #expect(server.port == 0)
        }

        @Test("Starting with a specific port uses that port")
        func startWithSpecificPort() throws {
            let server = DZWebServer()
            let options: [String: Any] = [
                DZWebServerOption_Port: 18273,
                DZWebServerOption_BindToLocalhost: true,
                DZWebServerOption_AutomaticallyMapHEADToGET: true,
            ]

            try server.start(options: options)
            defer { server.stop() }

            #expect(server.port == 18273)
        }

        @Test("Binding to localhost makes serverURL use localhost hostname")
        func bindToLocalhostSetsLocalhostURL() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let url = try #require(server.serverURL)
            #expect(url.host == "localhost")
        }
    }

    // MARK: - Server URLs

    @Suite("Server URLs", .serialized, .tags(.properties))
    struct ServerURLs {
        @Test("serverURL is nil when server is not running")
        func serverURLIsNilWhenStopped() {
            let server = DZWebServer()

            #expect(server.serverURL == nil)
        }

        @Test("serverURL is non-nil when server is running")
        func serverURLIsNonNilWhenRunning() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            #expect(server.serverURL != nil)
        }

        @Test("serverURL contains the correct port")
        func serverURLContainsCorrectPort() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let url = try #require(server.serverURL)
            #expect(url.port == Int(server.port))
        }

        @Test("bonjourServerURL is nil when Bonjour is disabled")
        func bonjourServerURLIsNilWhenDisabled() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            #expect(server.bonjourServerURL == nil)
        }

        @Test("publicServerURL is nil when NAT mapping is not requested")
        func publicServerURLIsNilByDefault() throws {
            let server = DZWebServer()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            #expect(server.publicServerURL == nil)
        }
    }

    // MARK: - Handler Management

    @Suite("Handler Management")
    struct HandlerManagement {
        @Test("removeAllHandlers clears registered handlers")
        func removeAllHandlersClearsHandlers() throws {
            let server = DZWebServer()

            server.addHandler(
                forMethod: "GET",
                path: "/test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "Hello")
                }
            )

            server.removeAllHandlers()

            try server.start(options: localhostOptions)
            defer { server.stop() }

            // With no handlers, a request should return 501 Not Implemented
            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("test"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 405 || httpResponse.statusCode == 501)
        }
    }

    // MARK: - Handlers and Request Handling (Integration)

    @Suite("Handlers and Request Handling", .serialized, .tags(.integration))
    struct HandlersAndRequestHandling {
        @Test("Handler for specific path responds to matching requests")
        func handlerForPathRespondsToMatchingPath() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/hello",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "Hello, World!")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("hello"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)
            let body = String(data: data, encoding: .utf8)

            #expect(httpResponse.statusCode == 200)
            #expect(body == "Hello, World!")
        }

        @Test("Default handler for GET responds to any GET path")
        func defaultHandlerForGETRespondsToAnyPath() throws {
            let server = DZWebServer()
            server.addDefaultHandler(
                forMethod: "GET",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    DZWebServerDataResponse(text: "default: \(request.path)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data1, response1) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("any/path"))
            )
            let http1 = try #require(response1 as? HTTPURLResponse)
            #expect(http1.statusCode == 200)
            #expect(String(data: data1, encoding: .utf8) == "default: /any/path")

            let (data2, response2) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("other"))
            )
            let http2 = try #require(response2 as? HTTPURLResponse)
            #expect(http2.statusCode == 200)
            #expect(String(data: data2, encoding: .utf8) == "default: /other")
        }

        @Test("Regex handler responds to matching paths and captures groups")
        func regexHandlerMatchesAndCapturesGroups() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                pathRegex: "/items/([0-9]+)/detail",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    let captures = request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures)
                        as? [String] ?? []
                    let id = captures.first ?? "none"
                    return DZWebServerDataResponse(text: "item:\(id)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("items/42/detail"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "item:42")
        }

        @Test("Last added handler wins (LIFO order)")
        func lastAddedHandlerWinsLIFO() throws {
            let server = DZWebServer()

            // First handler -- added earlier, lower priority
            server.addHandler(
                forMethod: "GET",
                path: "/test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "first")
                }
            )

            // Second handler -- added later, higher priority (LIFO)
            server.addHandler(
                forMethod: "GET",
                path: "/test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "second")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, _) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("test"))
            )
            #expect(String(data: data, encoding: .utf8) == "second")
        }

        @Test("Handler returning nil produces 500 Internal Server Error")
        func handlerReturningNilProduces500() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/nil",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    nil
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("nil"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)
            #expect(httpResponse.statusCode == 500)
        }

        @Test("Request to unhandled path produces 405 or 501 response")
        func noMatchingHandlerProducesErrorStatus() throws {
            let server = DZWebServer()
            // Add handler for a specific path only
            server.addHandler(
                forMethod: "GET",
                path: "/exists",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "ok")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("does-not-exist"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)
            // Framework returns either 405 (Method Not Allowed) or 501 (Not Implemented)
            #expect(httpResponse.statusCode == 405 || httpResponse.statusCode == 501)
        }

        @Test("Async process block produces correct response")
        func asyncProcessBlockRespondsCorrectly() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/async",
                request: DZWebServerRequest.self,
                asyncProcessBlock: { _, completionBlock in
                    completionBlock(DZWebServerDataResponse(text: "async-response"))
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("async"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "async-response")
        }

        @Test("Custom match block handler is invoked correctly")
        func customMatchBlockHandlerWorks() throws {
            let server = DZWebServer()
            server.addHandler(
                match: { method, url, headers, path, query in
                    if method == "GET", path.hasPrefix("/custom") {
                        return DZWebServerRequest(
                            method: method,
                            url: url,
                            headers: headers,
                            path: path,
                            query: query
                        )
                    }
                    return nil
                },
                processBlock: { _ in
                    DZWebServerDataResponse(text: "custom-matched")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("custom/route"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "custom-matched")
        }
    }

    // MARK: - HTTP Methods

    @Suite("HTTP Methods", .serialized, .tags(.integration))
    struct HTTPMethods {
        @Test("GET request is handled correctly")
        func getRequestHandled() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/resource",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "get-ok")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("resource"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "get-ok")
        }

        @Test("POST request is handled correctly")
        func postRequestHandled() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/submit",
                request: DZWebServerDataRequest.self,
                processBlock: { request in
                    let dataRequest = request as! DZWebServerDataRequest
                    let body = String(data: dataRequest.data, encoding: .utf8) ?? ""
                    return DZWebServerDataResponse(text: "received:\(body)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let bodyData = "payload".data(using: .utf8)!
            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("submit")))
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = bodyData
            urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

            let (data, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "received:payload")
        }

        @Test("PUT request is handled correctly")
        func putRequestHandled() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "PUT",
                path: "/update",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "put-ok")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("update")))
            urlRequest.httpMethod = "PUT"

            let (data, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "put-ok")
        }

        @Test("DELETE request is handled correctly")
        func deleteRequestHandled() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "DELETE",
                path: "/remove",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "delete-ok")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("remove")))
            urlRequest.httpMethod = "DELETE"

            let (data, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "delete-ok")
        }

        @Test("HEAD request is automatically mapped to GET when option is enabled")
        func headRequestAutoMappedToGET() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/head-test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "body-content")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("head-test")))
            urlRequest.httpMethod = "HEAD"

            let (data, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            // HEAD must return 200 but with no body content
            #expect(httpResponse.statusCode == 200)
            #expect(data.isEmpty)
        }
    }

    // MARK: - GET Handlers

    @Suite("GET Handlers", .serialized, .tags(.integration))
    struct GETHandlers {
        @Test("Static data handler serves correct data and content type")
        func staticDataHandlerServesData() throws {
            let server = DZWebServer()
            let payload = "static-payload".data(using: .utf8)!

            server.addGETHandler(
                forPath: "/static",
                staticData: payload,
                contentType: "text/plain",
                cacheAge: 0
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("static"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(data == payload)
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            #expect(contentType?.hasPrefix("text/plain") == true)
        }

        @Test("File path handler serves file contents")
        func filePathHandlerServesFileContents() throws {
            let server = DZWebServer()
            let tempDir = NSTemporaryDirectory()
            let filePath = (tempDir as NSString).appendingPathComponent("dz_test_file.txt")
            let fileContent = "file-content-for-test"

            try fileContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: filePath) }

            server.addGETHandler(
                forPath: "/file",
                filePath: filePath,
                isAttachment: false,
                cacheAge: 0,
                allowRangeRequests: false
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("file"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == fileContent)
        }

        @Test("File path handler with attachment sets Content-Disposition header")
        func filePathHandlerAttachmentSetsContentDisposition() throws {
            let server = DZWebServer()
            let tempDir = NSTemporaryDirectory()
            let filePath = (tempDir as NSString).appendingPathComponent("dz_attachment.txt")

            try "attachment-content".write(toFile: filePath, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: filePath) }

            server.addGETHandler(
                forPath: "/download",
                filePath: filePath,
                isAttachment: true,
                cacheAge: 0,
                allowRangeRequests: false
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("download"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            let disposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition")
            #expect(disposition?.contains("attachment") == true)
        }

        @Test("Directory handler serves files from directory")
        func directoryHandlerServesFiles() throws {
            let server = DZWebServer()
            let tempDir = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dz_dir_test")

            try FileManager.default.createDirectory(
                atPath: tempDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            let innerFilePath = (tempDir as NSString).appendingPathComponent("hello.txt")
            try "dir-file-content".write(toFile: innerFilePath, atomically: true, encoding: .utf8)

            server.addGETHandler(
                forBasePath: "/files/",
                directoryPath: tempDir,
                indexFilename: nil,
                cacheAge: 0,
                allowRangeRequests: false
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("files/hello.txt"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "dir-file-content")
        }

        @Test("Directory handler serves index file when configured")
        func directoryHandlerServesIndexFile() throws {
            let server = DZWebServer()
            let tempDir = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("dz_index_test")

            try FileManager.default.createDirectory(
                atPath: tempDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            let indexPath = (tempDir as NSString).appendingPathComponent("index.html")
            try "<html>Index</html>".write(toFile: indexPath, atomically: true, encoding: .utf8)

            server.addGETHandler(
                forBasePath: "/site/",
                directoryPath: tempDir,
                indexFilename: "index.html",
                cacheAge: 0,
                allowRangeRequests: false
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("site/"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "<html>Index</html>")
        }

        @Test("Static data handler with cacheAge sets Cache-Control header")
        func staticDataHandlerCacheControl() throws {
            let server = DZWebServer()
            let payload = "cached".data(using: .utf8)!

            server.addGETHandler(
                forPath: "/cached",
                staticData: payload,
                contentType: "text/plain",
                cacheAge: 3600
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("cached"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            let cacheControl = httpResponse.value(forHTTPHeaderField: "Cache-Control")
            #expect(cacheControl?.contains("max-age=3600") == true)
        }
    }

    // MARK: - Server Options

    @Suite("Server Options", .serialized, .tags(.integration))
    struct ServerOptions {
        @Test("ServerName option sets the Server response header")
        func serverNameOptionSetsHeader() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/name-test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "ok")
                }
            )

            var options = localhostOptions
            options[DZWebServerOption_ServerName] = "TestServer/1.0"

            try server.start(options: options)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("name-test"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            let serverHeader = httpResponse.value(forHTTPHeaderField: "Server")
            #expect(serverHeader == "TestServer/1.0")
        }

        @Test("Port option sets the listening port")
        func portOptionSetsListeningPort() throws {
            let server = DZWebServer()

            var options = localhostOptions
            options[DZWebServerOption_Port] = 28471

            try server.start(options: options)
            defer { server.stop() }

            #expect(server.port == 28471)
        }

        @Test("BindToLocalhost option restricts server to localhost")
        func bindToLocalhostRestrictsToLocalhost() throws {
            let server = DZWebServer()

            var options = localhostOptions
            options[DZWebServerOption_BindToLocalhost] = true

            try server.start(options: options)
            defer { server.stop() }

            let url = try #require(server.serverURL)
            #expect(url.host == "localhost")
        }
    }

    // NOTE: Logging tests removed — the log methods use C variadic macros
    // internally which can crash the Swift test runner process, and
    // setLogLevel modifies global state that affects all tests.

    // MARK: - Authentication

    @Suite("Authentication", .serialized, .tags(.authentication, .integration))
    struct Authentication {
        @Test("Basic auth with correct credentials returns 200")
        func basicAuthCorrectCredentials() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/protected",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "secret-content")
                }
            )

            var options = localhostOptions
            options[DZWebServerOption_AuthenticationMethod] = DZWebServerAuthenticationMethod_Basic
            options[DZWebServerOption_AuthenticationAccounts] = ["admin": "password123"]

            try server.start(options: options)
            defer { server.stop() }

            let credentials = "admin:password123".data(using: .utf8)!.base64EncodedString()
            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("protected")))
            urlRequest.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

            let (data, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "secret-content")
        }

        @Test("Basic auth with wrong credentials returns 401")
        func basicAuthWrongCredentials() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/protected",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "secret-content")
                }
            )

            var options = localhostOptions
            options[DZWebServerOption_AuthenticationMethod] = DZWebServerAuthenticationMethod_Basic
            options[DZWebServerOption_AuthenticationAccounts] = ["admin": "password123"]

            try server.start(options: options)
            defer { server.stop() }

            let wrongCredentials = "admin:wrongpass".data(using: .utf8)!.base64EncodedString()
            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("protected")))
            urlRequest.setValue("Basic \(wrongCredentials)", forHTTPHeaderField: "Authorization")

            let (_, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 401)
        }

        @Test("Basic auth with no credentials returns 401")
        func basicAuthNoCredentials() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/protected",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "secret-content")
                }
            )

            var options = localhostOptions
            options[DZWebServerOption_AuthenticationMethod] = DZWebServerAuthenticationMethod_Basic
            options[DZWebServerOption_AuthenticationAccounts] = ["admin": "password123"]

            try server.start(options: options)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("protected"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 401)
        }

        @Test("Digest auth with correct credentials returns 200")
        func digestAuthCorrectCredentials() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/digest-protected",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "digest-secret")
                }
            )

            var options = localhostOptions
            options[DZWebServerOption_AuthenticationMethod] = DZWebServerAuthenticationMethod_DigestAccess
            options[DZWebServerOption_AuthenticationAccounts] = ["user": "pass"]

            try server.start(options: options)
            defer { server.stop() }

            // URLSession handles Digest authentication automatically when a
            // credential is provided via the delegate or a ProtectionSpace
            let url = try #require(server.serverURL?.appendingPathComponent("digest-protected"))
            let protectedURL = try #require(URL(
                string: "http://user:pass@localhost:\(server.port)/digest-protected"
            ))

            // Use a custom session with a credential-providing delegate
            let delegate = DigestAuthDelegate(user: "user", password: "pass")
            let session = URLSession(
                configuration: .ephemeral,
                delegate: delegate,
                delegateQueue: nil
            )
            defer { session.invalidateAndCancel() }

            let urlRequest = URLRequest(url: url)
            let (_, response) = try awaitData(for: urlRequest, session: session)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
        }
    }

    // MARK: - JSON Responses

    @Suite("JSON Responses", .serialized, .tags(.integration))
    struct JSONResponses {
        @Test("Handler returning JSON data response has correct content type")
        func jsonResponseContentType() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/json",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(jsonObject: ["key": "value"])
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("json"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(contentType.contains("json"))

            let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
            #expect(json?["key"] == "value")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases", .serialized, .tags(.integration))
    struct EdgeCases {
        @Test("Multiple simultaneous requests are handled correctly")
        func multipleSimultaneousRequests() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/concurrent",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    let id = request.query?["id"] ?? "unknown"
                    return DZWebServerDataResponse(text: "response-\(id)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let requestCount = 10
            let baseURL = try #require(server.serverURL)

            // Issue multiple requests in parallel and collect results
            let group = DispatchGroup()
            let resultsLock = NSLock()
            var results: [String: String] = [:]

            for i in 0..<requestCount {
                group.enter()
                let url = try #require(URL(string: "\(baseURL.absoluteString)concurrent?id=\(i)"))
                let task = testSession.dataTask(with: url) { data, _, error in
                    defer { group.leave() }
                    guard let data, error == nil else { return }
                    let body = String(data: data, encoding: .utf8) ?? ""
                    resultsLock.lock()
                    results["\(i)"] = body
                    resultsLock.unlock()
                }
                task.resume()
            }

            let waitResult = group.wait(timeout: .now() + 30)
            #expect(waitResult == .success)
            #expect(results.count == requestCount)

            for i in 0..<requestCount {
                #expect(results["\(i)"] == "response-\(i)")
            }
        }

        @Test("Large request body is handled correctly")
        func largeRequestBody() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/large",
                request: DZWebServerDataRequest.self,
                processBlock: { request in
                    let dataRequest = request as! DZWebServerDataRequest
                    return DZWebServerDataResponse(text: "size:\(dataRequest.data.count)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            // Create a 1 MB payload
            let largeData = Data(repeating: 0x41, count: 1_000_000)
            var urlRequest = try URLRequest(url: #require(server.serverURL?.appendingPathComponent("large")))
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = largeData
            urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

            let (data, response) = try awaitData(for: urlRequest)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "size:1000000")
        }

        @Test("Large response body is sent correctly")
        func largeResponseBody() throws {
            let server = DZWebServer()
            let responseSize = 1_000_000
            let responseData = Data(repeating: 0x42, count: responseSize)

            server.addHandler(
                forMethod: "GET",
                path: "/large-response",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(
                        data: responseData,
                        contentType: "application/octet-stream"
                    )
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("large-response"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(data.count == responseSize)
            #expect(data == responseData)
        }

        @Test("Request with query parameters passes them to handler")
        func queryParametersAreAccessible() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/query",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    let name = request.query?["name"] ?? "missing"
                    let age = request.query?["age"] ?? "missing"
                    return DZWebServerDataResponse(text: "\(name):\(age)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let url = try #require(URL(
                string: "\(server.serverURL!.absoluteString)query?name=Dominic&age=30"
            ))
            let (data, response) = try awaitData(from: url)
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "Dominic:30")
        }

        @Test("Server can be started and stopped multiple times")
        func startStopMultipleTimes() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/ping",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "pong")
                }
            )

            for _ in 0..<3 {
                try server.start(options: localhostOptions)

                #expect(server.isRunning == true)
                #expect(server.port > 0)

                let (data, _) = try awaitData(
                    from: #require(server.serverURL?.appendingPathComponent("ping"))
                )
                #expect(String(data: data, encoding: .utf8) == "pong")

                server.stop()
                #expect(server.isRunning == false)
                #expect(server.port == 0)
            }
        }
    }

    // MARK: - Response Headers

    @Suite("Response Headers", .serialized, .tags(.integration))
    struct ResponseHeaders {
        @Test("Custom additional header is included in response")
        func customAdditionalHeader() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/custom-header",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    let response = DZWebServerDataResponse(text: "ok")!
                    response.setValue("custom-value", forAdditionalHeader: "X-Custom-Header")
                    return response
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("custom-header"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.value(forHTTPHeaderField: "X-Custom-Header") == "custom-value")
        }

        @Test("Response with custom status code sends that status")
        func customStatusCode() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/created",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    let response = DZWebServerDataResponse(text: "created")!
                    response.statusCode = 201
                    return response
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("created"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 201)
        }

        @Test("Empty response with no content type returns no body")
        func emptyResponseNoBody() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/empty",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerResponse()
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("empty"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(data.isEmpty)
        }
    }

    // MARK: - Regex Handlers

    @Suite("Regex Handlers", .serialized, .tags(.integration))
    struct RegexHandlers {
        @Test("Regex handler with multiple capture groups extracts all groups")
        func regexMultipleCaptureGroups() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                pathRegex: "/api/([a-z]+)/([0-9]+)",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    let captures = request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures)
                        as? [String] ?? []
                    let joined = captures.joined(separator: ",")
                    return DZWebServerDataResponse(text: "captures:\(joined)")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            let (data, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("api/users/99"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "captures:users,99")
        }

        @Test("Regex handler does not match non-matching paths")
        func regexHandlerDoesNotMatchNonMatchingPath() throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                pathRegex: "/api/[0-9]+",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "matched")
                }
            )

            try server.start(options: localhostOptions)
            defer { server.stop() }

            // Path with letters should not match
            let (_, response) = try awaitData(
                from: #require(server.serverURL?.appendingPathComponent("api/abc"))
            )
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 405 || httpResponse.statusCode == 501)
        }
    }

    // MARK: - Delegate

    @Suite("Delegate", .serialized, .tags(.server))
    struct DelegateTests {
        @Test("Delegate is called for server lifecycle events")
        func delegateReceivesLifecycleEvents() throws {
            let server = DZWebServer()
            let delegate = TestServerDelegate()
            server.delegate = delegate

            try server.start(options: localhostOptions)

            // Allow time for async delegate callback
            Thread.sleep(forTimeInterval: 0.5)

            server.stop()

            // Allow time for async delegate callback
            Thread.sleep(forTimeInterval: 0.5)

            #expect(delegate.didStartCalled == true)
            #expect(delegate.didStopCalled == true)
        }

        @Test("Assigning delegate property stores it")
        func delegateAssignment() {
            let server = DZWebServer()
            let delegate = TestServerDelegate()

            server.delegate = delegate
            #expect(server.delegate === delegate)

            server.delegate = nil
            #expect(server.delegate == nil)
        }
    }
}

// MARK: - Synchronous Helpers

/// Synchronously performs a URLSession data task and returns the result.
/// Uses a semaphore to bridge async URLSession to synchronous test code.
private func awaitData(
    from url: URL,
    session: URLSession = testSession
) throws
    -> (Data, URLResponse)
{
    try awaitData(for: URLRequest(url: url), session: session)
}

/// Synchronously performs a URLSession data task with a custom request.
private func awaitData(
    for request: URLRequest,
    session: URLSession = testSession
) throws
    -> (Data, URLResponse)
{
    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    var resultResponse: URLResponse?
    var resultError: Error?

    let task = session.dataTask(with: request) { data, response, error in
        resultData = data
        resultResponse = response
        resultError = error
        semaphore.signal()
    }
    task.resume()

    let waitResult = semaphore.wait(timeout: .now() + 30)
    guard waitResult == .success else {
        throw NSError(
            domain: "DZWebServerTests",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Request timed out"]
        )
    }
    if let error = resultError {
        throw error
    }
    guard let data = resultData, let response = resultResponse else {
        throw NSError(
            domain: "DZWebServerTests",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "No data or response received"]
        )
    }
    return (data, response)
}

// MARK: - Test Helpers

/// Simple delegate for testing DZWebServerDelegate callbacks.
private final class TestServerDelegate: NSObject, DZWebServerDelegate {
    var didStartCalled = false
    var didStopCalled = false
    var didConnectCalled = false
    var didDisconnectCalled = false

    func webServerDidStart(_: DZWebServer) {
        self.didStartCalled = true
    }

    func webServerDidStop(_: DZWebServer) {
        self.didStopCalled = true
    }

    func webServerDidConnect(_: DZWebServer) {
        self.didConnectCalled = true
    }

    func webServerDidDisconnect(_: DZWebServer) {
        self.didDisconnectCalled = true
    }
}

/// URLSession delegate that provides credentials for Digest authentication challenges.
private final class DigestAuthDelegate: NSObject, URLSessionTaskDelegate {
    let user: String
    let password: String

    init(user: String, password: String) {
        self.user = user
        self.password = password
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive _: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let credential = URLCredential(
            user: self.user,
            password: self.password,
            persistence: .forSession
        )
        completionHandler(.useCredential, credential)
    }
}
