//
//  DZWebServerConnectionTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

// MARK: Root Suite

@Suite("DZWebServerConnection", .serialized, .tags(.connection, .integration))
struct DZWebServerConnectionTests {
    // MARK: Request Parsing

    @Suite("Request Parsing")
    struct RequestParsing {
        @Test("POST body is read completely and passed to the handler")
        func postRequestBodyIsRead() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "POST",
                path: "/echo",
                request: DZWebServerDataRequest.self
            ) { request in
                let dataRequest = request as? DZWebServerDataRequest
                return DZWebServerDataResponse(
                    data: dataRequest?.data ?? Data(),
                    contentType: "application/octet-stream"
                )
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let sentBody = Data("Echo this back".utf8)
            let (statusCode, data, _) = try await TestSupport.sendRequest(
                method: "POST",
                url: #require(server.serverURL?.appending(path: "echo")),
                body: sentBody,
                headers: ["Content-Type": "application/octet-stream"]
            )

            #expect(statusCode == 200)
            #expect(data == sentBody)
        }

        @Test("Connection passes query parameters to the request")
        func connectionPassesQueryParameters() async throws {
            var capturedQuery: [String: String]?

            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/search",
                request: DZWebServerRequest.self
            ) { request in
                capturedQuery = request.query
                return DZWebServerDataResponse(text: "OK")
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let baseURL = try #require(server.serverURL)
            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(URL(string: "\(baseURL.absoluteString)search?q=hello&lang=en"))
            )

