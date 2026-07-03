import Testing
import Foundation
@testable import VPStudio

@Suite("MediaType Enum")
struct MediaTypeValueTests {
    @Test("MediaType has correct display names")
    func displayNames() {
        #expect(MediaType.movie.displayName == "Movie")
        #expect(MediaType.series.displayName == "TV Show")
    }

    @Test("MediaType has correct TMDB paths")
    func tmdbPaths() {
        #expect(MediaType.movie.tmdbPath == "movie")
        #expect(MediaType.series.tmdbPath == "tv")
    }

    @Test("MediaType is CaseIterable")
    func caseIterable() {
        let allCases = MediaType.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.movie))
        #expect(allCases.contains(.series))
    }

    @Test("MediaType Codable round-trip")
    func codableRoundTrip() throws {
        let original = MediaType.series
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaType.self, from: data)
        #expect(decoded == original)
    }

    @Test("MediaType raw values")
    func rawValues() {
        #expect(MediaType.movie.rawValue == "movie")
        #expect(MediaType.series.rawValue == "series")
    }
}

@Suite("VideoQuality Enum")
struct VideoQualityTests {
    @Test("VideoQuality has correct sort orders")
    func sortOrders() {
        #expect(VideoQuality.uhd4k.sortOrder == 5)
        #expect(VideoQuality.hd1080p.sortOrder == 4)
        #expect(VideoQuality.hd720p.sortOrder == 3)
        #expect(VideoQuality.sd480p.sortOrder == 2)
        #expect(VideoQuality.sd.sortOrder == 1)
        #expect(VideoQuality.unknown.sortOrder == 0)
    }

    @Test("VideoQuality comparison works correctly")
    func comparison() {
        #expect(VideoQuality.uhd4k > VideoQuality.hd1080p)
        #expect(VideoQuality.hd1080p > VideoQuality.hd720p)
        #expect(VideoQuality.hd720p > VideoQuality.sd480p)
        #expect(VideoQuality.sd480p > VideoQuality.sd)
        #expect(VideoQuality.sd > VideoQuality.unknown)
    }

    @Test("VideoQuality parsing from titles")
    func parsing() {
        #expect(VideoQuality.parse(from: "2160p HDR") == .uhd4k)
        #expect(VideoQuality.parse(from: "4K UHD") == .uhd4k)
        #expect(VideoQuality.parse(from: "1080p BluRay") == .hd1080p)
        #expect(VideoQuality.parse(from: "720p WEB-DL") == .hd720p)
        #expect(VideoQuality.parse(from: "480p DVDRip") == .sd480p)
        #expect(VideoQuality.parse(from: "SD Quality") == .sd)
        #expect(VideoQuality.parse(from: "Unknown Format") == .unknown)
    }

    @Test("VideoQuality is CaseIterable")
    func caseIterable() {
        let allCases = VideoQuality.allCases
        #expect(allCases.count == 6)
        #expect(allCases.contains(.uhd4k))
        #expect(allCases.contains(.unknown))
    }

    @Test("VideoQuality Codable round-trip")
    func codableRoundTrip() throws {
        let original = VideoQuality.hd1080p
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoQuality.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("VideoCodec Enum")
struct VideoCodecTestsModelsMediatypetests {
    @Test("VideoCodec parsing from titles")
    func parsing() {
        #expect(VideoCodec.parse(from: "H.265 HEVC") == .h265)
        #expect(VideoCodec.parse(from: "x264 AVC") == .h264)
        #expect(VideoCodec.parse(from: "AV1 Codec") == .av1)
        #expect(VideoCodec.parse(from: "XviD Rip") == .xvid)
        #expect(VideoCodec.parse(from: "Unknown Codec") == .unknown)
    }

    @Test("VideoCodec is CaseIterable")
    func caseIterable() {
        let allCases = VideoCodec.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.h264))
        #expect(allCases.contains(.unknown))
    }

