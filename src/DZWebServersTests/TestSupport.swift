//
//  TestSupport.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 05.10.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

/// Shared fixtures for the integration suites.
enum TestSupport {
    /// Ephemeral port bound to loopback, so parallel test runs never collide on a fixed port.
    static let localhostOptions: [String: Any] = [
        DZWebServerOption_Port: 0,
        DZWebServerOption_BindToLocalhost: true,
    ]

    /// Ephemeral session so no cookies, credentials or cached responses leak between tests.
    static let session = URLSession(configuration: .ephemeral)

    /// Starts the server, retrying on EADDRINUSE. Framework bug: with port 0, `DZWebServer` binds IPv6 to the
    /// port the OS picked for IPv4 without that port being free on IPv6, so parallel runs can collide.
    static func start(_ server: DZWebServer, options: [String: Any] = localhostOptions) throws {
        var attempt = 1
        while true {
            do {
                try server.start(options: options)
                return
            } catch let error as NSError
                where error.domain == NSPOSIXErrorDomain && error.code == Int(EADDRINUSE) && attempt < 5
            {
                attempt += 1
            }
        }
    }

    /// Creates a unique, empty directory inside the temporary directory. The caller removes it.
    static func makeTemporaryDirectory(prefix: String) throws -> String {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    /// Drains a response through its `DZWebServerBodyReader` methods, as a connection would.
    static func readBody(of response: DZWebServerResponse) throws -> Data {
        try response.open()
        defer { response.close() }
        var body = Data()
        while true {
            let chunk = try response.readData()
            if chunk.isEmpty {
                return body
            }
            body.append(chunk)
        }
    }

    static func sendRequest(
        method: String = "GET",
        url: URL,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws
        -> (statusCode: Int, data: Data, response: HTTPURLResponse)
    {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await self.session.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        return (httpResponse.statusCode, data, httpResponse)
    }
}