            #expect(statusCode == 200)
            #expect(capturedQuery == ["q": "hello", "lang": "en"])
        }

        @Test("Connection passes every request header to the handler")
        func connectionPassesRequestHeaders() async throws {
            var capturedHeaders: [String: String] = [:]

            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/headers",
                request: DZWebServerRequest.self
            ) { request in
                capturedHeaders = request.headers
                return DZWebServerDataResponse(text: "OK")
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let sentHeaders = Dictionary(uniqueKeysWithValues: (0..<50).map { ("X-Test-\($0)", "value-\($0)") })
            let (statusCode, _, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appending(path: "headers")),
                headers: sentHeaders
            )

            #expect(statusCode == 200)
            let receivedTestHeaders = capturedHeaders.filter { $0.key.hasPrefix("X-Test-") }
            #expect(receivedTestHeaders == sentHeaders)
        }

        @Test("Connection populates local and remote addresses on the request")
        func connectionPopulatesAddresses() async throws {
            var capturedRequest: DZWebServerRequest?

            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/address",
                request: DZWebServerRequest.self
            ) { request in
                capturedRequest = request
                return DZWebServerDataResponse(text: "OK")
            }
            try TestSupport.start(server)
            defer { server.stop() }

            _ = try await TestSupport.sendRequest(url: #require(server.serverURL?.appending(path: "address")))

            let request = try #require(capturedRequest)
            let localAddress = try #require(request.localAddressString)
            let remoteAddress = try #require(request.remoteAddressString)
            #expect(localAddress.hasPrefix("127.0.0.1:") || localAddress.hasPrefix("::1:"))
            #expect(localAddress.hasSuffix(":\(server.port)"))
            #expect(remoteAddress.hasPrefix("127.0.0.1:") || remoteAddress.hasPrefix("::1:"))
            #expect(remoteAddress != localAddress)

            // sockaddr_in is 16 bytes, sockaddr_in6 is 28 bytes.
            let expectedSize = localAddress.hasPrefix("::1:") ? 28 : 16
            #expect(request.localAddressData?.count == expectedSize)
            #expect(request.remoteAddressData?.count == expectedSize)
        }

        @Test("Server handles multiple sequential connections")
        func multipleSequentialRequests() async throws {
            var requestCount = 0
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/counter",
                request: DZWebServerRequest.self
            ) { _ in
                requestCount += 1
                return DZWebServerDataResponse(text: "Request \(requestCount)")
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let url = try #require(server.serverURL?.appending(path: "counter"))
            for index in 1...5 {
                let (statusCode, data, _) = try await TestSupport.sendRequest(url: url)

                #expect(statusCode == 200)
                #expect(String(data: data, encoding: .utf8) == "Request \(index)")
            }
        }
    }

    // MARK: Response Writing

    @Suite("Response Writing")
    struct ResponseWriting {
        @Test("No-content response is sent without a body")
        func emptyResponseBody() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "DELETE",
                path: "/resource",
                request: DZWebServerRequest.self
            ) { _ in
                DZWebServerResponse(statusCode: 204)
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                method: "DELETE",
                url: #require(server.serverURL?.appending(path: "resource"))
            )

            #expect(statusCode == 204)
            #expect(data.isEmpty)
        }

        @Test("HEAD response has no body but the Content-Length of the GET body")
        func headResponseHasContentLengthWithoutBody() async throws {
            let bodyText = "Known length body"
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/head-length",
                request: DZWebServerRequest.self
            ) { _ in
                DZWebServerDataResponse(text: bodyText)
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, response) = try await TestSupport.sendRequest(
                method: "HEAD",
                url: #require(server.serverURL?.appending(path: "head-length"))
            )

            #expect(statusCode == 200)
            #expect(data.isEmpty)
            #expect(response.value(forHTTPHeaderField: "Content-Length") == "\(bodyText.utf8.count)")
        }

        @Test("Additional response headers set in the handler are sent")
        func customResponseHeadersReceivedByClient() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/custom-header",
                request: DZWebServerRequest.self
            ) { _ in
                let response = DZWebServerDataResponse(text: "OK")
                response?.setValue("custom-value-123", forAdditionalHeader: "X-Custom-Response")
                return response
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, _, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appending(path: "custom-header"))
            )

            #expect(statusCode == 200)
            #expect(response.value(forHTTPHeaderField: "X-Custom-Response") == "custom-value-123")
        }

        @Test(
            "Content-Type and Content-Length match the response",
            arguments: [
                ("text", "text/plain; charset=utf-8"),
                ("html", "text/html; charset=utf-8"),
                ("json", "application/json"),
            ]
        )
        func contentHeadersMatchResponse(kind: String, expectedContentType: String) async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/content",
                request: DZWebServerRequest.self
            ) { _ in
                switch kind {
                case "html":
                    DZWebServerDataResponse(html: "<h1>Hello</h1>")
                case "json":
                    DZWebServerDataResponse(jsonObject: ["key": "value"])
                default:
                    DZWebServerDataResponse(text: "Plain text")
                }
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appending(path: "content"))
            )

            #expect(statusCode == 200)
            #expect(data.isEmpty == false)
            #expect(response.value(forHTTPHeaderField: "Content-Type") == expectedContentType)
            #expect(response.value(forHTTPHeaderField: "Content-Length") == "\(data.count)")
        }

        @Test("Asynchronous handler with delayed completion still produces the response")
        func asyncHandlerWithDelayedResponse() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/async",
                request: DZWebServerRequest.self,
                asyncProcessBlock: { _, completion in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                        completion(DZWebServerDataResponse(text: "Async response"))
                    }
                }
            )
            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, _) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appending(path: "async"))
            )

            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "Async response")
        }
    }

    // MARK: Standard Headers

    @Suite("Standard Headers")
    struct StandardHeaders {
        @Test("Server header defaults to the server class name")
        func serverHeaderDefaultsToClassName() async throws {
            let (_, response) = try await self.fetchOK()

            #expect(response.value(forHTTPHeaderField: "Server") == "DZWebServer")
        }

        @Test("Date header carries the current time in RFC 822 format")
        func responseIncludesDateHeader() async throws {
            let (_, response) = try await self.fetchOK()

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "GMT")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            let dateHeader = try #require(response.value(forHTTPHeaderField: "Date"))
            let date = try #require(formatter.date(from: dateHeader))
            #expect(abs(date.timeIntervalSinceNow) < 60)
        }

        @Test("Connection header is Close")
        func connectionHeaderIsClose() async throws {
            let (_, response) = try await self.fetchOK()

            #expect(response.value(forHTTPHeaderField: "Connection") == "Close")
        }

        @Test("cacheControlMaxAge 0 sends no-cache")
        func noCacheDirective() async throws {
            let (_, response) = try await self.fetchOK(cacheControlMaxAge: 0)

            #expect(response.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
        }

        @Test("Positive cacheControlMaxAge sends max-age")
        func maxAgeDirective() async throws {
            let (_, response) = try await self.fetchOK(cacheControlMaxAge: 3600)

            #expect(response.value(forHTTPHeaderField: "Cache-Control") == "max-age=3600, public")
        }

        private func fetchOK(cacheControlMaxAge: UInt = 0) async throws -> (Data, HTTPURLResponse) {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/ok",
                request: DZWebServerRequest.self
            ) { _ in
                let response = DZWebServerDataResponse(text: "OK")
                response?.cacheControlMaxAge = cacheControlMaxAge
                return response
            }
            try TestSupport.start(server)
            defer { server.stop() }

            let (statusCode, data, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appending(path: "ok"))
            )
            #expect(statusCode == 200)
            return (data, response)
        }
    }

    // MARK: Connection Class Option

    @Suite("Connection Class Option")
    struct ConnectionClassOption {
        @Test("Server uses the connection subclass passed in the ConnectionClass option")
        func customConnectionClassIsUsed() async throws {
            let server = DZWebServer()
            server.addHandler(
                forMethod: "GET",
                path: "/conn-class",
                request: DZWebServerRequest.self
            ) { _ in
                DZWebServerDataResponse(text: "OK")
            }
            var options = TestSupport.localhostOptions
            options[DZWebServerOption_ConnectionClass] = TaggingConnection.self
            try TestSupport.start(server, options: options)
            defer { server.stop() }

            let (statusCode, data, response) = try await TestSupport.sendRequest(
                url: #require(server.serverURL?.appending(path: "conn-class"))
            )

            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "OK")
            #expect(response.value(forHTTPHeaderField: TaggingConnection.headerName) == "1")
        }
    }
}

// MARK: Test Doubles

private final class TaggingConnection: DZWebServerConnection {
    static let headerName = "X-Tagging-Connection"

    override func overrideResponse(
        _ response: DZWebServerResponse,
        for request: DZWebServerRequest
    )
        -> DZWebServerResponse
    {
        response.setValue("1", forAdditionalHeader: Self.headerName)
        return super.overrideResponse(response, for: request)
    }
}
