import Foundation
import Testing
@testable import VPStudio

@Suite("RealDebridEpisodeSelection")
struct RealDebridEpisodeSelectionTests {

    // MARK: - Helpers

    private func makeService() -> RealDebridService {
        RealDebridService(apiToken: "test-token", session: .shared)
    }

    private func rdFile(id: Int, path: String, bytes: Int64? = nil) -> RDFile {
        RDFile(id: id, path: path, bytes: bytes, selected: 0)
    }

    // MARK: - episodeMatchTokens

    @Test func episodeMatchTokensGeneratesStandardFormats() async {
        let service = makeService()
        let tokens = await service.episodeMatchTokens(seasonNumber: 2, episodeNumber: 5)
        #expect(tokens.contains("s02e05"))
        #expect(tokens.contains("2x05"))
        #expect(tokens.contains("season 2 episode 5"))
        #expect(tokens.contains("season.2.episode.5"))
        #expect(tokens.contains("ep05"))
        #expect(tokens.count == 5)
    }

    @Test func episodeMatchTokensPadsSingleDigits() async {
        let service = makeService()
        let tokens = await service.episodeMatchTokens(seasonNumber: 1, episodeNumber: 1)
        #expect(tokens.contains("s01e01"))
        #expect(tokens.contains("1x01"))
        #expect(tokens.contains("ep01"))
    }

    @Test func episodeMatchTokensHandlesDoubleDigits() async {
        let service = makeService()
        let tokens = await service.episodeMatchTokens(seasonNumber: 10, episodeNumber: 12)
        #expect(tokens.contains("s10e12"))
        #expect(tokens.contains("10x12"))
        #expect(tokens.contains("ep12"))
    }

    // MARK: - isProbablyVideoFile

    @Test func isProbablyVideoFileAcceptsCommonExtensions() {
        #expect(RealDebridService.isProbablyVideoFile("movie.mkv") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.mp4") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.avi") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.mov") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.m4v") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.ts") == true)
    }

    @Test func isProbablyVideoFileAcceptsVideoExtensions() {
        #expect(RealDebridService.isProbablyVideoFile("movie.mkv") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.mp4") == true)
        #expect(RealDebridService.isProbablyVideoFile("movie.avi") == true)
    }

    @Test func isProbablyVideoFileRejectsNonVideoExtensions() {
        #expect(RealDebridService.isProbablyVideoFile("readme.txt") == false)
        #expect(RealDebridService.isProbablyVideoFile("movie.nfo") == false)
        #expect(RealDebridService.isProbablyVideoFile("poster.jpg") == false)
        #expect(RealDebridService.isProbablyVideoFile("subtitles.srt") == false)
        #expect(RealDebridService.isProbablyVideoFile("archive.zip") == false)
        #expect(RealDebridService.isProbablyVideoFile("noextension") == false)
    }

    // MARK: - normalizedFileName

    @Test func normalizedFileNameReturnsLastPathComponentLowercased() {
        #expect(RealDebridService.normalizedFileName("/tmp/Movie.mkv") == "movie.mkv")
        #expect(RealDebridService.normalizedFileName("Show.S01E02.MP4") == "show.s01e02.mp4")
    }

    @Test func normalizedFileNameTrimsWhitespace() {
        #expect(RealDebridService.normalizedFileName("  file.mkv  ") == "file.mkv")
    }

    @Test func normalizedFileNameReturnsNilForEmptyOrNilInput() {
        #expect(RealDebridService.normalizedFileName(nil) == nil)
        #expect(RealDebridService.normalizedFileName("") == nil)
        #expect(RealDebridService.normalizedFileName("   ") == nil)
    }

    // MARK: - bestExactMatch

