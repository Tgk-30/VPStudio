import Foundation
import Testing
@testable import VPStudio

@Suite("VideoQuality Sort Order Tests")
struct VideoQualitySortOrderTests {

    @Test("VideoQuality cases have correct sort order")
    func videoQualitySortOrder() {
        #expect(VideoQuality.uhd4k.sortOrder == 5)
        #expect(VideoQuality.hd1080p.sortOrder == 4)
        #expect(VideoQuality.hd720p.sortOrder == 3)
        #expect(VideoQuality.sd480p.sortOrder == 2)
        #expect(VideoQuality.sd.sortOrder == 1)
        #expect(VideoQuality.unknown.sortOrder == 0)
    }

    @Test("VideoQuality Comparable implementation matches sortOrder")
    func videoQualityComparable() {
        #expect(VideoQuality.uhd4k > VideoQuality.hd1080p)
        #expect(VideoQuality.hd1080p > VideoQuality.hd720p)
        #expect(VideoQuality.hd720p > VideoQuality.sd480p)
        #expect(VideoQuality.sd480p > VideoQuality.sd)
        #expect(VideoQuality.sd > VideoQuality.unknown)
    }

    @Test("VideoQuality.allCases contains all cases")
    func videoQualityAllCases() {
        let allCases = VideoQuality.allCases
        #expect(allCases.count == 6)
        #expect(allCases.contains(.uhd4k))
        #expect(allCases.contains(.hd1080p))
        #expect(allCases.contains(.hd720p))
        #expect(allCases.contains(.sd480p))
        #expect(allCases.contains(.sd))
        #expect(allCases.contains(.unknown))
    }
}

@Suite("VideoQuality Parse Tests")
struct VideoQualityParseTests {

    @Test("parse 2160p returns uhd4k")
    func parse2160p() {
        #expect(VideoQuality.parse(from: "Movie.2160p.BluRay") == .uhd4k)
        #expect(VideoQuality.parse(from: "film.2160p.webdl") == .uhd4k)
    }

    @Test("parse 4k returns uhd4k")
    func parse4k() {
        #expect(VideoQuality.parse(from: "Movie.4k.BluRay") == .uhd4k)
        #expect(VideoQuality.parse(from: "film.4k.hdr") == .uhd4k)
    }

    @Test("parse uhd returns uhd4k")
    func parseUHD() {
        #expect(VideoQuality.parse(from: "Movie.UHD.BluRay") == .uhd4k)
    }

    @Test("parse 1080p returns hd1080p")
    func parse1080p() {
        #expect(VideoQuality.parse(from: "Movie.1080p.BluRay") == .hd1080p)
        #expect(VideoQuality.parse(from: "film.1080i.webdl") == .hd1080p)
    }

    @Test("parse 720p returns hd720p")
    func parse720p() {
        #expect(VideoQuality.parse(from: "Movie.720p.BluRay") == .hd720p)
    }

    @Test("parse 480p returns sd480p")
    func parse480p() {
        #expect(VideoQuality.parse(from: "Movie.480p.BluRay") == .sd480p)
    }

    @Test("parse sd standalone returns sd")
    func parseSDStandalone() {
        #expect(VideoQuality.parse(from: "Movie.SD.BluRay") == .sd)
        #expect(VideoQuality.parse(from: "film.sd.xvid") == .sd)
    }

    @Test("parse dvdrip returns sd")
    func parseDVDRip() {
        #expect(VideoQuality.parse(from: "Movie.DVDRip") == .sd)
    }

    @Test("parse cam returns sd")
    func parseCam() {
        #expect(VideoQuality.parse(from: "Movie.CAM") == .sd)
    }

    @Test("parse unknown title returns unknown")
    func parseUnknown() {
        #expect(VideoQuality.parse(from: "Movie") == .unknown)
        #expect(VideoQuality.parse(from: "") == .unknown)
    }
}

@Suite("VideoCodec Tests")
struct VideoCodecTests {

    @Test("VideoCodec all cases exist")
    func allVideoCodecCases() {
        #expect(VideoCodec.allCases.count == 5)
    }

    @Test("VideoCodec parse h265 variants")
    func parseH265() {
        #expect(VideoCodec.parse(from: "movie.x265.mkv") == .h265)
        #expect(VideoCodec.parse(from: "movie.h265.mkv") == .h265)
        #expect(VideoCodec.parse(from: "movie.h.265.mkv") == .h265)
        #expect(VideoCodec.parse(from: "movie.hevc.mkv") == .h265)
    }

    @Test("VideoCodec parse h264 variants")
    func parseH264() {
        #expect(VideoCodec.parse(from: "movie.x264.mkv") == .h264)
        #expect(VideoCodec.parse(from: "movie.h264.mkv") == .h264)
        #expect(VideoCodec.parse(from: "movie.h.264.mkv") == .h264)
        #expect(VideoCodec.parse(from: "movie.avc.mkv") == .h264)
    }

    @Test("VideoCodec parse av1")
    func parseAV1() {
        #expect(VideoCodec.parse(from: "movie.av1.mkv") == .av1)
    }

