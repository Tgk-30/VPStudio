import Testing
import Foundation
@testable import VPStudio

// MARK: - File Writing

@Suite("OpenSubtitlesService - File Writing")
struct OpenSubtitlesFileWritingTests {

    @Test func writesFileToTemporaryDirectory() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "Hello",
            fileName: "test.srt",
            format: .srt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func writtenFileContainsCorrectContent() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = "1\n00:00:01,000 --> 00:00:02,000\nHello\n"
        let url = try await service.writeTemporarySubtitleFile(
            content: content,
            fileName: "test.srt",
            format: .srt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == content)
    }

    @Test func knownSRTFormatUsesSRTExtension() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "1",
            fileName: "movie.txt",
            format: .srt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "srt")
    }

    @Test func knownVTTFormatUsesVTTExtension() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "WEBVTT",
            fileName: "movie.txt",
            format: .vtt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "vtt")
    }

    @Test func knownASSFormatUsesASSExtension() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "[Script Info]",
            fileName: "movie.txt",
            format: .ass
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "ass")
    }

    @Test func unknownFormatResolvesFromSRTFilename() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "1",
            fileName: "movie.srt",
            format: .unknown
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "srt")
    }

    @Test func unknownFormatResolvesFromVTTFilename() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "WEBVTT",
            fileName: "movie.vtt",
            format: .unknown
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "vtt")
    }

    @Test func unknownFormatResolvesFromASSFilename() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "[Script Info]",
            fileName: "movie.ass",
            format: .unknown
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "ass")
    }

    @Test func unknownFormatWithUnknownFilenameDefaultsToSRT() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let url = try await service.writeTemporarySubtitleFile(
            content: "1",
            fileName: "movie.txt",
            format: .unknown
        )
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "srt")
    }

    @Test func stripsUTF8BOMBeforeWriting() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = "\u{FEFF}1\n00:00:01,000 --> 00:00:02,000\nHello\n"
        let url = try await service.writeTemporarySubtitleFile(
            content: content,
            fileName: "test.srt",
            format: .srt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == "1\n00:00:01,000 --> 00:00:02,000\nHello\n")
        #expect(written.first != "\u{FEFF}")
    }

    @Test func stripsUTF16BOMBeforeWriting() async throws {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = "\u{FEFF}WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n"
        let url = try await service.writeTemporarySubtitleFile(
            content: content,
            fileName: "test.vtt",
            format: .vtt
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(!written.hasPrefix("\u{FEFF}"))
        #expect(written.hasPrefix("WEBVTT"))
    }
}

// MARK: - Content Decoding

@Suite("OpenSubtitlesService - Content Decoding")
struct OpenSubtitlesDecodingTests {

    @Test func decodesUTF8Content() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let data = Data("1\n00:00:01,000 --> 00:00:02,000\nHello\n".utf8)
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == "1\n00:00:01,000 --> 00:00:02,000\nHello\n")
    }

    @Test func decodesUTF16Content() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = "1\n00:00:01,000 --> 00:00:02,000\nCafé\n"
        let data = content.data(using: .utf16)!
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == content)
    }

    @Test func decodesLatin1Content() async {
        let service = OpenSubtitlesService(apiKey: "test")
        // Include byte patterns that are unpaired surrogates in both UTF-16BE
        // (0xd8 0x41) and UTF-16LE (0x41 0xdc) so ALL UTF-16 variants fail,
        // forcing the decoder to fall through to Latin-1.
        let content = "1\nØAAÜ\n2"
        let data = content.data(using: .isoLatin1)!
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == content)
    }

    @Test func fallsBackThroughEncodingChain() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = "1\n00:00:01,000 --> 00:00:02,000\nTest\n"
        let data = content.data(using: .utf16)!
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == content)
    }

    @Test func stripsUTF8BOMFromDecodedContent() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let bom = Data([0xEF, 0xBB, 0xBF])
        let content = Data("1\nHello\n".utf8)
        let data = bom + content
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == "1\nHello\n")
        #expect(decoded?.first != "\u{FEFF}")
    }

    @Test func stripsUTF16BOMFromDecodedContent() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let bom = Data([0xFE, 0xFF])
        let content = "1\nHello\n".data(using: .utf16BigEndian)!
        let data = bom + content
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == "1\nHello\n")
        #expect(decoded?.first != "\u{FEFF}")
    }

    @Test func returnsNilForBinaryData() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let data = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC])
        let decoded = await service.decodeSubtitleContent(from: data)
        #expect(decoded == nil)
    }
}

// MARK: - Heuristics

@Suite("OpenSubtitlesService - Text Heuristics")
struct OpenSubtitlesHeuristicsTests {

    @Test func emptyDataReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        #expect(await service.isLikelyTextSubtitleData(Data()) == true)
    }

    @Test func dataWithNullByteReturnsFalse() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let data = Data("Hello".utf8) + Data([0x00]) + Data("World".utf8)
        #expect(await service.isLikelyTextSubtitleData(data) == false)
    }

    @Test func dataWithExcessiveControlCharsReturnsFalse() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let data = Data(repeating: 0x01, count: 100)
        #expect(await service.isLikelyTextSubtitleData(data) == false)
    }

    @Test func normalTextDataReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let data = Data("1\n00:00:01,000 --> 00:00:02,000\nHello, world!\n".utf8)
        #expect(await service.isLikelyTextSubtitleData(data) == true)
    }

    @Test func dataWithTabsAndNewlinesReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let data = Data("1\t\n00:00:01,000 --> 00:00:02,000\r\nHello\n".utf8)
        #expect(await service.isLikelyTextSubtitleData(data) == true)
    }

    @Test func emptyStringReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        #expect(await service.isLikelySubtitleText("") == true)
    }

    @Test func validSRTContentReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        Hello

        2
        00:00:03,000 --> 00:00:04,000
        World
        """
        #expect(await service.isLikelySubtitleText(content) == true)
    }

    @Test func validVTTContentReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        Hello

        00:00:03.000 --> 00:00:04.000
        World
        """
        #expect(await service.isLikelySubtitleText(content) == true)
    }

    @Test func stringWithExcessiveControlCharsReturnsFalse() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = String(repeating: "\u{0001}", count: 100)
        #expect(await service.isLikelySubtitleText(content) == false)
    }

    @Test func stringWithTabsAndNewlinesReturnsTrue() async {
        let service = OpenSubtitlesService(apiKey: "test")
        let content = "1\t\r\n2\t\r\n3"
        #expect(await service.isLikelySubtitleText(content) == true)
    }
}
