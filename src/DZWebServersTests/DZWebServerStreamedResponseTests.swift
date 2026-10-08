//
//  DZWebServerStreamedResponseTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZWebServers
import Foundation
import Testing

/// Hands out a fixed sequence of chunks, then empty data to end the stream. Read from the server's GCD queue.
private final class ChunkSource: @unchecked Sendable {
    private var chunks: [Data]

    init(_ chunks: [String]) {
        self.chunks = chunks.map { Data($0.utf8) }
    }

    func next() -> Data {
        self.chunks.isEmpty ? Data() : self.chunks.removeFirst()
    }
}

/// Reads one chunk through the body reader protocol; stream blocks in these tests complete synchronously.
private func readChunk(from response: DZWebServerStreamedResponse) -> (data: Data?, error: Error?) {
    var result: (data: Data?, error: Error?) = (nil, nil)
    var isCompleted = false
    (response as DZWebServerBodyReader).asyncReadData?(completion: { data, error in
        result = (data, error)
        isCompleted = true
    })
    #expect(isCompleted)
    return result
}

@Suite("DZWebServerStreamedResponse", .serialized, .tags(.response, .streaming))
struct DZWebServerStreamedResponseTests {
    // MARK: Initialization

    @Suite("Initialization", .tags(.properties))
    struct Initialization {
        @Test("Sync initializer sets the content type and leaves the length unknown for chunked encoding")
        func syncInitializerConfiguresChunkedBody() {
            let response = DZWebServerStreamedResponse(contentType: "text/plain", streamBlock: { _ in Data() })

            #expect(response.contentType == "text/plain")
            #expect(response.contentLength == UInt.max)
            #expect(response.statusCode == 200)
            #expect(response.hasBody())
        }

        @Test("Async initializer sets the content type and leaves the length unknown for chunked encoding")
        func asyncInitializerConfiguresChunkedBody() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/event-stream",
                asyncStreamBlock: { completion in completion(Data(), nil) }
            )

            #expect(response.contentType == "text/event-stream")
            #expect(response.contentLength == UInt.max)
            #expect(response.statusCode == 200)
            #expect(response.hasBody())
        }

        @Test("Description marks the body as a stream")
        func descriptionMarksStream() {
            let response = DZWebServerStreamedResponse(contentType: "text/plain", streamBlock: { _ in Data() })

            #expect(response.description.hasSuffix("\n\n<STREAM>"))
        }
    }

    // MARK: Reading

    @Suite("Reading")
    struct Reading {
        @Test("Sync stream block chunks are delivered in order, followed by empty data")
        func syncStreamBlockDeliversChunks() {
            let source = ChunkSource(["Hello, ", "World"])
            let response = DZWebServerStreamedResponse(contentType: "text/plain", streamBlock: { _ in source.next() })

            #expect(readChunk(from: response).data == Data("Hello, ".utf8))
            #expect(readChunk(from: response).data == Data("World".utf8))
            #expect(readChunk(from: response).data == Data())
        }

        @Test("Error set by the sync stream block is passed to the reader")
        func syncStreamBlockErrorIsPropagated() {
            let response = DZWebServerStreamedResponse(contentType: "text/plain", streamBlock: { error in
                error?.pointee = NSError(domain: "StreamTest", code: 42)
                return nil
            })

            let result = readChunk(from: response)

            #expect(result.data == nil)
            let error = result.error as NSError?
            #expect(error?.domain == "StreamTest")
            #expect(error?.code == 42)
        }

        @Test("Async stream block data and error are passed to the reader unchanged")
        func asyncStreamBlockResultIsPassedThrough() {
            let response = DZWebServerStreamedResponse(
                contentType: "text/plain",
                asyncStreamBlock: { completion in
                    completion(Data("chunk".utf8), NSError(domain: "StreamTest", code: 7))
                }
            )

            let result = readChunk(from: response)

            #expect(result.data == Data("chunk".utf8))
            #expect((result.error as NSError?)?.code == 7)
        }
    }

    // MARK: Serving

    @Suite("Serving", .serialized, .tags(.integration))
    struct Serving {
        private func serve(_ makeResponse: @escaping () -> DZWebServerResponse) throws -> DZWebServer {
            let server = DZWebServer()
            server.addHandler(forMethod: "GET", path: "/stream", request: DZWebServerRequest.self) { _ in
                makeResponse()
            }
            try TestSupport.start(server)
            return server
        }

        @Test("Sync stream is sent without a Content-Length and concatenates all chunks")
        func syncStreamIsServedChunked() async throws {
            let server = try self.serve {
                let source = ChunkSource(["alpha-", "beta-", "gamma"])
                return DZWebServerStreamedResponse(contentType: "text/plain", streamBlock: { _ in source.next() })
            }
            defer { server.stop() }
            let url = try #require(server.serverURL?.appendingPathComponent("stream"))

            let (statusCode, data, response) = try await TestSupport.sendRequest(url: url)

            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "alpha-beta-gamma")
            #expect(response.expectedContentLength == -1)
            #expect(response.value(forHTTPHeaderField: "Content-Type") == "text/plain")
        }

        @Test("Async stream completed from another queue is served in full")
        func asyncStreamIsServed() async throws {
            let server = try self.serve {
                let source = ChunkSource(["one", "two"])
                return DZWebServerStreamedResponse(contentType: "text/plain", asyncStreamBlock: { completion in
                    DispatchQueue.global().async {
                        completion(source.next(), nil)
                    }
                })
            }
            defer { server.stop() }
            let url = try #require(server.serverURL?.appendingPathComponent("stream"))

            let (statusCode, data, _) = try await TestSupport.sendRequest(url: url)

            #expect(statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == "onetwo")
        }

        @Test("Gzip-encoded stream is decoded by the client to the original content")
        func gzipStreamIsServedEncoded() async throws {
            let payload = String(repeating: "compressible ", count: 500)
            let server = try self.serve {
                let source = ChunkSource([payload])
                let response = DZWebServerStreamedResponse(
                    contentType: "text/plain",
                    streamBlock: { _ in source.next() }
                )
                response.isGZipContentEncodingEnabled = true
                return response
            }
            defer { server.stop() }
            let url = try #require(server.serverURL?.appendingPathComponent("stream"))

            let (statusCode, data, response) = try await TestSupport.sendRequest(url: url)

            #expect(statusCode == 200)
            #expect(response.value(forHTTPHeaderField: "Content-Encoding") == "gzip")
            #expect(String(data: data, encoding: .utf8) == payload)
        }

        @Test("Additional headers set on the stream response are sent to the client")
        func additionalHeadersAreSent() async throws {
            let server = try self.serve {
                let response = DZWebServerStreamedResponse(
                    contentType: "text/event-stream",
                    streamBlock: { _ in Data() }
                )
                response.setValue("no-transform", forAdditionalHeader: "X-Stream-Mode")
                return response
            }
            defer { server.stop() }
            let url = try #require(server.serverURL?.appendingPathComponent("stream"))

            let (_, _, response) = try await TestSupport.sendRequest(url: url)

            #expect(response.value(forHTTPHeaderField: "X-Stream-Mode") == "no-transform")
        }
    }
}
