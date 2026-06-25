import Testing
import Foundation
@testable import VPStudio

private func makeStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

private func readRequestBody(_ request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read > 0 {
            data.append(buffer, count: read)
        } else {
            break
        }
    }
    return data.isEmpty ? nil : data
}

private actor DefaultFirstMatchSubtitleService: OpenSubtitlesServicing {
    private var requests: [(query: String, languages: [String])] = []

    func search(
        imdbId: String?,
        tmdbId: Int?,
        query: String?,
        season: Int?,
        episode: Int?,
        languages: [String]
    ) async throws -> [Subtitle] {
        []
    }

    func downloadSubtitle(fileId: Int) async throws -> String {
        "1\n00:00:00,000 --> 00:00:01,000\nHello\n"
    }

    func downloadFirstMatch(
        query: String,
        languages: [String]
    ) async throws -> Subtitle {
        requests.append((query: query, languages: languages))
        return Subtitle(
            id: "default-first-match",
            language: languages.first ?? "und",
            fileName: "\(query).srt",
            url: "file:///tmp/\(query).srt",
            format: .srt,
            fileId: 7,
            source: "Stub"
        )
    }

    func recordedRequests() -> [(query: String, languages: [String])] {
        requests
    }
}

@Suite("OpenSubtitlesServicing Protocol Defaults")
struct OpenSubtitlesServicingProtocolDefaultTests {
    @Test
    func seasonalDownloadFirstMatchDelegatesToNonSeasonalOverloadByDefault() async throws {
        let service = DefaultFirstMatchSubtitleService()

        let subtitle = try await service.downloadFirstMatch(
            query: "Show S01E02",
            languages: ["en", "fr"],
            season: 1,
            episode: 2
        )

        #expect(subtitle.id == "default-first-match")
        #expect(subtitle.language == "en")
        #expect(await service.recordedRequests().map(\.query) == ["Show S01E02"])
        #expect(await service.recordedRequests().first?.languages == ["en", "fr"])
    }
}

// MARK: - OpenSubtitlesService Request Construction Tests

@Suite("OpenSubtitlesService - Request Construction")
struct OpenSubtitlesServiceRequestConstructionTests {

