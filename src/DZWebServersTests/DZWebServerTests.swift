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

// MARK: Root Suite

@Suite("DZWebServer", .serialized, .tags(.server))
struct DZWebServerTests {
    // MARK: Lifecycle

    @Suite("Lifecycle", .serialized, .tags(.properties))
    struct Lifecycle {
        @Test("Newly created server is idle")
        func newServerIsIdle() {
            let server = DZWebServer()

            #expect(server.isRunning == false)
            #expect(server.port == 0)
            #expect(server.serverURL == nil)
            #expect(server.bonjourName == nil)
            #expect(server.bonjourType == nil)
        }

        @Test("Starting with port 0 assigns an ephemeral port and sets running to true")
        func startWithPortZeroAssignsEphemeralPort() throws {
            let server = DZWebServer()

            try TestSupport.start(server)
            defer { server.stop() }

            #expect(server.isRunning == true)
            #expect(server.port > 0)
        }

        @Test("Stopping the server resets running and port")
        func stopResetsRunningAndPort() throws {
            let server = DZWebServer()

            try TestSupport.start(server)
            server.stop()

            #expect(server.isRunning == false)
            #expect(server.port == 0)
            #expect(server.serverURL == nil)
        }

        @Test("Port option sets the listening port")
        func portOptionSetsListeningPort() throws {
            // Borrow a port the OS just handed out instead of hard-coding one that parallel runs could hold.
            let probe = DZWebServer()
            try TestSupport.start(probe)
            let freePort = probe.port
            probe.stop()

            let server = DZWebServer()
            var options = TestSupport.localhostOptions
            options[DZWebServerOption_Port] = freePort

            try server.start(options: options)
            defer { server.stop() }

            #expect(server.port == freePort)
        }

