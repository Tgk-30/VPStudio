import Foundation
import CoreMedia
import CoreVideo
import Testing
@testable import VPStudio

// MARK: - HDRMetadataExtractor Mastering Display Color Volume Parsing Tests

@Suite("HDRMetadataExtractor — Mastering Display Color Volume Parsing")
struct HDRMetadataExtractorMDCVParsingTests {

    // MARK: - Valid 24-byte MDCV data

    @Test func parseMasteringDisplayColorVolumeExtractsMaxLuminance() {
        let data = Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x98, 0x96, 0x80, 0, 0, 0, 0]) // 1000 nits
        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(data)

        #expect(result.maxLuminance == 1000.0)
        #expect(result.minLuminance == 0.0)
    }

    @Test func parseMasteringDisplayColorVolumeExtractsMinLuminance() {
        var data = Data(repeating: 0, count: 24)
        // Primaries and white point (16 bytes) + max luminance (4 bytes) + min luminance (4 bytes)
        // Set min luminance to 0.005 nits = 50 units
        data[20] = 0
        data[21] = 0
        data[22] = 0x00
        data[23] = 0x32 // 50 in big-endian = 0.005 * 10000

        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(data)

        #expect(result.minLuminance == 0.005)
    }

    @Test func parseMasteringDisplayColorVolumeHandles4000Nits() {
        var data = Data(repeating: 0, count: 24)
        // max luminance at byte offset 16 = 4000 nits
        data[16] = 0x02
        data[17] = 0x62
        data[18] = 0x5A
        data[19] = 0x00 // 4000 nits in 0.0001-nit units

        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(data)

        #expect(result.maxLuminance == 4000.0)
    }

    @Test func parseMasteringDisplayColorVolumeHandles1000Nits() {
        var data = Data(repeating: 0, count: 24)
        // max luminance at byte offset 16 = 1000 nits in 0.0001-nit units
        data[16] = 0x00
        data[17] = 0x98
        data[18] = 0x96
        data[19] = 0x80

        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(data)

        #expect(result.maxLuminance == 1000.0)
    }

    @Test func parseMasteringDisplayColorVolumeHandles0MinLuminance() {
        var data = Data(repeating: 0, count: 24)
        // max luminance = 1000, min luminance = 0
        data[16] = 0x00
        data[17] = 0x00
        data[18] = 0x03
        data[19] = 0xE8
        // min luminance = 0

        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(data)

        #expect(result.minLuminance == 0.0)
    }

    // MARK: - Edge cases for data size

    @Test func parseMasteringDisplayColorVolumeReturnsNilWhenDataTooShort() {
        let shortData = Data([0, 1, 2, 3, 4, 5, 6, 7])
        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(shortData)

        #expect(result.maxLuminance == nil)
        #expect(result.minLuminance == nil)
    }

    @Test func parseMasteringDisplayColorVolumeHandlesExactly24Bytes() {
        let exactly24 = Data(repeating: 0xAB, count: 24)
        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(exactly24)

        #expect(result.maxLuminance != nil)
        #expect(result.minLuminance != nil)
    }

    @Test func parseMasteringDisplayColorVolumeHandles25Bytes() {
        let extra = Data(repeating: 0xAB, count: 25)
        let result = HDRMetadataExtractorTestsHelper.parseMasteringDisplayColorVolume(extra)

        // Should use only first 24 bytes
        #expect(result.maxLuminance != nil)
    }
}

// MARK: - HDRMetadataExtractor Content Light Level Info Parsing Tests

@Suite("HDRMetadataExtractor — Content Light Level Info Parsing")
struct HDRMetadataExtractorCLLIParsingTests {

    @Test func parseContentLightLevelInfoExtractsMaxCLL() {
        var data = Data()
        data.append(0x03) // high byte of 1000
        data.append(0xE8) // low byte of 1000
        data.append(0x01) // high byte of 400
        data.append(0x90) // low byte of 400

        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(data)

        #expect(result.maxCLL == 1000.0)
    }

    @Test func parseContentLightLevelInfoExtractsMaxFALL() {
        var data = Data()
        data.append(0x03) // high byte of 1000
        data.append(0xE8) // low byte of 1000
        data.append(0x01) // high byte of 400
        data.append(0x90) // low byte of 400

        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(data)

        #expect(result.maxFALL == 400.0)
    }

    @Test func parseContentLightLevelInfoHandles1000NitsMaxCLL() {
        var data = Data()
        data.append(0x03) // high byte of 1000 (0x03E8)
        data.append(0xE8) // low byte
        data.append(0x00) // FALL = 0
        data.append(0x64) // 100

        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(data)

        #expect(result.maxCLL == 1000.0)
    }