    @Test func searchConstructsCorrectEndpoint() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "test-key", session: session)
        _ = try await service.search(query: "Test")

        #expect(recorder.path == "/api/v1/subtitles")
    }

    @Test func invalidCustomBaseURLFallsBackToDefaultAPIEndpoint() async throws {
        final class URLRecorder: @unchecked Sendable {
            var host: String?
            var path: String?
        }
        let recorder = URLRecorder()

        let session = makeStubSession { request in
            recorder.host = request.url?.host
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(
            apiKey: "key",
            session: session,
            baseURL: "http://["
        )
        _ = try await service.search(query: "Fallback")

        #expect(recorder.host == "api.opensubtitles.com")
        #expect(recorder.path == "/api/v1/subtitles")
    }

    @Test func searchSendsApiKeyHeader() async throws {
        final class HeaderRecorder: @unchecked Sendable { var apiKey: String? }
        let recorder = HeaderRecorder()

        let session = makeStubSession { request in
            recorder.apiKey = request.value(forHTTPHeaderField: "Api-Key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "my-secret-key", session: session)
        _ = try await service.search(query: "Test")

        #expect(recorder.apiKey == "my-secret-key")
    }

    @Test func searchSendsUserAgentHeader() async throws {
        final class HeaderRecorder: @unchecked Sendable { var userAgent: String? }
        let recorder = HeaderRecorder()

        let session = makeStubSession { request in
            recorder.userAgent = request.value(forHTTPHeaderField: "User-Agent")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "Test")

        #expect(recorder.userAgent == "VPStudio v1.0")
    }

    @Test func searchSendsContentTypeHeader() async throws {
        final class HeaderRecorder: @unchecked Sendable { var contentType: String? }
        let recorder = HeaderRecorder()

        let session = makeStubSession { request in
            recorder.contentType = request.value(forHTTPHeaderField: "Content-Type")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "Test")

        #expect(recorder.contentType == "application/json")
    }

    @Test func loginSendsPOSTRequest() async throws {
        final class MethodRecorder: @unchecked Sendable { var method: String? }
        let recorder = MethodRecorder()

        let session = makeStubSession { request in
            recorder.method = request.httpMethod
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"token":"abc"}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.login(username: "user", password: "pass")

        #expect(recorder.method == "POST")
    }

    @Test func loginSendsJSONBody() async throws {
        final class BodyRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _username: String?
            private var _password: String?
            var username: String? {
                lock.lock(); defer { lock.unlock() }
                return _username
            }
            var password: String? {
                lock.lock(); defer { lock.unlock() }
                return _password
            }
            func capture(_ u: String?, _ p: String?) {
                lock.lock(); defer { lock.unlock() }
                _username = u
                _password = p
            }
        }
        let recorder = BodyRecorder()

        let session = makeStubSession { request in
            if let body = readRequestBody(request),
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
                recorder.capture(json["username"], json["password"])
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"token":"abc"}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.login(username: "testuser", password: "testpass")

        #expect(recorder.username == "testuser")
        #expect(recorder.password == "testpass")
    }

    @Test func loginUsesCorrectEndpoint() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"token":"abc"}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.login(username: "u", password: "p")

        #expect(recorder.path == "/api/v1/login")
    }

    @Test func getDownloadURLSendsPOSTRequest() async throws {
        final class MethodRecorder: @unchecked Sendable { var method: String? }
        let recorder = MethodRecorder()

        let session = makeStubSession { request in
            recorder.method = request.httpMethod
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"link":"https://example.com/file"}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.getDownloadURL(fileId: 123)

        #expect(recorder.method == "POST")
    }

    @Test func getDownloadURLSendsFileIdInBody() async throws {
        final class BodyRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _fileId: Int?
            var fileId: Int? {
                lock.lock(); defer { lock.unlock() }
                return _fileId
            }
            func capture(_ id: Int?) {
                lock.lock(); defer { lock.unlock() }
                _fileId = id
            }
        }
        let recorder = BodyRecorder()

        let session = makeStubSession { request in
            if let body = readRequestBody(request),
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let fileId = json["file_id"] as? Int {
                recorder.capture(fileId)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"link":"https://example.com/file"}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.getDownloadURL(fileId: 999)

        #expect(recorder.fileId == 999)
    }

    @Test func getDownloadURLUsesCorrectEndpoint() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"link":"https://example.com/file"}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.getDownloadURL(fileId: 1)

        #expect(recorder.path == "/api/v1/download")
    }

    @Test func searchByHashUsesCorrectEndpoint() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.searchByHash(movieHash: "abc", movieSize: 1000)

        #expect(recorder.path == "/api/v1/subtitles")
    }

    @Test func searchByHashSendsHashAndSize() async throws {
        final class QueryRecorder: @unchecked Sendable { var hash: String?; var size: String? }
        let recorder = QueryRecorder()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            recorder.hash = components?.queryItems?.first(where: { $0.name == "moviehash" })?.value
            recorder.size = components?.queryItems?.first(where: { $0.name == "moviebytesize" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.searchByHash(movieHash: "hash123456", movieSize: 9876543210)

        #expect(recorder.hash == "hash123456")
        #expect(recorder.size == "9876543210")
    }

    @Test func authenticatedRequestIncludesBearerToken() async throws {
        final class HeaderRecorder: @unchecked Sendable { var auth: String? }
        let recorder = HeaderRecorder()

        let session = makeStubSession { request in
            recorder.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.hasSuffix("/login") == true {
                return (response, Data(#"{"token":"secret-token"}"#.utf8))
            }
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.login(username: "u", password: "p")
        _ = try await service.search(query: "Test")

        #expect(recorder.auth == "Bearer secret-token")
    }
}

// MARK: - OpenSubtitlesService Response Parsing Tests

@Suite("OpenSubtitlesService - Response Parsing")
struct OpenSubtitlesServiceResponseParsingTests {

    @Test func searchParsesSubtitleItemCorrectly() async throws {
        let json = """
        {
            "data": [{
                "id": 12345,
                "attributes": {
                    "language": "en",
                    "release": "Movie.2024.1080p.WEB-DL",
                    "ratings": 8.5,
                    "download_count": 1500,
                    "hearing_impaired": false,
                    "files": [{"file_id": 67890, "file_name": "Movie.2024.1080p.WEB-DL.srt"}]
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Movie")

        #expect(results.count == 1)
        #expect(results[0].id == "12345")
        #expect(results[0].language == "en")
        #expect(results[0].fileName == "Movie.2024.1080p.WEB-DL.srt")
        #expect(results[0].format == .srt)
        #expect(results[0].fileId == 67890)
        #expect(results[0].rating == 8.5)
        #expect(results[0].downloadCount == 1500)
        #expect(results[0].isHearingImpaired == false)
    }

    @Test func searchHandlesMultipleResults() async throws {
        let json = """
        {
            "data": [
                {"id": 1, "attributes": {"language": "en", "release": "Rel1", "ratings": 7.0, "download_count": 100, "hearing_impaired": false, "files": [{"file_id": 1, "file_name": "Rel1.srt"}]}},
                {"id": 2, "attributes": {"language": "es", "release": "Rel2", "ratings": 6.0, "download_count": 50, "hearing_impaired": true, "files": [{"file_id": 2, "file_name": "Rel2.srt"}]}}
            ]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Test")

        #expect(results.count == 2)
        #expect(results[0].language == "en")
        #expect(results[1].language == "es")
        #expect(results[1].isHearingImpaired == true)
    }

    @Test func searchFiltersUnsupportedFormats() async throws {
        let json = """
        {
            "data": [{
                "id": 100,
                "attributes": {
                    "language": "en",
                    "release": "Bad.Format",
                    "ratings": 5.0,
                    "download_count": 10,
                    "hearing_impaired": false,
                    "files": [{"file_id": 101, "file_name": "Bad.Format.txt"}]
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Test")

        #expect(results.isEmpty)
    }

    @Test func searchPrefersSupportedFormatWhenMultipleFiles() async throws {
        let json = """
        {
            "data": [{
                "id": 200,
                "attributes": {
                    "language": "en",
                    "release": "Multi.Format",
                    "ratings": 7.5,
                    "download_count": 500,
                    "hearing_impaired": false,
                    "files": [
                        {"file_id": 201, "file_name": "Multi.Format.sub"},
                        {"file_id": 202, "file_name": "Multi.Format.srt"},
                        {"file_id": 203, "file_name": "Multi.Format.vtt"}
                    ]
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Test")

        #expect(results.count == 1)
        let selected = results[0]
        #expect(["srt", "vtt"].contains(selected.format.rawValue))
        #expect(selected.fileId == 202 || selected.fileId == 203)
    }

    @Test func searchUsesReleaseNameWhenNoFiles() async throws {
        let json = """
        {
            "data": [{
                "id": 300,
                "attributes": {
                    "language": "fr",
                    "release": "French.Release.Name",
                    "ratings": 6.5,
                    "download_count": 200,
                    "hearing_impaired": false,
                    "files": []
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Test")

        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.fileName == "French.Release.Name")
    }

    @Test func searchDecodesEnvelopeWrappedResponse() async throws {
        let json = """
        {
            "data": {
                "data": [{
                    "id": 301,
                    "attributes": {
                        "language": "de",
                        "release": "Wrapped.Release",
                        "ratings": 7.0,
                        "download_count": 12,
                        "hearing_impaired": false,
                        "files": [{"file_id": 302, "file_name": "Wrapped.Release.vtt"}]
                    }
                }]
            }
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Wrapped")

        #expect(results.count == 1)
        #expect(results[0].id == "301")
        #expect(results[0].format == .vtt)
        #expect(results[0].fileId == 302)
    }

    @Test func searchUsesUnknownFilenameWhenNoFilesOrReleaseAreProvided() async throws {
        let json = """
        {
            "data": [{
                "id": 303,
                "attributes": {
                    "language": "it",
                    "ratings": 0,
                    "download_count": 0,
                    "hearing_impaired": false,
                    "files": []
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Unknown")

        let result = try #require(results.first)
        #expect(result.fileName == "Unknown")
        #expect(result.format == .unknown)
        #expect(result.fileId == nil)
        #expect(result.isSupportedSubtitle == false)
    }

    @Test func searchThrowsDecodingFailedForMalformedJSON() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":["#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.decodingFailed) {
            _ = try await service.search(query: "Broken")
        }
    }

    @Test func loginReturnsToken() async throws {
        let json = #"{"token":"login-token-xyz-123"}"#

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let token = try await service.login(username: "user", password: "pass")

        #expect(token == "login-token-xyz-123")
    }

    @Test func getDownloadURLParsesLink() async throws {
        let json = #"{"link":"https://cdn.example.com/subtitles/file.srt"}"#

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let url = try await service.getDownloadURL(fileId: 1)

        #expect(url.absoluteString == "https://cdn.example.com/subtitles/file.srt")
    }

    @Test func getDownloadURLThrowsOnInvalidURL() async {
        let json = #"{"link":"not-a-valid-url"}"#

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.invalidDownloadURL) {
            _ = try await service.getDownloadURL(fileId: 1)
        }
    }
}

// MARK: - OpenSubtitlesService Download Handling Tests

@Suite("OpenSubtitlesService - Download Handling")
struct OpenSubtitlesServiceDownloadHandlingTests {

    @Test func downloadSubtitleReturnsContent() async throws {
        let subtitleContent = "1\n00:00:01,000 --> 00:00:02,000\nHello World\n"
        let fileURLResponse = #"{"link":"https://cdn.example.com/file.srt"}"#

        let session = makeStubSession { request in
            let url = try #require(request.url)
            if url.path.contains("/download") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(fileURLResponse.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(subtitleContent.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let content = try await service.downloadSubtitle(fileId: 1)

        #expect(content.contains("Hello World"))
    }

    @Test func downloadSubtitleDecodesUTF8() async throws {
        let content = "1\n00:00:01,000 --> 00:00:02,000\nCafé résumé\n"
        let fileURLResponse = #"{"link":"https://cdn.example.com/file.srt"}"#

        let session = makeStubSession { request in
            let url = try #require(request.url)
            if url.path.contains("/download") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(fileURLResponse.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(content.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let result = try await service.downloadSubtitle(fileId: 1)

        #expect(result.contains("Café"))
        #expect(result.contains("résumé"))
    }

    @Test func downloadSubtitleDecodesUTF16() async throws {
        let content = "1\n00:00:01,000 --> 00:00:02,000\nCafé\n"
        let fileURLResponse = #"{"link":"https://cdn.example.com/file.srt"}"#

        let session = makeStubSession { request in
            let url = try #require(request.url)
            if url.path.contains("/download") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(fileURLResponse.utf8))
            }
            let utf16Data = content.data(using: .utf16)!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, utf16Data)
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let result = try await service.downloadSubtitle(fileId: 1)

        #expect(result.contains("Café"))
    }

    @Test func downloadSubtitleRejectsBinaryData() async throws {
        let binaryData = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD])
        let fileURLResponse = #"{"link":"https://cdn.example.com/file.srt"}"#

        let session = makeStubSession { request in
            let url = try #require(request.url)
            if url.path.contains("/download") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(fileURLResponse.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, binaryData)
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        do {
            _ = try await service.downloadSubtitle(fileId: 1)
            Issue.record("Expected decodingFailed error")
        } catch let error as SubtitleError {
            if case .decodingFailed = error {
                // expected
            } else {
                Issue.record("Expected decodingFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected SubtitleError, got \(error)")
        }
    }

    @Test func downloadFirstMatchSearchesAndDownloads() async throws {
        let searchResponse = """
        {
            "data": [{
                "id": 500,
                "attributes": {
                    "language": "en",
                    "release": "Test.Movie",
                    "ratings": 8.0,
                    "download_count": 100,
                    "hearing_impaired": false,
                    "files": [{"file_id": 501, "file_name": "Test.Movie.srt"}]
                }
            }]
        }
        """
        let fileURLResponse = #"{"link":"https://cdn.example.com/Test.Movie.srt"}"#
        let subtitleContent = "1\n00:00:01,000 --> 00:00:02,000\nDownloaded\n"

        final class PathRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _paths: [String] = []
            var paths: [String] {
                lock.lock(); defer { lock.unlock() }
                return _paths
            }
            func record(_ p: String) {
                lock.lock(); defer { lock.unlock() }
                _paths.append(p)
            }
        }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            recorder.record(url.path)
            if url.path.contains("/subtitles") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(searchResponse.utf8))
            }
            if url.path.contains("/download") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(fileURLResponse.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(subtitleContent.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let result = try await service.downloadFirstMatch(query: "Test Movie")

        #expect(recorder.paths.contains { $0.hasSuffix("/subtitles") })
        #expect(recorder.paths.contains { $0.hasSuffix("/download") })
        #expect(result.fileName == "Test.Movie.srt")
        #expect(!result.url.isEmpty)
    }

    @Test func downloadFirstMatchCanSearchWithIMDbBackedLookupIDs() async throws {
        let searchResponse = """
        {
            "data": [{
                "id": 501,
                "attributes": {
                    "language": "en",
                    "release": "Dune.2021",
                    "ratings": 8.0,
                    "download_count": 100,
                    "hearing_impaired": false,
                    "files": [{"file_id": 502, "file_name": "Dune.2021.srt"}]
                }
            }]
        }
        """
        let fileURLResponse = #"{"link":"https://cdn.example.com/Dune.2021.srt"}"#
        let subtitleContent = "1\n00:00:01,000 --> 00:00:02,000\nDownloaded\n"

        final class QueryRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _subtitleQueryItems: [URLQueryItem] = []
            var subtitleQueryItems: [URLQueryItem] {
                lock.lock(); defer { lock.unlock() }
                return _subtitleQueryItems
            }
            func record(_ items: [URLQueryItem]) {
                lock.lock(); defer { lock.unlock() }
                _subtitleQueryItems = items
            }
        }
        let recorder = QueryRecorder()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            if url.path.contains("/subtitles") {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                recorder.record(components?.queryItems ?? [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(searchResponse.utf8))
            }
            if url.path.contains("/download") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(fileURLResponse.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(subtitleContent.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let result = try await service.downloadFirstMatch(
            imdbId: "movie-imdb-TT1160419",
            tmdbId: nil,
            query: "Dune 2021",
            languages: ["en"],
            season: nil,
            episode: nil
        )

        let values = Dictionary(uniqueKeysWithValues: recorder.subtitleQueryItems.map { ($0.name, $0.value ?? "") })
        #expect(values["imdb_id"] == "1160419")
        #expect(values["tmdb_id"] == nil)
        #expect(values["query"] == "Dune 2021")
        #expect(result.fileName == "Dune.2021.srt")
    }

    @Test func downloadFirstMatchThrowsNoSubtitlesFoundWhenEmpty() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.noSubtitlesFound) {
            _ = try await service.downloadFirstMatch(query: "NoMatch")
        }
    }

    @Test func downloadFirstMatchThrowsWhenNoSupportedFormat() async {
        let json = """
        {
            "data": [{
                "id": 600,
                "attributes": {
                    "language": "en",
                    "release": "Bad",
                    "ratings": 5.0,
                    "download_count": 10,
                    "hearing_impaired": false,
                    "files": [{"file_id": 601, "file_name": "Bad.txt"}]
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.noSubtitlesFound) {
            _ = try await service.downloadFirstMatch(query: "Test")
        }
    }

    @Test func downloadFirstMatchThrowsWhenNoFileId() async {
        let json = """
        {
            "data": [{
                "id": 700,
                "attributes": {
                    "language": "en",
                    "release": "NoFileId",
                    "ratings": 6.0,
                    "download_count": 50,
                    "hearing_impaired": false,
                    "files": []
                }
            }]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.noSubtitlesFound) {
            _ = try await service.downloadFirstMatch(query: "Test")
        }
    }

    @Test func writeTemporarySubtitleFileCreatesFile() async throws {
        let service = OpenSubtitlesService(apiKey: "key")
        let content = "1\n00:00:01,000 --> 00:00:02,000\nTest\n"
        let url = try await service.writeTemporarySubtitleFile(
            content: content,
            fileName: "test.srt",
            format: .srt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == content)
    }

    @Test func writeTemporarySubtitleFileStripsBOM() async throws {
        let service = OpenSubtitlesService(apiKey: "key")
        let content = "\u{FEFF}1\n00:00:01,000 --> 00:00:02,000\nBOM Test\n"
        let url = try await service.writeTemporarySubtitleFile(
            content: content,
            fileName: "test.srt",
            format: .srt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(!written.hasPrefix("\u{FEFF}"))
        #expect(written.contains("BOM Test"))
    }

    @Test func writeTemporarySubtitleFileUsesCorrectExtensionForFormat() async throws {
        let service = OpenSubtitlesService(apiKey: "key")

        let srtURL = try await service.writeTemporarySubtitleFile(content: "1", fileName: "x", format: .srt)
        defer { try? FileManager.default.removeItem(at: srtURL) }
        #expect(srtURL.pathExtension == "srt")

        let vttURL = try await service.writeTemporarySubtitleFile(content: "WEBVTT", fileName: "x", format: .vtt)
        defer { try? FileManager.default.removeItem(at: vttURL) }
        #expect(vttURL.pathExtension == "vtt")

        let assURL = try await service.writeTemporarySubtitleFile(content: "[Script]", fileName: "x", format: .ass)
        defer { try? FileManager.default.removeItem(at: assURL) }
        #expect(assURL.pathExtension == "ass")
    }

    @Test func writeTemporarySubtitleFileResolvesUnknownFormatFromFilename() async throws {
        let service = OpenSubtitlesService(apiKey: "key")
        let url = try await service.writeTemporarySubtitleFile(
            content: "WEBVTT",
            fileName: "movie.vtt",
            format: .unknown
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "vtt")
    }
}

// MARK: - OpenSubtitlesService Rate Limiting Tests

@Suite("OpenSubtitlesService - Rate Limiting")
struct OpenSubtitlesServiceRateLimitingTests {

    @Test func consecutiveRequestsAreRateLimited() async throws {
        final class TimestampRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _times: [Date] = []
            var times: [Date] {
                lock.lock(); defer { lock.unlock() }
                return _times
            }
            func record() {
                lock.lock(); defer { lock.unlock() }
                _times.append(Date())
            }
        }
        let recorder = TimestampRecorder()

        let session = makeStubSession { request in
            recorder.record()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "First")
        _ = try await service.search(query: "Second")

        let times = recorder.times
        #expect(times.count == 2)
        let interval = times[1].timeIntervalSince(times[0])
        #expect(interval >= 0.10)
    }

    @Test func retryAfter429SucceedsOnSecondAttempt() async throws {
        final class CallRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int {
                lock.lock(); defer { lock.unlock() }
                return _count
            }
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                _count += 1
                return _count
            }
        }
        let recorder = CallRecorder()

        let session = makeStubSession { request in
            let call = recorder.record()
            let url = request.url!
            if call == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "0"])!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[{"id":1,"attributes":{"language":"en","release":"R","ratings":7.0,"download_count":10,"hearing_impaired":false,"files":[{"file_id":1,"file_name":"R.srt"}]}}]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        let results = try await service.search(query: "Test")

        #expect(recorder.count == 2)
        #expect(results.count == 1)
    }

    @Test func retryAfter429FailsAfterSecondAttempt() async {
        final class CallRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int {
                lock.lock(); defer { lock.unlock() }
                return _count
            }
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                _count += 1
                return _count
            }
        }
        let recorder = CallRecorder()

        let session = makeStubSession { request in
            _ = recorder.record()
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.self) {
            _ = try await service.search(query: "Test")
        }

        #expect(recorder.count == 2)
    }

    @Test func rateLimitingAppliesToAllServiceMethods() async throws {
        final class TimestampRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _times: [Date] = []
            var times: [Date] {
                lock.lock(); defer { lock.unlock() }
                return _times
            }
            func record() {
                lock.lock(); defer { lock.unlock() }
                _times.append(Date())
            }
        }
        let recorder = TimestampRecorder()

        let session = makeStubSession { request in
            recorder.record()
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/login") {
                return (response, Data(#"{"token":"t"}"#.utf8))
            }
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.login(username: "u", password: "p")
        _ = try await service.search(query: "Test")

        let times = recorder.times
        #expect(times.count == 2)
        let interval = times[1].timeIntervalSince(times[0])
        #expect(interval >= 0.10)
    }

    @Test func unauthorizedClearsAuthToken() async throws {
        final class CallRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int {
                lock.lock(); defer { lock.unlock() }
                return _count
            }
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                _count += 1
                return _count
            }
        }
        let recorder = CallRecorder()

        let session = makeStubSession { request in
            let call = recorder.record()
            let url = try #require(request.url)
            if call == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"token":"valid-token"}"#.utf8))
            }
            if call == 2 {
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        _ = try await service.login(username: "user", password: "pass")

        do {
            _ = try await service.search(query: "Test")
            Issue.record("Expected unauthorized error")
        } catch SubtitleError.unauthorized {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(recorder.count == 2)
    }

    @Test func minimumRequestIntervalIsApplied() async throws {
        final class TimestampRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _times: [Date] = []
            var times: [Date] {
                lock.lock(); defer { lock.unlock() }
                return _times
            }
            func record() {
                lock.lock(); defer { lock.unlock() }
                _times.append(Date())
            }
        }
        let recorder = TimestampRecorder()

        let session = makeStubSession { request in
            recorder.record()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "A")
        _ = try await service.search(query: "B")

        let times = recorder.times
        let interval = times[1].timeIntervalSince(times[0])
        #expect(interval >= 0.10)
    }
}

// MARK: - OpenSubtitlesService Error Tests

@Suite("OpenSubtitlesService - Error Handling")
struct OpenSubtitlesServiceErrorHandlingTests {

    @Test func invalidURLThrowsInvalidURL() async {
        let service = OpenSubtitlesService(apiKey: "key", session: makeStubSession { _ in
            throw URLError(.badURL)
        })

        do {
            _ = try await service.search(query: "Test")
            Issue.record("Expected error")
        } catch let error as SubtitleError {
            let isInvalidURL: Bool
            if case .invalidURL = error {
                isInvalidURL = true
            } else {
                isInvalidURL = false
            }
            #expect(isInvalidURL)
        } catch {
            Issue.record("Expected SubtitleError, got \(error)")
        }
    }

    @Test func httpErrorMapsCorrectly() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data("Service Unavailable".utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        do {
            _ = try await service.search(query: "Test")
            Issue.record("Expected error")
        } catch let error as SubtitleError {
            if case .httpError(let code) = error {
                #expect(code == 503)
            } else {
                Issue.record("Expected httpError(503), got \(error)")
            }
        } catch {
            Issue.record("Expected SubtitleError, got \(error)")
        }
    }

    @Test func allSubtitleErrorsHaveDescriptions() {
        let errors: [SubtitleError] = [
            .invalidURL,
            .httpError(0),
            .unauthorized,
            .decodingFailed,
            .invalidDownloadURL,
            .noSubtitlesFound,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test func httpErrorDescriptionContainsCode() {
        let error = SubtitleError.httpError(429)
        #expect(error.errorDescription?.contains("429") == true)
    }

    @Test func unauthorizedDescription() {
        let error = SubtitleError.unauthorized
        #expect(error.errorDescription == "OpenSubtitles authorization expired")
    }

    @Test func noSubtitlesFoundDescription() {
        let error = SubtitleError.noSubtitlesFound
        #expect(error.errorDescription == "No subtitles found")
    }
}
