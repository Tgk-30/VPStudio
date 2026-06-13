import Testing
import Foundation
@testable import VPStudio

@Suite("Subtitle Properties")
struct SubtitleUnitModelTests {
    @Test("Subtitle properties are set correctly")
    func subtitleProperties() {
        let subtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt,
            fileId: 456,
            rating: 4.5,
            downloadCount: 100,
            isHearingImpaired: true,
            source: "opensubtitles"
        )

        #expect(subtitle.id == "sub-123")
        #expect(subtitle.language == "en")
        #expect(subtitle.fileName == "subtitle.srt")
        #expect(subtitle.url == "https://example.com/subtitle.srt")
        #expect(subtitle.format == .srt)
        #expect(subtitle.fileId == 456)
        #expect(subtitle.rating == 4.5)
        #expect(subtitle.downloadCount == 100)
        #expect(subtitle.isHearingImpaired == true)
        #expect(subtitle.source == "opensubtitles")
    }

    @Test("Subtitle with optional properties nil")
    func optionalPropertiesNil() {
        let subtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        #expect(subtitle.fileId == nil)
        #expect(subtitle.rating == nil)
        #expect(subtitle.downloadCount == nil)
        #expect(subtitle.isHearingImpaired == nil)
        #expect(subtitle.source == nil)
    }
}

@Suite("Subtitle Format Parsing")
struct SubtitleFormatParsingModelTests {
    @Test("Format parsing from filename")
    func formatParsing() {
        #expect(SubtitleFormat.parse(from: "subtitle.srt") == .srt)
        #expect(SubtitleFormat.parse(from: "subtitle.vtt") == .vtt)
        #expect(SubtitleFormat.parse(from: "subtitle.webvtt") == .vtt)
        #expect(SubtitleFormat.parse(from: "subtitle.ass") == .ass)
        #expect(SubtitleFormat.parse(from: "subtitle.ssa") == .ssa)
        #expect(SubtitleFormat.parse(from: "subtitle.txt") == .unknown)
        #expect(SubtitleFormat.parse(from: "subtitle") == .unknown)
    }

    @Test("Format parsing is case insensitive")
    func caseInsensitiveParsing() {
        #expect(SubtitleFormat.parse(from: "subtitle.SRT") == .srt)
        #expect(SubtitleFormat.parse(from: "subtitle.VTT") == .vtt)
        #expect(SubtitleFormat.parse(from: "subtitle.ASS") == .ass)
        #expect(SubtitleFormat.parse(from: "subtitle.SSA") == .ssa)
    }
}

@Suite("Subtitle Language Code Normalization")
struct SubtitleLanguageNormalizationModelTests {
    @Test("Language code is preserved as-is")
    func languageCodePreservation() {
        let subtitle1 = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        let subtitle2 = Subtitle(
            id: "sub-456",
            language: "EN",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        let subtitle3 = Subtitle(
            id: "sub-789",
            language: "en-US",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        #expect(subtitle1.language == "en")
        #expect(subtitle2.language == "EN")
        #expect(subtitle3.language == "en-US")
    }
}

@Suite("Subtitle Display Name")
struct SubtitleDisplayNameModelTests {
    @Test("Display name shows language in uppercase")
    func displayNameUppercase() {
        let subtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        #expect(subtitle.displayName == "EN")
    }

    @Test("Display name includes hearing impaired marker")
    func displayNameHearingImpaired() {
        let subtitle1 = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt,
            isHearingImpaired: true
        )

        let subtitle2 = Subtitle(
            id: "sub-456",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt,
            isHearingImpaired: false
        )

        #expect(subtitle1.displayName == "EN (HI)")
        #expect(subtitle2.displayName == "EN")
    }

    @Test("Display name with nil hearing impaired")
    func displayNameNilHearingImpaired() {
        let subtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt,
            isHearingImpaired: nil
        )

        #expect(subtitle.displayName == "EN")
    }
}

@Suite("Subtitle Download URL")
struct SubtitleDownloadURLModelTests {
    @Test("Valid download URL")
    func validDownloadURL() {
        let subtitle1 = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        let subtitle2 = Subtitle(
            id: "sub-456",
            language: "en",
            fileName: "subtitle.srt",
            url: "http://example.com/subtitle.srt",
            format: .srt
        )

        let subtitle3 = Subtitle(
            id: "sub-789",
            language: "en",
            fileName: "subtitle.srt",
            url: "file:///path/to/subtitle.srt",
            format: .srt
        )
        let subtitle4 = Subtitle(
            id: "sub-uppercase",
            language: "en",
            fileName: "subtitle.srt",
            url: "HTTPS://example.com/subtitle.srt",
            format: .srt
        )

        #expect(subtitle1.downloadURL == URL(string: "https://example.com/subtitle.srt")!)
        #expect(subtitle2.downloadURL == URL(string: "http://example.com/subtitle.srt")!)
        #expect(subtitle3.downloadURL == URL(string: "file:///path/to/subtitle.srt")!)
        #expect(subtitle4.downloadURL == URL(string: "HTTPS://example.com/subtitle.srt")!)
    }