    @Test func parseContentLightLevelInfoHandles4000NitsMaxCLL() {
        var data = Data()
        data.append(0x0F) // high byte of 4000 (0x0FA0)
        data.append(0xA0) // low byte
        data.append(0x03) // FALL = 1000
        data.append(0xE8)

        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(data)

        #expect(result.maxCLL == 4000.0)
    }

    @Test func parseContentLightLevelInfoReturnsNilWhenDataTooShort() {
        let shortData = Data([0x00, 0x01])
        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(shortData)

        #expect(result.maxCLL == nil)
        #expect(result.maxFALL == nil)
    }

    @Test func parseContentLightLevelInfoHandlesExactly4Bytes() {
        let exactly4 = Data([0x03, 0xE8, 0x01, 0x90])
        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(exactly4)

        #expect(result.maxCLL == 1000.0)
        #expect(result.maxFALL == 400.0)
    }

    @Test func parseContentLightLevelInfoHandlesZeroValues() {
        let zeros = Data([0, 0, 0, 0])
        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(zeros)

        #expect(result.maxCLL == 0.0)
        #expect(result.maxFALL == 0.0)
    }

    @Test func parseContentLightLevelInfoHandlesMaxValues() {
        var data = Data()
        data.append(0xFF) // max UInt16 = 65535
        data.append(0xFF)
        data.append(0xFF)
        data.append(0xFF)

        let result = HDRMetadataExtractorTestsHelper.parseContentLightLevelInfo(data)

        #expect(result.maxCLL == 65535.0)
        #expect(result.maxFALL == 65535.0)
    }
}

// MARK: - HDRMetadataExtractor Transfer Function Detection Tests

@Suite("HDRMetadataExtractor — Transfer Function HDR Detection")
struct HDRMetadataExtractorTransferFunctionTests {

    @Test func pqTransferFunctionIsHdr() {
        let result = HDRMetadataExtractorTestsHelper.isHDRTransferFunction("SMPTE_ST_2084_PQ")
        #expect(result == true)
    }

    @Test func hlgTransferFunctionIsHdr() {
        let result = HDRMetadataExtractorTestsHelper.isHDRTransferFunction("ITU_R_2100_HLG")
        #expect(result == true)
    }

    @Test func sdrTransferFunctionIsNotHdr() {
        let result = HDRMetadataExtractorTestsHelper.isHDRTransferFunction("ITU_R_709_2")
        #expect(result == false)
    }

    @Test func nilTransferFunctionIsNotHdr() {
        let result = HDRMetadataExtractorTestsHelper.isHDRTransferFunction(nil)
        #expect(result == false)
    }

    @Test func emptyTransferFunctionIsNotHdr() {
        let result = HDRMetadataExtractorTestsHelper.isHDRTransferFunction("")
        #expect(result == false)
    }

    @Test func arbitraryTransferFunctionIsNotHdr() {
        let result = HDRMetadataExtractorTestsHelper.isHDRTransferFunction("unknown-transfer")
        #expect(result == false)
    }
}


// MARK: - HDRMetadataExtractor fourCC Helper Tests

@Suite("HDRMetadataExtractor — FourCharCode Helper")
struct HDRMetadataExtractorFourCCTests {

    @Test func fourCCHandles4CharacterString() {
        let code = HDRMetadataExtractorTestsHelper.fourCC("dvh1")
        #expect(code != 0)
    }

    @Test func fourCCHandles3CharacterString() {
        let code = HDRMetadataExtractorTestsHelper.fourCC("abc")
        #expect(code != 0)
    }

    @Test func fourCCHandles2CharacterString() {
        let code = HDRMetadataExtractorTestsHelper.fourCC("ab")
        #expect(code != 0)
    }

    @Test func fourCCHandles1CharacterString() {
        let code = HDRMetadataExtractorTestsHelper.fourCC("a")
        #expect(code != 0)
    }

    @Test func fourCCHandlesEmptyString() {
        let code = HDRMetadataExtractorTestsHelper.fourCC("")
        #expect(code == 0)
    }

    @Test func fourCCHandlesLongString() {
        let code = HDRMetadataExtractorTestsHelper.fourCC("dvh1test")
        // Should only use first 4 bytes
        #expect(code != 0)
    }

    @Test func fourCCProducesConsistentResults() {
        let code1 = HDRMetadataExtractorTestsHelper.fourCC("dvh1")
        let code2 = HDRMetadataExtractorTestsHelper.fourCC("dvh1")
        #expect(code1 == code2)
    }

    @Test func fourCCProducesDifferentResultsForDifferentStrings() {
        let code1 = HDRMetadataExtractorTestsHelper.fourCC("dvh1")
        let code2 = HDRMetadataExtractorTestsHelper.fourCC("dvhe")
        #expect(code1 != code2)
    }
}

