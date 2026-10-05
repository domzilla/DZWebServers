//
//  DZWebServerMultiPartFormRequestTests.swift
//  DZWebServersTests
//
//  Created by Dominic Rodemer on 27.02.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import DZWebServers

@Suite("DZWebServerMultiPartFormRequest", .serialized, .tags(.request, .integration, .fileIO))
struct DZWebServerMultiPartFormRequestTests {
    // MARK: Private

    private static let boundary = "DZTestBoundary"

    /// The handler runs on a GCD thread, hence `@unchecked Sendable`.
    private final class RequestBox: @unchecked Sendable {
        var request: DZWebServerMultiPartFormRequest?
    }

    private static func multipartBody(
        fields: [(name: String, value: String)] = [],
        files: [(name: String, filename: String, contentType: String, data: Data)] = []
    )
        -> Data
    {
        var body = Data()
        for field in fields {
            body.append(Data("--\(self.boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n".utf8))
            body.append(Data("\(field.value)\r\n".utf8))
        }
        for file in files {
            body.append(Data("--\(self.boundary)\r\n".utf8))
            body.append(Data(
                "Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".utf8
            ))
            body.append(Data("Content-Type: \(file.contentType)\r\n\r\n".utf8))
            body.append(file.data)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(self.boundary)--\r\n".utf8))
        return body
    }

    /// Posts `body` to a fresh server and returns the parsed request. Uploaded temporary files live as long as the
    /// returned request.
    private static func upload(_ body: Data) async throws -> DZWebServerMultiPartFormRequest {
        let server = DZWebServer()
        let box = RequestBox()
        server.addHandler(
            forMethod: "POST",
            path: "/upload",
            request: DZWebServerMultiPartFormRequest.self
        ) { request -> DZWebServerResponse? in
            box.request = request as? DZWebServerMultiPartFormRequest
            return DZWebServerDataResponse(text: "OK")
        }
        try TestSupport.start(server)
        defer { server.stop() }

        let url = try #require(URL(string: "http://localhost:\(server.port)/upload"))
        let result = try await TestSupport.sendRequest(
            method: "POST",
            url: url,
            body: body,
            headers: ["Content-Type": "multipart/form-data; boundary=\(self.boundary)"]
        )
        #expect(result.statusCode == 200)
        return try #require(box.request)
    }

    // MARK: Class Method

    @Suite("Class method")
    struct ClassMethod {
        @Test("mimeType returns multipart/form-data")
        func mimeTypeReturnsMultipartFormData() {
            #expect(DZWebServerMultiPartFormRequest.mimeType() == "multipart/form-data")
        }
    }

    // MARK: Form Fields

    @Suite("Form fields (arguments)")
    struct FormFields {
        @Test("Single text field is parsed with correct controlName, string and raw data")
        func singleTextField() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [(name: "username", value: "Dominic")])
            )