    @Test("VideoCodec parse xvid/divx")
    func parseXvid() {
        #expect(VideoCodec.parse(from: "movie.xvid.mkv") == .xvid)
        #expect(VideoCodec.parse(from: "movie.divx.mkv") == .xvid)
    }

    @Test("VideoCodec parse unknown")
    func parseUnknown() {
        #expect(VideoCodec.parse(from: "movie.unknown.mkv") == .unknown)
    }
}

@Suite("AudioFormat Tests")
struct AudioFormatTests {

    @Test("AudioFormat spatialAudioHint for Atmos/DTS-HD MA/TrueHD")
    func spatialAudioHintTrue() {
        #expect(AudioFormat.atmos.spatialAudioHint == true)
        #expect(AudioFormat.dtsHDMA.spatialAudioHint == true)
        #expect(AudioFormat.trueHD.spatialAudioHint == true)
    }

    @Test("AudioFormat spatialAudioHint for other formats")
    func spatialAudioHintFalse() {
        #expect(AudioFormat.dts.spatialAudioHint == false)
        #expect(AudioFormat.ac3.spatialAudioHint == false)
        #expect(AudioFormat.eac3.spatialAudioHint == false)
        #expect(AudioFormat.aac.spatialAudioHint == false)
        #expect(AudioFormat.flac.spatialAudioHint == false)
        #expect(AudioFormat.unknown.spatialAudioHint == false)
    }

    @Test("AudioFormat surroundHint for surround formats")
    func surroundHintTrue() {
        #expect(AudioFormat.atmos.surroundHint == true)
        #expect(AudioFormat.dtsHDMA.surroundHint == true)
        #expect(AudioFormat.trueHD.surroundHint == true)
        #expect(AudioFormat.dts.surroundHint == true)
        #expect(AudioFormat.ac3.surroundHint == true)
        #expect(AudioFormat.eac3.surroundHint == true)
    }

    @Test("AudioFormat surroundHint for non-surround formats")
    func surroundHintFalse() {
        #expect(AudioFormat.aac.surroundHint == false)
        #expect(AudioFormat.flac.surroundHint == false)
        #expect(AudioFormat.unknown.surroundHint == false)
    }

    @Test("AudioFormat parse atmos")
    func parseAtmos() {
        #expect(AudioFormat.parse(from: "movie.atmos.mkv") == .atmos)
    }

    @Test("AudioFormat parse DTS-HD variants")
    func parseDTSHD() {
        #expect(AudioFormat.parse(from: "movie.dts-hd.mkv") == .dtsHDMA)
        #expect(AudioFormat.parse(from: "movie.dts.hd.mkv") == .dtsHDMA)
        #expect(AudioFormat.parse(from: "movie.dtshd.mkv") == .dtsHDMA)
    }

    @Test("AudioFormat parse TrueHD variants")
    func parseTrueHD() {
        #expect(AudioFormat.parse(from: "movie.truehd.mkv") == .trueHD)
        #expect(AudioFormat.parse(from: "movie.true-hd.mkv") == .trueHD)
    }

    @Test("AudioFormat parse EAC3 variants")
    func parseEAC3() {
        #expect(AudioFormat.parse(from: "movie.eac3.mkv") == .eac3)
        #expect(AudioFormat.parse(from: "movie.e-ac3.mkv") == .eac3)
        #expect(AudioFormat.parse(from: "movie.ddp.mkv") == .eac3)
    }

    @Test("AudioFormat parse DTS")
    func parseDTS() {
        #expect(AudioFormat.parse(from: "movie.dts.mkv") == .dts)
    }

    @Test("AudioFormat parse AC3 variants")
    func parseAC3() {
        #expect(AudioFormat.parse(from: "movie.ac3.mkv") == .ac3)
        #expect(AudioFormat.parse(from: "movie.ac-3.mkv") == .ac3)
        #expect(AudioFormat.parse(from: "movie.dd5.mkv") == .ac3)
    }

    @Test("AudioFormat parse AAC")
    func parseAAC() {
        #expect(AudioFormat.parse(from: "movie.aac.mkv") == .aac)
    }

    @Test("AudioFormat parse FLAC")
    func parseFLAC() {
        #expect(AudioFormat.parse(from: "movie.flac.mkv") == .flac)
    }

    @Test("AudioFormat parse unknown")
    func parseUnknown() {
        #expect(AudioFormat.parse(from: "movie.unknown.mkv") == .unknown)
    }
}

@Suite("SourceType Tests")
struct SourceTypeTests {

    @Test("SourceType qualityTier values")
    func qualityTierValues() {
        #expect(SourceType.bluRay.qualityTier == 6)
        #expect(SourceType.webDL.qualityTier == 5)
        #expect(SourceType.webRip.qualityTier == 4)
        #expect(SourceType.hdRip.qualityTier == 3)
        #expect(SourceType.dvdRip.qualityTier == 2)
        #expect(SourceType.hdtv.qualityTier == 2)
        #expect(SourceType.cam.qualityTier == 1)
        #expect(SourceType.unknown.qualityTier == 0)
    }