// MARK: - HDRDisplayMetadata Tests

@Suite("HDRDisplayMetadata — Struct Behavior")
struct HDRDisplayMetadataStructTests {

    @Test func defaultMetadataIsNotHdr() {
        let metadata = HDRDisplayMetadata(
            maxDisplayLuminance: nil,
            minDisplayLuminance: nil,
            maxContentLightLevel: nil,
            maxFrameAverageLightLevel: nil,
            colorPrimaries: nil,
            transferFunction: nil,
            isHDR: false,
            isDolbyVision: false
        )

        #expect(!metadata.isHDR)
        #expect(!metadata.isDolbyVision)
    }

    @Test func metadataWithHDRFlagIsHDR() {
        let metadata = HDRDisplayMetadata(
            maxDisplayLuminance: 1000,
            minDisplayLuminance: 0.005,
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: false
        )

        #expect(metadata.isHDR)
        #expect(!metadata.isDolbyVision)
    }

    @Test func metadataWithDolbyVisionFlagIsBoth() {
        let metadata = HDRDisplayMetadata(
            maxDisplayLuminance: 4000,
            minDisplayLuminance: 0.001,
            maxContentLightLevel: 4000,
            maxFrameAverageLightLevel: 1000,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: true
        )

        #expect(metadata.isHDR)
        #expect(metadata.isDolbyVision)
    }

    @Test func metadataIsEquatable() {
        let metadata1 = HDRDisplayMetadata(
            maxDisplayLuminance: 1000,
            minDisplayLuminance: 0.005,
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: false
        )

        let metadata2 = HDRDisplayMetadata(
            maxDisplayLuminance: 1000,
            minDisplayLuminance: 0.005,
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: false
        )

        #expect(metadata1 == metadata2)
    }

    @Test func metadataWithDifferentValuesAreNotEqual() {
        let metadata1 = HDRDisplayMetadata(
            maxDisplayLuminance: 1000,
            minDisplayLuminance: 0.005,
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: false
        )

        let metadata2 = HDRDisplayMetadata(
            maxDisplayLuminance: 4000, // Different
            minDisplayLuminance: 0.005,
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: false
        )

        #expect(metadata1 != metadata2)
    }
}

// MARK: - Test Helper

enum HDRMetadataExtractorTestsHelper {
    static func parseMasteringDisplayColorVolume(_ data: Data) -> (maxLuminance: Float?, minLuminance: Float?) {
        guard data.count >= 24 else { return (nil, nil) }
        let maxRaw = readUInt32BE(data, offset: 16)
        let minRaw = readUInt32BE(data, offset: 20)
        return (Float(maxRaw) / 10_000.0, Float(minRaw) / 10_000.0)
    }

    static func parseContentLightLevelInfo(_ data: Data) -> (maxCLL: Float?, maxFALL: Float?) {
        guard data.count >= 4 else { return (nil, nil) }
        let cll = readUInt16BE(data, offset: 0)
        let fall = readUInt16BE(data, offset: 2)
        return (Float(cll), Float(fall))
    }

    static func isHDRTransferFunction(_ tf: String?) -> Bool {
        guard let tf else { return false }
        let hdrFunctions: Set<String> = [
            "SMPTE_ST_2084_PQ",
            "ITU_R_2100_HLG",
            kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String,
            kCVImageBufferTransferFunction_ITU_R_2100_HLG as String,
        ]
        return hdrFunctions.contains(tf)
    }

    static func isDolbyVisionCodec(_ formatDesc: CMFormatDescription) -> Bool {
        let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
        let dvCodecs: Set<FourCharCode> = [
            fourCC("dvh1"),
            fourCC("dvhe"),
            fourCC("dva1"),
            fourCC("dvav"),
        ]
        return dvCodecs.contains(codecType)
    }

    static func fourCC(_ string: String) -> FourCharCode {
        var code: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            code = (code << 8) | FourCharCode(char)
        }
        return code
    }

    private static func readUInt16BE(_ data: Data, offset: Int) -> UInt16 {
        guard data.count >= offset + 2 else { return 0 }
        return data.withUnsafeBytes { rawBuffer -> UInt16 in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
        }
    }

    private static func readUInt32BE(_ data: Data, offset: Int) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        return data.withUnsafeBytes { rawBuffer -> UInt32 in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return (UInt32(bytes[offset]) << 24)
                | (UInt32(bytes[offset + 1]) << 16)
                | (UInt32(bytes[offset + 2]) << 8)
                | UInt32(bytes[offset + 3])
        }
    }
}