            #expect(request.arguments.count == 1)
            #expect(request.arguments.first?.controlName == "username")
            #expect(request.arguments.first?.string == "Dominic")
            #expect(request.arguments.first?.data == Data("Dominic".utf8))
            #expect(request.files.isEmpty)
        }

        @Test("Multiple text fields are parsed in order")
        func multipleTextFields() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [
                    (name: "first", value: "Alice"),
                    (name: "second", value: "Bob"),
                    (name: "third", value: "Charlie"),
                ])
            )

            #expect(request.arguments.map(\.controlName) == ["first", "second", "third"])
            #expect(request.arguments.map(\.string) == ["Alice", "Bob", "Charlie"])
        }

        @Test("Field with unicode value is parsed correctly")
        func fieldWithUnicodeValue() async throws {
            let unicodeValue = "\u{1F44B} Hej v\u{00E4}rlden! \u{4F60}\u{597D}"
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [(name: "greeting", value: unicodeValue)])
            )

            #expect(request.arguments.count == 1)
            #expect(request.arguments.first?.string == unicodeValue)
        }

        @Test("Field with empty value is parsed as an empty string")
        func fieldWithEmptyValue() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [(name: "empty", value: "")])
            )

            #expect(request.arguments.count == 1)
            #expect(request.arguments.first?.string == "")
            #expect(request.arguments.first?.data.isEmpty == true)
        }

        @Test("Field with a 10,000 character value is parsed completely")
        func fieldWithVeryLongValue() async throws {
            let longValue = String(repeating: "ABCDEFGHIJ", count: 1000)
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [(name: "longfield", value: longValue)])
            )

            #expect(request.arguments.count == 1)
            #expect(request.arguments.first?.string == longValue)
        }
    }

    // MARK: File Uploads

    @Suite("File uploads (files)")
    struct FileUploads {
        @Test("Single file upload is parsed with controlName, fileName and content on disk")
        func singleFileUpload() async throws {
            let fileData = Data("The quick brown fox jumps over the lazy dog.".utf8)
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "document", filename: "report.txt", contentType: "text/plain", data: fileData),
                ])
            )

            let file = try #require(request.files.first)
            #expect(request.files.count == 1)
            #expect(request.arguments.isEmpty)
            #expect(file.controlName == "document")
            #expect(file.fileName == "report.txt")
            #expect(FileManager.default.contents(atPath: file.temporaryPath) == fileData)
        }

        @Test("Multiple file uploads are parsed in order")
        func multipleFileUploads() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "file1", filename: "a.txt", contentType: "text/plain", data: Data("aaa".utf8)),
                    (name: "file2", filename: "b.png", contentType: "image/png", data: Data([0x89, 0x50, 0x4E, 0x47])),
                    (
                        name: "file3",
                        filename: "c.json",
                        contentType: "application/json",
                        data: Data("{\"key\":1}".utf8)
                    ),
                ])
            )

            #expect(request.files.map(\.controlName) == ["file1", "file2", "file3"])
            #expect(request.files.map(\.fileName) == ["a.txt", "b.png", "c.json"])
        }

        @Test("File name with unicode or spaces is parsed correctly", arguments: [
            "\u{00FC}bersicht.txt",
            "my document file.txt",
        ])
        func fileNameIsPreserved(fileName: String) async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "doc", filename: fileName, contentType: "text/plain", data: Data("data".utf8)),
                ])
            )

            #expect(request.files.count == 1)
            #expect(request.files.first?.fileName == fileName)
        }

        @Test("File with empty content is stored as a zero-length file")
        func fileWithEmptyContent() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "empty", filename: "empty.bin", contentType: "application/octet-stream", data: Data()),
                ])
            )

            let file = try #require(request.files.first)
            #expect(file.fileName == "empty.bin")
            #expect(FileManager.default.contents(atPath: file.temporaryPath) == Data())
        }

        @Test("Binary content is preserved exactly", arguments: [
            Data(0...255),
            Data(repeating: 0xAB, count: 100 * 1024),
        ])
        func binaryContentIsPreserved(fileData: Data) async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "binary", filename: "data.bin", contentType: "application/octet-stream", data: fileData),
                ])
            )

            let file = try #require(request.files.first)
            #expect(FileManager.default.contents(atPath: file.temporaryPath) == fileData)
        }
    }

    // MARK: Lookup Methods

    @Suite("Lookup methods")
    struct LookupMethods {
        @Test("firstArgumentForControlName returns the matching argument or nil")
        func firstArgumentForControlName() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [
                    (name: "color", value: "blue"),
                    (name: "size", value: "large"),
                ])
            )

            #expect(request.firstArgument(forControlName: "color")?.string == "blue")
            #expect(request.firstArgument(forControlName: "size")?.string == "large")
            #expect(request.firstArgument(forControlName: "nonexistent") == nil)
        }

        @Test("firstFileForControlName returns the matching file or nil")
        func firstFileForControlName() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "photo", filename: "pic.jpg", contentType: "image/jpeg", data: Data([0xFF, 0xD8])),
                ])
            )

            let photo = try #require(request.firstFile(forControlName: "photo"))
            #expect(photo.fileName == "pic.jpg")
            #expect(photo.controlName == "photo")
            #expect(request.firstFile(forControlName: "missing") == nil)
        }

        @Test("Repeated field control name returns the first via firstArgumentForControlName")
        func repeatedFieldControlNameReturnsFirst() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [
                    (name: "tag", value: "swift"),
                    (name: "tag", value: "objc"),
                    (name: "tag", value: "testing"),
                ])
            )

            #expect(request.firstArgument(forControlName: "tag")?.string == "swift")
            #expect(request.arguments.count == 3)
        }

        @Test("Repeated file control name returns the first via firstFileForControlName")
        func repeatedFileControlNameReturnsFirst() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(files: [
                    (name: "attachment", filename: "first.txt", contentType: "text/plain", data: Data("one".utf8)),
                    (name: "attachment", filename: "second.txt", contentType: "text/plain", data: Data("two".utf8)),
                ])
            )

            #expect(request.firstFile(forControlName: "attachment")?.fileName == "first.txt")
            #expect(request.files.count == 2)
        }
    }

    // MARK: Mixed Fields and Files

    @Suite("Mixed fields and files")
    struct MixedFieldsAndFiles {
        @Test("Form with both text fields and file uploads parses all parts in order")
        func formWithFieldsAndFiles() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(
                    fields: [
                        (name: "title", value: "My Document"),
                        (name: "author", value: "Dominic"),
                    ],
                    files: [
                        (name: "image", filename: "photo.jpg", contentType: "image/jpeg", data: Data([0xFF, 0xD8])),
                        (name: "thumbnail", filename: "thumb.png", contentType: "image/png", data: Data([0x89, 0x50])),
                    ]
                )
            )

            #expect(request.arguments.map(\.controlName) == ["title", "author"])
            #expect(request.arguments.map(\.string) == ["My Document", "Dominic"])
            #expect(request.files.map(\.controlName) == ["image", "thumbnail"])
            #expect(request.files.map(\.fileName) == ["photo.jpg", "thumb.png"])
        }
    }

    // MARK: Part Content Types

    @Suite("Part content types")
    struct PartContentTypes {
        @Test("contentType defaults to text/plain for parts without a Content-Type header")
        func contentTypeDefaultsToTextPlain() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [(name: "field", value: "value")])
            )

            #expect(request.arguments.first?.contentType == "text/plain")
            #expect(request.arguments.first?.mimeType == "text/plain")
        }

        @Test("contentType keeps parameters while mimeType strips them")
        func mimeTypeStripsParameters() async throws {
            var body = Data()
            body.append(Data("--\(DZWebServerMultiPartFormRequestTests.boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"doc\"; filename=\"notes.txt\"\r\n".utf8))
            body.append(Data("Content-Type: text/plain; charset=utf-8\r\n\r\n".utf8))
            body.append(Data("Some notes\r\n".utf8))
            body.append(Data("--\(DZWebServerMultiPartFormRequestTests.boundary)--\r\n".utf8))

            let request = try await DZWebServerMultiPartFormRequestTests.upload(body)

            let file = try #require(request.files.first)
            #expect(file.contentType == "text/plain; charset=utf-8")
            #expect(file.mimeType == "text/plain")
        }

        @Test("Argument with a non-text content type has nil string but keeps raw data")
        func argumentStringIsNilForBinaryContentType() async throws {
            let rawBytes = Data([0x00, 0x01, 0x02, 0x03])
            var body = Data()
            body.append(Data("--\(DZWebServerMultiPartFormRequestTests.boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"binaryarg\"\r\n".utf8))
            body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
            body.append(rawBytes)
            body.append(Data("\r\n--\(DZWebServerMultiPartFormRequestTests.boundary)--\r\n".utf8))

            let request = try await DZWebServerMultiPartFormRequestTests.upload(body)

            let argument = try #require(request.arguments.first)
            #expect(argument.string == nil)
            #expect(argument.data == rawBytes)
        }
    }

    // MARK: Edge Cases

    @Suite("Edge cases")
    struct EdgeCases {
        @Test("Empty form with no fields and no files produces empty arrays")
        func emptyForm() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody()
            )

            #expect(request.arguments.isEmpty)
            #expect(request.files.isEmpty)
        }

        @Test("Field with special characters in name is parsed correctly")
        func fieldWithSpecialCharactersInName() async throws {
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [
                    (name: "field-name_with.special", value: "specialvalue"),
                ])
            )

            #expect(request.arguments.first?.controlName == "field-name_with.special")
            #expect(request.arguments.first?.string == "specialvalue")
        }

        @Test("Field value containing boundary-like text does not confuse the parser")
        func fieldValueContainingBoundaryLikeText() async throws {
            let trickyValue = "This has --SomeOtherBoundary in it"
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: [(name: "tricky", value: trickyValue)])
            )

            #expect(request.arguments.count == 1)
            #expect(request.arguments.first?.string == trickyValue)
        }

        @Test("Form with 50 fields processes all of them in order")
        func formWithManyFields() async throws {
            let fields = (0..<50).map { (name: "field_\($0)", value: "value_\($0)") }
            let request = try await DZWebServerMultiPartFormRequestTests.upload(
                DZWebServerMultiPartFormRequestTests.multipartBody(fields: fields)
            )

            #expect(request.arguments.map(\.controlName) == fields.map(\.name))
            #expect(request.arguments.compactMap(\.string) == fields.map(\.value))
        }
    }
}