    @Test("Invalid download URL returns nil")
    func invalidDownloadURL() {
        let subtitle1 = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "invalid-url",
            format: .srt
        )

        let subtitle2 = Subtitle(
            id: "sub-456",
            language: "en",
            fileName: "subtitle.srt",
            url: "ftp://example.com/subtitle.srt",
            format: .srt
        )

        #expect(subtitle1.downloadURL == nil)
        #expect(subtitle2.downloadURL == nil)
    }
}

@Suite("Subtitle Supported Format")
struct SubtitleSupportedFormatModelTests {
    @Test("Known formats are supported")
    func knownFormatsSupported() {
        let subtitle1 = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        let subtitle2 = Subtitle(
            id: "sub-456",
            language: "en",
            fileName: "subtitle.vtt",
            url: "https://example.com/subtitle.vtt",
            format: .vtt
        )

        let subtitle3 = Subtitle(
            id: "sub-789",
            language: "en",
            fileName: "subtitle.ass",
            url: "https://example.com/subtitle.ass",
            format: .ass
        )

        #expect(subtitle1.isSupportedSubtitle == true)
        #expect(subtitle2.isSupportedSubtitle == true)
        #expect(subtitle3.isSupportedSubtitle == true)
    }

    @Test("Unknown format is not supported")
    func unknownFormatNotSupported() {
        let subtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.txt",
            url: "https://example.com/subtitle.txt",
            format: .unknown
        )

        #expect(subtitle.isSupportedSubtitle == false)
    }

    @Test("Format parsed from filename determines support")
    func formatFromFilename() {
        let subtitle1 = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .unknown
        )

        let subtitle2 = Subtitle(
            id: "sub-456",
            language: "en",
            fileName: "subtitle.txt",
            url: "https://example.com/subtitle.txt",
            format: .srt
        )

        #expect(subtitle1.isSupportedSubtitle == true)
        #expect(subtitle2.isSupportedSubtitle == true)
    }
}

@Suite("SubtitleFormat Properties")
struct SubtitleFormatModelTests {
    @Test("Supported subtitle formats")
    func supportedFormats() {
        #expect(SubtitleFormat.srt.isSupportedSubtitle == true)
        #expect(SubtitleFormat.vtt.isSupportedSubtitle == true)
        #expect(SubtitleFormat.ass.isSupportedSubtitle == true)
        #expect(SubtitleFormat.ssa.isSupportedSubtitle == true)
        #expect(SubtitleFormat.unknown.isSupportedSubtitle == false)
    }

    @Test("File extensions are correct")
    func fileExtensions() {
        #expect(SubtitleFormat.srt.fileExtension == "srt")
        #expect(SubtitleFormat.vtt.fileExtension == "vtt")
        #expect(SubtitleFormat.ass.fileExtension == "ass")
        #expect(SubtitleFormat.ssa.fileExtension == "ssa")
        #expect(SubtitleFormat.unknown.fileExtension == "srt")
    }
}

@Suite("Subtitle Codable Round-Trip")
struct SubtitleModelCodableTests {
    @Test("Subtitle encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalSubtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt,
            fileId: 456,
            rating: 4.5,
            downloadCount: 100,
            isHearingImpaired: true,
            source: "opensubtitles"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSubtitle)
        let decoder = JSONDecoder()
        let decodedSubtitle = try decoder.decode(Subtitle.self, from: data)

        #expect(decodedSubtitle.id == originalSubtitle.id)
        #expect(decodedSubtitle.language == originalSubtitle.language)
        #expect(decodedSubtitle.fileName == originalSubtitle.fileName)
        #expect(decodedSubtitle.url == originalSubtitle.url)
        #expect(decodedSubtitle.format == originalSubtitle.format)
        #expect(decodedSubtitle.fileId == originalSubtitle.fileId)
        #expect(decodedSubtitle.rating == originalSubtitle.rating)
        #expect(decodedSubtitle.downloadCount == originalSubtitle.downloadCount)
        #expect(decodedSubtitle.isHearingImpaired == originalSubtitle.isHearingImpaired)
        #expect(decodedSubtitle.source == originalSubtitle.source)
    }

    @Test("Subtitle with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let originalSubtitle = Subtitle(
            id: "sub-123",
            language: "en",
            fileName: "subtitle.srt",
            url: "https://example.com/subtitle.srt",
            format: .srt
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSubtitle)
        let decoder = JSONDecoder()
        let decodedSubtitle = try decoder.decode(Subtitle.self, from: data)

        #expect(decodedSubtitle.id == originalSubtitle.id)
        #expect(decodedSubtitle.language == originalSubtitle.language)
        #expect(decodedSubtitle.fileName == originalSubtitle.fileName)
        #expect(decodedSubtitle.url == originalSubtitle.url)
        #expect(decodedSubtitle.format == originalSubtitle.format)
    }
}