    @Test("SourceType parse bluray variants")
    func parseBluray() {
        #expect(SourceType.parse(from: "movie.bluray.mkv") == .bluRay)
        #expect(SourceType.parse(from: "movie.blu-ray.mkv") == .bluRay)
        #expect(SourceType.parse(from: "movie.bdrip.mkv") == .bluRay)
        #expect(SourceType.parse(from: "movie.brrip.mkv") == .bluRay)
    }

    @Test("SourceType parse web-dl variants")
    func parseWebDL() {
        #expect(SourceType.parse(from: "movie.web-dl.mkv") == .webDL)
        #expect(SourceType.parse(from: "movie.webdl.mkv") == .webDL)
    }

    @Test("SourceType parse webrip variants")
    func parseWebRip() {
        #expect(SourceType.parse(from: "movie.webrip.mkv") == .webRip)
        #expect(SourceType.parse(from: "movie.web-rip.mkv") == .webRip)
    }

    @Test("SourceType parse hdrip")
    func parseHDRip() {
        #expect(SourceType.parse(from: "movie.hdrip.mkv") == .hdRip)
    }

    @Test("SourceType parse dvdrip variants")
    func parseDVDRip() {
        #expect(SourceType.parse(from: "movie.dvdrip.mkv") == .dvdRip)
        #expect(SourceType.parse(from: "movie.dvd-rip.mkv") == .dvdRip)
    }

    @Test("SourceType parse hdtv")
    func parseHDTV() {
        #expect(SourceType.parse(from: "movie.hdtv.mkv") == .hdtv)
    }

    @Test("SourceType parse cam variants")
    func parseCam() {
        #expect(SourceType.parse(from: "movie.hdcam.mkv") == .cam)
        #expect(SourceType.parse(from: "movie.telesync.mkv") == .cam)
        #expect(SourceType.parse(from: "movie.cam.mkv") == .cam)
        #expect(SourceType.parse(from: "movie.ts.mkv") == .cam)
    }

    @Test("SourceType parse unknown")
    func parseUnknown() {
        #expect(SourceType.parse(from: "movie.unknown.mkv") == .unknown)
    }
}

@Suite("HDRFormat Tests")
struct HDRFormatTests {

    @Test("HDRFormat parse dolby vision variants")
    func parseDolbyVision() {
        #expect(HDRFormat.parse(from: "movie.dolby.vision.mkv") == .dolbyVision)
        #expect(HDRFormat.parse(from: "movie.dolby-vision.mkv") == .dolbyVision)
        #expect(HDRFormat.parse(from: "movie.dolbyvision.mkv") == .dolbyVision)
        #expect(HDRFormat.parse(from: "movie.dovi.mkv") == .dolbyVision)
        #expect(HDRFormat.parse(from: "movie.dv.mkv") == .dolbyVision)
    }

    @Test("HDRFormat parse hdr10+")
    func parseHDR10Plus() {
        #expect(HDRFormat.parse(from: "movie.hdr10+.mkv") == .hdr10Plus)
        #expect(HDRFormat.parse(from: "movie.hdr10plus.mkv") == .hdr10Plus)
    }

    @Test("HDRFormat parse hdr10")
    func parseHDR10() {
        #expect(HDRFormat.parse(from: "movie.hdr10.mkv") == .hdr10)
        #expect(HDRFormat.parse(from: "movie.hdr.mkv") == .hdr10)
    }

    @Test("HDRFormat parse hlg")
    func parseHLG() {
        #expect(HDRFormat.parse(from: "movie.hlg.mkv") == .hlg)
    }

    @Test("HDRFormat parse default sdr")
    func parseDefaultSDR() {
        #expect(HDRFormat.parse(from: "movie.sdr.mkv") == .sdr)
        #expect(HDRFormat.parse(from: "movie.mkv") == .sdr)
    }
}

@Suite("HDRPreference Tests")
struct HDRPreferenceTests {

    @Test("HDRPreference display names")
    func displayNames() {
        #expect(HDRPreference.auto.displayName == "Auto")
        #expect(HDRPreference.dolbyVision.displayName == "Dolby Vision")
        #expect(HDRPreference.hdr10.displayName == "HDR10/HDR10+")
    }

    @Test("HDRPreference raw values")
    func rawValues() {
        #expect(HDRPreference.auto.rawValue == "auto")
        #expect(HDRPreference.dolbyVision.rawValue == "dolby_vision")
        #expect(HDRPreference.hdr10.rawValue == "hdr10")
    }
}

@Suite("MediaType Tests")
struct MediaTypeTests {

    @Test("MediaType display names")
    func displayNames() {
        #expect(MediaType.movie.displayName == "Movie")
        #expect(MediaType.series.displayName == "TV Show")
    }

    @Test("MediaType tmdbPath")
    func tmdbPaths() {
        #expect(MediaType.movie.tmdbPath == "movie")
        #expect(MediaType.series.tmdbPath == "tv")
    }

    @Test("MediaType allCases")
    func allCases() {
        #expect(MediaType.allCases.count == 2)
        #expect(MediaType.allCases.contains(.movie))
        #expect(MediaType.allCases.contains(.series))
    }
}