    @Test func bestExactMatchWithHintAndExactSize() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Show.S01E02.mkv", resolvedFileSizeHint: 2000)
        #expect(match?.id == 2)
    }

    @Test func bestExactMatchWithHintPrefersLargestWhenNoSizeHint() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 3000),
            rdFile(id: 3, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Show.S01E02.mkv", resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func bestExactMatchWithHintPrefersLargestWhenSizeHintMisses() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Show.S01E02.mkv", resolvedFileSizeHint: 9999)
        #expect(match?.id == 2)
    }

    @Test func bestExactMatchReturnsNilWhenNoHint() async {
        let service = makeService()
        let files = [rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: 1000)]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: nil, resolvedFileSizeHint: 1000)
        #expect(match == nil)
    }

    @Test func bestExactMatchReturnsNilWhenHintMatchesNothing() async {
        let service = makeService()
        let files = [rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: 1000)]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Other.mkv", resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    @Test func bestExactMatchIsCaseInsensitive() async {
        let service = makeService()
        let files = [rdFile(id: 1, path: "/show.s01e02.mkv", bytes: 1000)]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Show.S01E02.MKV", resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func bestExactMatchIgnoresPathPrefix() async {
        let service = makeService()
        let files = [rdFile(id: 1, path: "/tmp/Show.S01E02.mkv", bytes: 1000)]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Show.S01E02.mkv", resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func bestExactMatchHandlesNilBytesGracefully() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: nil),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: nil),
        ]
        let match = await service.bestExactMatch(in: files, resolvedFileNameHint: "Show.S01E02.mkv", resolvedFileSizeHint: nil)
        #expect(match != nil)
    }

    // MARK: - preferredEpisodeFile exact-match priority

    @Test func preferredEpisodeFileUsesExactMatchOverTokenMatch() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(
            in: files,
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E02.mkv",
            resolvedFileSizeHint: nil
        )
        #expect(match?.id == 2)
    }

    // MARK: - preferredEpisodeFile token matching (SxxExx)

    @Test func preferredEpisodeFileMatchesSxxExxFormat() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
            rdFile(id: 3, path: "/Show.S01E03.mkv", bytes: 3000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func preferredEpisodeFileMatchesNxExxFormat() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.1x01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.1x02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func preferredEpisodeFileMatchesSeasonEpisodeTextFormat() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show season 1 episode 1.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show season 1 episode 2.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func preferredEpisodeFileMatchesSeasonEpisodeDotFormat() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.season.1.episode.1.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.season.1.episode.2.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func preferredEpisodeFileMatchesEpXXFormat() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.ep01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.ep02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func preferredEpisodeFileTokenMatchPrefersLargestFile() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E02.480p.mkv", bytes: 500),
            rdFile(id: 2, path: "/Show.S01E02.1080p.mkv", bytes: 2000),
            rdFile(id: 3, path: "/Show.S01E02.720p.mkv", bytes: 1000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    // MARK: - preferredEpisodeFile single-video fallback

    @Test func preferredEpisodeFileFallsBackToSingleVideoWhenNoTokenMatch() async {
        let service = makeService()
        let files = [rdFile(id: 1, path: "/Movie.Feature.2024.mkv", bytes: 5000)]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 9, episodeNumber: 9, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func preferredEpisodeFileSingleVideoFallbackIgnoresNonVideoFiles() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/readme.txt", bytes: 100),
            rdFile(id: 2, path: "/poster.jpg", bytes: 200),
            rdFile(id: 3, path: "/Movie.mkv", bytes: 5000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 9, episodeNumber: 9, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 3)
    }

    @Test func preferredEpisodeFileReturnsNilWhenMultipleVideosAndNoMatch() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Movie.A.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Movie.B.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    // MARK: - preferredEpisodeFile no-match cases

    @Test func preferredEpisodeFileReturnsNilForNilFiles() async {
        let service = makeService()
        let match = await service.preferredEpisodeFile(in: nil, seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    @Test func preferredEpisodeFileReturnsNilForEmptyFiles() async {
        let service = makeService()
        let match = await service.preferredEpisodeFile(in: [], seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    @Test func preferredEpisodeFileReturnsNilWhenOnlyNonVideoFiles() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/readme.txt", bytes: 100),
            rdFile(id: 2, path: "/poster.jpg", bytes: 200),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    // MARK: - preferredEpisodeFile video filtering

    @Test func preferredEpisodeFileFiltersOutTxtAndNfo() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/episode.nfo", bytes: 100),
            rdFile(id: 2, path: "/sample.txt", bytes: 50),
            rdFile(id: 3, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 3)
    }

    @Test func preferredEpisodeFileFiltersOutSubtitlesAndImages() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/subtitles.srt", bytes: 10),
            rdFile(id: 2, path: "/screenshot.png", bytes: 100),
            rdFile(id: 3, path: "/Show.S01E02.mp4", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 3)
    }

    @Test func preferredEpisodeFileAcceptsAllVideoExtensions() async {
        let service = makeService()
        let extensions = ["mkv", "mp4", "avi", "mov", "m4v", "ts"]
        for ext in extensions {
            let files = [rdFile(id: 1, path: "/Show.S01E02.\(ext)", bytes: 1000)]
            let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 2, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
            #expect(match != nil, "Expected .\(ext) to be treated as a video file")
        }
    }

    // MARK: - preferredEpisodeFile boundary cases

    @Test func preferredEpisodeFileHandlesSeason10Episode10() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S10E09.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S10E10.mkv", bytes: 2000),
            rdFile(id: 3, path: "/Show.S10E11.mkv", bytes: 3000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 10, episodeNumber: 10, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 2)
    }

    @Test func preferredEpisodeFileDoesNotMatchWrongEpisode() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E10.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E11.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    @Test func preferredEpisodeFileDoesNotMatchWrongSeason() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S10E01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S10E02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match == nil)
    }

    @Test func preferredEpisodeFileHandlesEpisode01Correctly() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func preferredEpisodeFileMatchesLowercasePaths() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/show.s02e05.mkv", bytes: 1000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 2, episodeNumber: 5, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func preferredEpisodeFileMatchesMixedCasePaths() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S02E05.MKV", bytes: 1000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 2, episodeNumber: 5, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func preferredEpisodeFileTokenMatchWithNestedPaths() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Season 2/Show.S02E05.mkv", bytes: 1000),
        ]
        let match = await service.preferredEpisodeFile(in: files, seasonNumber: 2, episodeNumber: 5, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(match?.id == 1)
    }

    @Test func preferredEpisodeFileExactMatchRespectsSizeHint() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E02.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
            rdFile(id: 3, path: "/Show.S01E03.mkv", bytes: 3000),
        ]
        let match = await service.preferredEpisodeFile(
            in: files,
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Show.S01E02.mkv",
            resolvedFileSizeHint: 1000
        )
        #expect(match?.id == 1)
    }

    @Test func preferredEpisodeFileExactMatchFallsBackToTokenWhenHintMismatches() async {
        let service = makeService()
        let files = [
            rdFile(id: 1, path: "/Show.S01E01.mkv", bytes: 1000),
            rdFile(id: 2, path: "/Show.S01E02.mkv", bytes: 2000),
        ]
        let match = await service.preferredEpisodeFile(
            in: files,
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Wrong.Name.mkv",
            resolvedFileSizeHint: nil
        )
        #expect(match?.id == 2)
    }

    @Test func selectMatchingEpisodeFileReturnsFalseWhenNoEpisodeMatch() async throws {
        let service = RealDebridService(apiToken: "test-token", session: URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
              "id": "1",
              "status": "downloaded",
              "filename": "Archive",
              "files": [
                {"id":1, "path":"/Movie.Collection.mkv", "bytes": 1234, "selected": 0}
              ]
            }
            """
            return (response, Data(body.utf8))
        })

        let selected = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.mkv",
            resolvedFileSizeHint: nil
        )

        #expect(selected == false)
    }

    @Test func getStreamURLFallsBackToTorrentFilenameWhenSelectedPathAndUnrestrictFilenameMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/info/1") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {"id":"1","filename":"Show.S01E01.mkv","status":"downloaded","links":["https://realdebrid.example/fallback"],"files":null}
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/unrestrict/link") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {"id":"1","filename":"","download":"https://cdn.example/fallback.mp4","filesize":1000}
                """
                return (response, Data(body.utf8))
            }
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let serviceWithSession = RealDebridService(apiToken: "test-token", session: session)
        let stream = try await serviceWithSession.getStreamURL(torrentId: "1")
        #expect(stream.fileName == "Show.S01E01.mkv")
    }

    @Test func getStreamURLUsesSelectedFilePathWhenUnrestrictFilenameMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/info/2") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {
                  "id":"2",
                  "status":"downloaded",
                  "filename":"Archive.mkv",
                  "files":[
                    {"id":10,"path":"/folder/Show.S01E01.mkv","bytes":1111,"selected":1}
                  ],
                  "links":[
                    "https://realdebrid.example/selected.mkv",
                    "https://realdebrid.example/backup.mkv"
                  ]
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/unrestrict/link") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {"id":"2","filename":"","download":"https://cdn.example/selected.mkv","filesize":1111}
                """
                return (response, Data(body.utf8))
            }
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let service = RealDebridService(apiToken: "test-token", session: session)
        let stream = try await service.getStreamURL(torrentId: "2")
        #expect(stream.fileName == "Show.S01E01.mkv")
    }

    @Test func getStreamURLUsesSingleLinkFileMetadataWhenNoPlayableFileExists() async throws {
        final class State: @unchecked Sendable { var unrestrictBody: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/info/3") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {
                  "id":"3",
                  "status":"downloaded",
                  "filename":"Archive",
                  "files":[
                    {"id":1,"path":"/Archive/readme.txt","bytes":321,"selected":0}
                  ],
                  "links":["https://realdebrid.example/single"]
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/unrestrict/link") {
                state.unrestrictBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {"id":"3","filename":"","download":"https://cdn.example/single.bin","filesize":0}
                """
                return (response, Data(body.utf8))
            }
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let service = RealDebridService(apiToken: "test-token", session: session)
        let stream = try await service.getStreamURL(torrentId: "3")

        #expect(state.unrestrictBody?.contains("single") == true)
        #expect(stream.fileName == "readme.txt")
        #expect(stream.sizeBytes == 321)
    }

    @Test func getStreamURLFallsBackToFirstLinkWhenPreferredFileHasNoParallelLink() async throws {
        final class State: @unchecked Sendable { var unrestrictBody: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/info/4") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {
                  "id":"4",
                  "status":"downloaded",
                  "filename":"Season Pack",
                  "files":[
                    {"id":1,"path":"/Show.S01E01.720p.mkv","bytes":1000,"selected":0},
                    {"id":2,"path":"/Show.S01E02.720p.mkv","bytes":2000,"selected":0},
                    {"id":3,"path":"/Show.S01E03.2160p.mkv","bytes":9000,"selected":0}
                  ],
                  "links":[
                    "https://realdebrid.example/first",
                    "https://realdebrid.example/second"
                  ]
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/unrestrict/link") {
                state.unrestrictBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {"id":"4","filename":"","download":"https://cdn.example/fallback.mkv","filesize":0}
                """
                return (response, Data(body.utf8))
            }
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let service = RealDebridService(apiToken: "test-token", session: session)
        let stream = try await service.getStreamURL(torrentId: "4")

        #expect(state.unrestrictBody?.contains("first") == true)
        #expect(state.unrestrictBody?.contains("second") == false)
        #expect(stream.fileName == "Show.S01E01.720p.mkv")
        #expect(stream.sizeBytes == 1000)
    }

    @Test func unavailableForLegalReasons451UsesHTTPFallbackForBlankBody() async {
        let service = RealDebridService(apiToken: "test-token", session: URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 451, httpVersion: nil, headerFields: nil)!
            return (response, Data("   ".utf8))
        })

        await #expect(throws: DebridError.unavailableForLegalReasons("Real-Debrid /user returned HTTP 451")) {
            _ = try await service.validateToken()
        }
    }

    @Test func selectMatchingEpisodeFileHandlesRateLimitedResponse() async throws {
        let service = RealDebridService(apiToken: "test-token", session: URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{}"#.utf8))
        })

        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}