    @Test("VideoCodec Codable round-trip")
    func codableRoundTrip() throws {
        let original = VideoCodec.av1
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoCodec.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("AudioFormat Enum")
struct AudioFormatTestsModelsMediatypetests {
    @Test("AudioFormat spatial audio hints")
    func spatialAudioHints() {
        #expect(AudioFormat.atmos.spatialAudioHint == true)
        #expect(AudioFormat.dtsHDMA.spatialAudioHint == true)
        #expect(AudioFormat.trueHD.spatialAudioHint == true)
        #expect(AudioFormat.aac.spatialAudioHint == false)
    }

    @Test("AudioFormat surround hints")
    func surroundHints() {
        #expect(AudioFormat.atmos.surroundHint == true)
        #expect(AudioFormat.dtsHDMA.surroundHint == true)
        #expect(AudioFormat.trueHD.surroundHint == true)
        #expect(AudioFormat.dts.surroundHint == true)
        #expect(AudioFormat.ac3.surroundHint == true)
        #expect(AudioFormat.eac3.surroundHint == true)
        #expect(AudioFormat.aac.surroundHint == false)
        #expect(AudioFormat.flac.surroundHint == false)
    }

    @Test("AudioFormat parsing from titles")
    func parsing() {
        #expect(AudioFormat.parse(from: "Atmos Audio") == .atmos)
        #expect(AudioFormat.parse(from: "DTS-HD MA") == .dtsHDMA)
        #expect(AudioFormat.parse(from: "TrueHD Track") == .trueHD)
        #expect(AudioFormat.parse(from: "EAC3 Audio") == .eac3)
        #expect(AudioFormat.parse(from: "DTS Sound") == .dts)
        #expect(AudioFormat.parse(from: "AC3 Dolby Digital") == .ac3)
        #expect(AudioFormat.parse(from: "AAC Audio") == .aac)
        #expect(AudioFormat.parse(from: "FLAC Lossless") == .flac)
        #expect(AudioFormat.parse(from: "Unknown Audio") == .unknown)
    }

    @Test("AudioFormat is CaseIterable")
    func caseIterable() {
        let allCases = AudioFormat.allCases
        #expect(allCases.count == 9)
        #expect(allCases.contains(.atmos))
        #expect(allCases.contains(.unknown))
    }

    @Test("AudioFormat Codable round-trip")
    func codableRoundTrip() throws {
        let original = AudioFormat.atmos
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioFormat.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("SourceType Enum")
struct SourceTypeTestsModelsMediatypetests {
    @Test("SourceType quality tiers")
    func qualityTiers() {
        #expect(SourceType.bluRay.qualityTier == 6)
        #expect(SourceType.webDL.qualityTier == 5)
        #expect(SourceType.webRip.qualityTier == 4)
        #expect(SourceType.hdRip.qualityTier == 3)
        #expect(SourceType.dvdRip.qualityTier == 2)
        #expect(SourceType.hdtv.qualityTier == 2)
        #expect(SourceType.cam.qualityTier == 1)
        #expect(SourceType.unknown.qualityTier == 0)
    }

    @Test("SourceType parsing from titles")
    func parsing() {
        #expect(SourceType.parse(from: "BluRay Rip") == .bluRay)
        #expect(SourceType.parse(from: "WEB-DL Quality") == .webDL)
        #expect(SourceType.parse(from: "WEBRip Source") == .webRip)
        #expect(SourceType.parse(from: "HDRip Content") == .hdRip)
        #expect(SourceType.parse(from: "DVDRip Movie") == .dvdRip)
        #expect(SourceType.parse(from: "HDTV Capture") == .hdtv)
        #expect(SourceType.parse(from: "CAM Recording") == .cam)
        #expect(SourceType.parse(from: "Unknown Source") == .unknown)
    }

    @Test("A trailing .ts container extension is not misread as a TS/CAM source")
    func trailingTSExtensionIsNotCam() {
        // MPEG-TS container files are legitimate — they must not be classified
        // as camera sources and hidden by the default "No CAM" filter.
        #expect(SourceType.parse(from: "Great.Movie.2024.1080p.WEB-DL.ts") == .webDL)
        #expect(SourceType.parse(from: "Great.Movie.2024.mkv") == .unknown)
        #expect(SourceType.parse(from: "Some.Episode.S01E02.ts") == .unknown)
        // A genuine TELESYNC token mid-title is still detected as CAM.
        #expect(SourceType.parse(from: "Great.Movie.2024.TS.XViD-GRP") == .cam)
        // HD-telesync must stay classified as CAM even once the .ts extension
        // is stripped (it was previously only caught by that extension).
        #expect(SourceType.parse(from: "Great.Movie.2024.HDTS.ts") == .cam)
        #expect(SourceType.parse(from: "Great.Movie.2024.TELECINE.x264.mkv") == .cam)
    }

    @Test("SourceType is CaseIterable")
    func caseIterable() {
        let allCases = SourceType.allCases
        #expect(allCases.count == 8)
        #expect(allCases.contains(.bluRay))
        #expect(allCases.contains(.unknown))
    }

    @Test("SourceType Codable round-trip")
    func codableRoundTrip() throws {
        let original = SourceType.webDL
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SourceType.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("HDRFormat Enum")
struct HDRFormatTestsModelsMediatypetests {
    @Test("HDRFormat parsing from titles")
    func parsing() {
        #expect(HDRFormat.parse(from: "Dolby Vision HDR") == .dolbyVision)
        #expect(HDRFormat.parse(from: "HDR10+ Content") == .hdr10Plus)
        #expect(HDRFormat.parse(from: "HDR10 Video") == .hdr10)
        #expect(HDRFormat.parse(from: "HLG Format") == .hlg)
        #expect(HDRFormat.parse(from: "SDR Content") == .sdr)
    }

    @Test("HDRFormat is CaseIterable")
    func caseIterable() {
        let allCases = HDRFormat.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.dolbyVision))
        #expect(allCases.contains(.sdr))
    }

    @Test("HDRFormat Codable round-trip")
    func codableRoundTrip() throws {
        let original = HDRFormat.dolbyVision
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HDRFormat.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("HDRPreference Enum")
struct HDRPreferenceValueTests {
    @Test("HDRPreference display names")
    func displayNames() {
        #expect(HDRPreference.auto.displayName == "Auto")
        #expect(HDRPreference.dolbyVision.displayName == "Dolby Vision")
        #expect(HDRPreference.hdr10.displayName == "HDR10/HDR10+")
    }

    @Test("HDRPreference is CaseIterable")
    func caseIterable() {
        let allCases = HDRPreference.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.auto))
        #expect(allCases.contains(.dolbyVision))
        #expect(allCases.contains(.hdr10))
    }

    @Test("HDRPreference Codable round-trip")
    func codableRoundTrip() throws {
        let original = HDRPreference.auto
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HDRPreference.self, from: data)
        #expect(decoded == original)
    }
}