        @Test("Server can be started and stopped multiple times")
        func startStopMultipleTimes() async throws {
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
                try TestSupport.start(server)
                defer { server.stop() }

                #expect(server.isRunning == true)
                #expect(server.port > 0)

                let (_, data, _) = try await TestSupport.sendRequest(
                    url: #require(server.serverURL?.appendingPathComponent("ping"))
                )
                #expect(String(data: data, encoding: .utf8) == "pong")
            }
            #expect(server.isRunning == false)
        }
    }

    // MARK: Server URLs

    @Suite("Server URLs", .serialized, .tags(.properties))
    struct ServerURLs {
        @Test("serverURL is http://localhost:<port>/ when bound to localhost")
        func serverURLUsesLocalhostAndPort() throws {
            let server = DZWebServer()

            try TestSupport.start(server)
            defer { server.stop() }

            let url = try #require(server.serverURL)
            #expect(url.absoluteString == "http://localhost:\(server.port)/")
        }

        @Test("bonjourServerURL is nil when Bonjour is disabled")
        func bonjourServerURLIsNilWhenDisabled() throws {
            let server = DZWebServer()

            try TestSupport.start(server)
            defer { server.stop() }

            #expect(server.bonjourServerURL == nil)
        }

        @Test("publicServerURL is nil when NAT mapping is not requested")
        func publicServerURLIsNilByDefault() throws {
            let server = DZWebServer()

            try TestSupport.start(server)
            defer { server.stop() }

            #expect(server.publicServerURL == nil)
        }
    }

    // MARK: Handlers

    @Suite("Handlers", .serialized, .tags(.integration))
    struct Handlers {
        @Test("removeAllHandlers clears registered handlers")
        func removeAllHandlersClearsHandlers() async throws {
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

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("test"))
            )
            #expect(statusCode == 501)
        }

        @Test("Request to unhandled path produces 501 Not Implemented")
        func noMatchingHandlerProduces501() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/exists",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "ok")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("does-not-exist"))
            )
            #expect(statusCode == 501)
        }

        @Test("Handler is routed by HTTP method", arguments: ["GET", "POST", "PUT", "DELETE"])
        func handlerIsRoutedByMethod(method: String) async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: method,
                path: "/resource",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    DZWebServerDataResponse(text: "\(request.method) \(request.path)")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                method: method,
                url: #require(server.serverURL?.appendingPathComponent("resource"))
            )

            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "\(method) /resource")
        }

        @Test("Default handler for GET responds to any GET path")
        func defaultHandlerForGETRespondsToAnyPath() async throws {
            let server = DZWebServer()
            server.addDefaultHandler(
                forMethod: "GET",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    DZWebServerDataResponse(text: "default: \(request.path)")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            for path in ["any/path", "other"] {
                let (statusCode, data, _) = try await TestSupport.sendRequest(
                    url: #require(server.serverURL?.appendingPathComponent(path))
                )
                #expect(statusCode == 200)
                #expect(String(data: data, encoding: .utf8) == "default: /\(path)")
            }
        }

        @Test("Last added handler wins (LIFO order)")
        func lastAddedHandlerWinsLIFO() async throws {
            let server = DZWebServer()
            for text in ["first", "second"] {
                server.addHandler(
                    forMethod: "GET",
                    path: "/test",
                    request: DZWebServerRequest.self,
                    processBlock: { _ in
                        DZWebServerDataResponse(text: text)
                    }
                )
            }

            try TestSupport.start(server)
            defer { server.stop() }

            let (_, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("test"))
            )
            #expect(String(data: data, encoding: .utf8) == "second")
        }

        @Test("Handler returning nil produces 500 Internal Server Error")
        func handlerReturningNilProduces500() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/nil",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    nil
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("nil"))
            )
            #expect(statusCode == 500)
        }

        @Test("Custom match block handler is invoked correctly")
        func customMatchBlockHandlerWorks() async throws {
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

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("custom/route"))
            )
            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "custom-matched")

            let (unmatchedStatusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("other"))
            )
            #expect(unmatchedStatusCode == 501)
        }

        @Test("Response with custom status code sends that status")
        func customStatusCode() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/created",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    let response = DZWebServerDataResponse(text: "created")
                    response?.statusCode = 201
                    return response
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("created"))
            )
            #expect(statusCode == 201)
        }
    }

    // MARK: Regex Handlers

    @Suite("Regex Handlers", .serialized, .tags(.integration))
    struct RegexHandlers {
        @Test("Regex handler responds to matching paths and captures groups")
        func regexHandlerMatchesAndCapturesGroups() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                pathRegex: "/api/([a-z]+)/([0-9]+)",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    let captures = request.attribute(forKey: DZWebServerRequestAttribute_RegexCaptures)
                        as? [String] ?? []
                    return DZWebServerDataResponse(text: "captures:\(captures.joined(separator: ","))")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("api/users/99"))
            )
            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "captures:users,99")
        }

        @Test("Regex handler does not match non-matching paths")
        func regexHandlerDoesNotMatchNonMatchingPath() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                pathRegex: "/api/[0-9]+",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "matched")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("api/abc"))
            )
            #expect(statusCode == 501)
        }
    }

    // MARK: GET Handlers

    @Suite("GET Handlers", .serialized, .tags(.integration))
    struct GETHandlers {
        @Test("Static data handler serves correct data and content type")
        func staticDataHandlerServesData() async throws {
            let server = DZWebServer()
            let payload = Data("static-payload".utf8)

            server.addGETHandler(
                forPath: "/static",
                staticData: payload,
                contentType: "text/plain",
                cacheAge: 0
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("static"))
            )
            #expect(statusCode == 200)
            #expect(data == payload)
            #expect(response.value(forHTTPHeaderField: "Content-Type") == "text/plain")
        }

        @Test("Static data handler with cacheAge sets Cache-Control header")
        func staticDataHandlerCacheControl() async throws {
            let server = DZWebServer()

            server.addGETHandler(
                forPath: "/cached",
                staticData: Data("cached".utf8),
                contentType: "text/plain",
                cacheAge: 3600
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (_, _, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("cached"))
            )
            #expect(response.value(forHTTPHeaderField: "Cache-Control") == "max-age=3600, public")
        }

        @Test("File path handler serves file contents inline")
        func filePathHandlerServesFileContents() async throws {
            let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebServerTests")
            defer { try? FileManager.default.removeItem(atPath: directory) }
            let filePath = (directory as NSString).appendingPathComponent("file.txt")
            try "file-content-for-test".write(toFile: filePath, atomically: true, encoding: .utf8)

            let server = DZWebServer()
            server.addGETHandler(
                forPath: "/file",
                filePath: filePath,
                isAttachment: false,
                cacheAge: 0,
                allowRangeRequests: false
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("file"))
            )
            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "file-content-for-test")
            #expect(response.value(forHTTPHeaderField: "Content-Disposition") == nil)
        }

        @Test("File path handler with attachment sets Content-Disposition header")
        func filePathHandlerAttachmentSetsContentDisposition() async throws {
            let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebServerTests")
            defer { try? FileManager.default.removeItem(atPath: directory) }
            let filePath = (directory as NSString).appendingPathComponent("attachment.txt")
            try "attachment-content".write(toFile: filePath, atomically: true, encoding: .utf8)

            let server = DZWebServer()
            server.addGETHandler(
                forPath: "/download",
                filePath: filePath,
                isAttachment: true,
                cacheAge: 0,
                allowRangeRequests: false
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("download"))
            )
            #expect(statusCode == 200)
            let disposition = try #require(response.value(forHTTPHeaderField: "Content-Disposition"))
            #expect(disposition.hasPrefix("attachment"))
            #expect(disposition.contains("attachment.txt"))
        }

        @Test("Directory handler serves files from directory")
        func directoryHandlerServesFiles() async throws {
            let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebServerTests")
            defer { try? FileManager.default.removeItem(atPath: directory) }
            try "dir-file-content".write(
                toFile: (directory as NSString).appendingPathComponent("hello.txt"),
                atomically: true,
                encoding: .utf8
            )

            let server = DZWebServer()
            server.addGETHandler(
                forBasePath: "/files/",
                directoryPath: directory,
                indexFilename: nil,
                cacheAge: 0,
                allowRangeRequests: false
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("files/hello.txt"))
            )
            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "dir-file-content")
        }

        @Test("Directory handler serves index file when configured")
        func directoryHandlerServesIndexFile() async throws {
            let directory = try TestSupport.makeTemporaryDirectory(prefix: "DZWebServerTests")
            defer { try? FileManager.default.removeItem(atPath: directory) }
            try "<html>Index</html>".write(
                toFile: (directory as NSString).appendingPathComponent("index.html"),
                atomically: true,
                encoding: .utf8
            )

            let server = DZWebServer()
            server.addGETHandler(
                forBasePath: "/site/",
                directoryPath: directory,
                indexFilename: "index.html",
                cacheAge: 0,
                allowRangeRequests: false
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("site/"))
            )
            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "<html>Index</html>")
        }
    }

    // MARK: Server Options

    @Suite("Server Options", .serialized, .tags(.integration))
    struct ServerOptions {
        @Test("ServerName option sets the Server response header")
        func serverNameOptionSetsHeader() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/name-test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "ok")
                }
            )

            var options = TestSupport.localhostOptions
            options[DZWebServerOption_ServerName] = "TestServer/1.0"

            try TestSupport.start(server, options: options)
            defer { server.stop() }

            let (_, _, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("name-test"))
            )
            #expect(response.value(forHTTPHeaderField: "Server") == "TestServer/1.0")
        }

        @Test("HEAD request is mapped to GET when AutomaticallyMapHEADToGET is enabled")
        func headRequestAutoMappedToGET() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/head-test",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "body-content")
                }
            )

            var options = TestSupport.localhostOptions
            options[DZWebServerOption_AutomaticallyMapHEADToGET] = true

            try TestSupport.start(server, options: options)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                method: "HEAD",
                url: #require(server.serverURL?.appendingPathComponent("head-test"))
            )
            #expect(statusCode == 200)
            #expect(data.isEmpty)
        }
    }

    // MARK: Authentication

    @Suite("Authentication", .serialized, .tags(.authentication, .integration))
    struct Authentication {
        @Test("Basic auth with correct credentials returns 200")
        func basicAuthCorrectCredentials() async throws {
            let server = try self.makeProtectedServer(method: DZWebServerAuthenticationMethod_Basic)
            defer { server.stop() }

            let credentials = Data("admin:password123".utf8).base64EncodedString()
            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("protected")),
                headers: ["Authorization": "Basic \(credentials)"]
            )
            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "secret-content")
        }

        @Test("Basic auth with wrong credentials returns 401")
        func basicAuthWrongCredentials() async throws {
            let server = try self.makeProtectedServer(method: DZWebServerAuthenticationMethod_Basic)
            defer { server.stop() }

            let credentials = Data("admin:wrongpass".utf8).base64EncodedString()
            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("protected")),
                headers: ["Authorization": "Basic \(credentials)"]
            )
            #expect(statusCode == 401)
        }

        @Test("Basic auth with no credentials returns 401 with a Basic challenge")
        func basicAuthNoCredentials() async throws {
            let server = try self.makeProtectedServer(method: DZWebServerAuthenticationMethod_Basic)
            defer { server.stop() }

            let (statusCode, _, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("protected"))
            )
            #expect(statusCode == 401)
            #expect(response.value(forHTTPHeaderField: "WWW-Authenticate")?.hasPrefix("Basic") == true)
        }

        @Test("Digest auth with correct credentials returns 200")
        func digestAuthCorrectCredentials() async throws {
            let server = try self.makeProtectedServer(method: DZWebServerAuthenticationMethod_DigestAccess)
            defer { server.stop() }

            let delegate = DigestAuthDelegate(user: "admin", password: "password123")
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            defer { session.invalidateAndCancel() }

            let url = try #require(server.serverURL?.appendingPathComponent("protected"))
            let (data, response) = try await session.data(for: URLRequest(url: url))
            let httpResponse = try #require(response as? HTTPURLResponse)

            #expect(httpResponse.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "secret-content")
            #expect(delegate.challengeMethod == NSURLAuthenticationMethodHTTPDigest)
        }

        /// The caller must call `stop()`.
        private func makeProtectedServer(method: String) throws -> DZWebServer {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/protected",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(text: "secret-content")
                }
            )

            var options = TestSupport.localhostOptions
            options[DZWebServerOption_AuthenticationMethod] = method
            options[DZWebServerOption_AuthenticationAccounts] = ["admin": "password123"]
            try TestSupport.start(server, options: options)
            return server
        }
    }

    // MARK: Edge Cases

    @Suite("Edge Cases", .serialized, .tags(.integration))
    struct EdgeCases {
        @Test("Multiple simultaneous requests are handled correctly")
        func multipleSimultaneousRequests() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/concurrent",
                request: DZWebServerRequest.self,
                processBlock: { request in
                    DZWebServerDataResponse(text: "response-\(request.query?["id"] ?? "unknown")")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let baseURL = try #require(server.serverURL)
            let urls = try (0..<10).map { index in
                try #require(URL(string: "\(baseURL.absoluteString)concurrent?id=\(index)"))
            }

            let bodies = try await withThrowingTaskGroup(of: (Int, String?).self) { group in
                for (index, url) in urls.enumerated() {
                    group.addTask {
                        let (_, data, _) = try await TestSupport.sendRequest(url: url)
                        return (index, String(data: data, encoding: .utf8))
                    }
                }
                var bodies: [Int: String] = [:]
                for try await (index, body) in group {
                    bodies[index] = body
                }
                return bodies
            }

            #expect(bodies.count == urls.count)
            for index in urls.indices {
                #expect(bodies[index] == "response-\(index)")
            }
        }

        @Test("Large request body is handled correctly")
        func largeRequestBody() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/large",
                request: DZWebServerDataRequest.self,
                processBlock: { request in
                    let dataRequest = request as? DZWebServerDataRequest
                    return DZWebServerDataResponse(
                        data: dataRequest?.data ?? Data(),
                        contentType: "application/octet-stream"
                    )
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let largeData = Data((0..<1_000_000).map { UInt8(truncatingIfNeeded: $0) })
            let (statusCode, data, _) = try await TestSupport.sendRequest(
                method: "POST",
                url: #require(server.serverURL?.appendingPathComponent("large")),
                body: largeData,
                headers: ["Content-Type": "application/octet-stream"]
            )
            #expect(statusCode == 200)
            #expect(data == largeData)
        }

        @Test("Large response body is sent correctly")
        func largeResponseBody() async throws {
            let responseData = Data((0..<1_000_000).map { UInt8(truncatingIfNeeded: $0 &* 7) })
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/large-response",
                request: DZWebServerRequest.self,
                processBlock: { _ in
                    DZWebServerDataResponse(data: responseData, contentType: "application/octet-stream")
                }
            )

            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appendingPathComponent("large-response"))
            )
            #expect(statusCode == 200)
            #expect(data == responseData)
        }
    }

    // MARK: Delegate

    @Suite("Delegate", .serialized)
    struct DelegateTests {
        @Test("Delegate is notified when the server starts and stops")
        func delegateReceivesLifecycleEvents() async throws {
            let server = DZWebServer()
            let delegate = TestServerDelegate()
            server.delegate = delegate

            try TestSupport.start(server)
            // The callbacks are dispatched async to the main queue; a MainActor hop runs after them (FIFO).
            await MainActor.run {}
            #expect(delegate.didStartCalled == true)
            #expect(delegate.didStopCalled == false)

            server.stop()
            await MainActor.run {}
            #expect(delegate.didStopCalled == true)
        }
    }
}

// MARK: Test Doubles

private final class TestServerDelegate: NSObject, DZWebServerDelegate {
    var didStartCalled = false
    var didStopCalled = false

    func webServerDidStart(_: DZWebServer) {
        self.didStartCalled = true
    }

    func webServerDidStop(_: DZWebServer) {
        self.didStopCalled = true
    }
}

private final class DigestAuthDelegate: NSObject, URLSessionTaskDelegate {
    let user: String
    let password: String
    private(set) var challengeMethod: String?

    init(user: String, password: String) {
        self.user = user
        self.password = password
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        self.challengeMethod = challenge.protectionSpace.authenticationMethod
        // Answer once; a rejected credential would otherwise be retried forever.
        guard challenge.previousFailureCount == 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(user: self.user, password: self.password, persistence: .none))
    }
}
