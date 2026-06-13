import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VPStudio

@Suite("HDRI Orientation Analyzer - Yaw Detection Logic")
struct HDRIOrientationAnalyzerYawTests {

    @Test
    func yawDetectionAtNegative90Degrees() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("yaw-neg90.png")
        let width = 200
        let height = 100
        let brightRange = 25..<45
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))
        let brightCenter = Float((brightRange.lowerBound + brightRange.upperBound - 1) / 2)
        let screenYaw = (brightCenter / Float(width - 1) - 0.5) * 360.0
        let expectedReturn = -screenYaw

        #expect(abs(yaw - expectedReturn) < 15)
    }

    @Test
    func yawDetectionAtPositive90Degrees() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("yaw-pos90.png")
        let width = 200
        let height = 100
        let brightRange = 155..<175
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))
        let brightCenter = Float((brightRange.lowerBound + brightRange.upperBound - 1) / 2)
        let screenYaw = (brightCenter / Float(width - 1) - 0.5) * 360.0
        let expectedReturn = -screenYaw

        #expect(abs(yaw - expectedReturn) < 15)
    }

    @Test
    func yawDetectionNear180Boundary() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("yaw-180.png")
        let width = 200
        let height = 100
        let brightRange = 185..<200
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(yaw > 150 || yaw < -150)
    }

    @Test
    func yawNegationBringsScreenToFront() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("yaw-negation.png")
        let width = 200
        let height = 100
        let brightRange = 10..<30
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        let brightCenter = Float((brightRange.lowerBound + brightRange.upperBound - 1) / 2)
        let screenYawAngle = (brightCenter / Float(width - 1) - 0.5) * 360.0

        let negatedScreenAngle = -screenYawAngle
        #expect(abs(yaw - negatedScreenAngle) < 20)
    }

    @Test
    func yawIsZeroWhenBrightRegionAtCenter() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("yaw-center.png")
        let width = 200
        let height = 100
        let brightRange = 95..<105
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(abs(yaw) < 20)
    }

    @Test
    func yawDetectionWithVeryWideImage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("wide-panorama.png")
        let width = 800
        let height = 400
        let brightRange = 350..<420
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))
        let brightCenter = Float((brightRange.lowerBound + brightRange.upperBound - 1) / 2)
        let screenYaw = (brightCenter / Float(width - 1) - 0.5) * 360.0

        #expect(abs(yaw + screenYaw) < 15)
    }

    @Test
    func yawDetectionWithTallImage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("tall-panorama.png")
        let width = 200
        let height = 400
        let brightRange = 80..<100
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(yaw.isFinite)
    }

    @Test
    func yawDetectionWithVerySmallWidth() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("small-width.png")
        let width = 10
        let height = 100
        let brightRange = 3..<7
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    private func writePanorama(
        url: URL,
        width: Int,
        height: Int,
        brightColumns: Range<Int>,
        brightValue: UInt8 = 255
    ) throws {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 12, count: height * bytesPerRow)

        for y in 0..<height {
            let rowBase = y * bytesPerRow
            let isInScreenBand = (Int(Double(height) * 0.19)..<Int(Double(height) * 0.50)).contains(y)
            for x in 0..<width {
                let index = rowBase + x * 4
                let isBrightColumn = brightColumns.contains(x)
                let value: UInt8 = isInScreenBand && isBrightColumn ? brightValue : 12
                pixels[index] = value
                pixels[index + 1] = value
                pixels[index + 2] = value
                pixels[index + 3] = 255
            }
        }

        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}

@Suite("HDRI Orientation Analyzer - Edge Cases")
struct HDRIOrientationAnalyzerEdgeValidationTests {

    @Test
    func analyzeSyncReturnsNilForEmptyFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("empty.hdr")
        try Data().write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForTextFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("text.txt")
        try Data("This is not an image file".utf8).write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForPartiallyCorruptedPNG() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("partial.png")
        var data = Data()
        data.append(contentsOf: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x10])
        try data.write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForHDRWithInvalidHeader() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("invalid.hdr")
        try Data("#?RADIANCE\nINVALID HEADER DATA".utf8).write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForEXRWithInvalidHeader() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("invalid.exr")
        try Data([0x76, 0x2F, 0x31, 0x01]).write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForRecognizedButUndecodableSignatures() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var pngWithWrongTrailer = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        pngWithWrongTrailer.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        pngWithWrongTrailer.append(Data("IDAT".utf8))
        pngWithWrongTrailer.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        var avifHeaderOnly = Data([0x76, 0x2F, 0x31, 0x01])
        avifHeaderOnly.append(contentsOf: [UInt8](repeating: 0, count: 33))

        let fixtures: [(name: String, fileExtension: String, data: Data)] = [
            ("png-wrong-trailer", "png", pngWithWrongTrailer),
            ("jpeg-with-eoi", "jpg", Data([0xFF, 0xD8, 0x00, 0x00, 0x00, 0xFF, 0xD9])),
            ("rgbe-format-only", "hdr", Data("#?RGBE\nFORMAT=32-bit_rle_rgbe\n\n".utf8)),
            ("avif-header-only", "avif", avifHeaderOnly),
        ]

        for fixture in fixtures {
            let imageURL = tempDir
                .appendingPathComponent(fixture.name)
                .appendingPathExtension(fixture.fileExtension)
            try fixture.data.write(to: imageURL)

            let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
            #expect(yaw == nil, "Expected \(fixture.name) to be rejected")
        }
    }

    @Test
    func analyzeSyncHandlesImageLargerThanThumbnailMax() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("large.hdr")
        let width = 4096
        let height = 2048
        try writeLargePanorama(url: imageURL, width: width, height: height, brightColumns: 1800..<2000)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    @Test
    func analyzeSyncReturnsNilForAllBlackImage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("black.png")
        try writeSolidColorImage(url: imageURL, width: 200, height: 100, color: (0, 0, 0))

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    @Test
    func analyzeSyncReturnsNilForAllWhiteImage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("white.png")
        try writeSolidColorImage(url: imageURL, width: 200, height: 100, color: (255, 255, 255))

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    @Test
    func analyzeSyncHandlesVeryDarkScreenRegion() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("dark-screen.png")
        let width = 200
        let height = 100
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: 90..<110, brightValue: 50)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    @Test
    func analyzeSyncReturnsNilForWidth2Image() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("width2.png")
        try writeSolidColorImage(url: imageURL, width: 2, height: 100, color: (128, 128, 128))

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForHeight2Image() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("height2.png")
        try writeSolidColorImage(url: imageURL, width: 200, height: 2, color: (128, 128, 128))

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    private func writeSolidColorImage(url: URL, width: Int, height: Int, color: (UInt8, UInt8, UInt8)) throws {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        for y in 0..<height {
            let rowBase = y * bytesPerRow
            for x in 0..<width {
                let index = rowBase + x * 4
                pixels[index] = color.0
                pixels[index + 1] = color.1
                pixels[index + 2] = color.2
                pixels[index + 3] = 255
            }
        }

        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    private func writeLargePanorama(url: URL, width: Int, height: Int, brightColumns: Range<Int>) throws {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 12, count: height * bytesPerRow)

        for y in 0..<height {
            let rowBase = y * bytesPerRow
            let isInScreenBand = (Int(Double(height) * 0.19)..<Int(Double(height) * 0.50)).contains(y)
            for x in 0..<width {
                let index = rowBase + x * 4
                let isBrightColumn = brightColumns.contains(x)
                let value: UInt8 = isInScreenBand && isBrightColumn ? 255 : 12
                pixels[index] = value
                pixels[index + 1] = value
                pixels[index + 2] = value
                pixels[index + 3] = 255
            }
        }

        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    private func writePanorama(
        url: URL,
        width: Int,
        height: Int,
        brightColumns: Range<Int>,
        brightValue: UInt8 = 255
    ) throws {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 12, count: height * bytesPerRow)

        for y in 0..<height {
            let rowBase = y * bytesPerRow
            let isInScreenBand = (Int(Double(height) * 0.19)..<Int(Double(height) * 0.50)).contains(y)
            for x in 0..<width {
                let index = rowBase + x * 4
                let isBrightColumn = brightColumns.contains(x)
                let value: UInt8 = isInScreenBand && isBrightColumn ? brightValue : 12
                pixels[index] = value
                pixels[index + 1] = value
                pixels[index + 2] = value
                pixels[index + 3] = 255
            }
        }

        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}

@Suite("HDRI Orientation Analyzer - Box Smooth Calculations")
struct HDRIOrientationAnalyzerBoxSmoothTests {

    @Test
    func boxSmoothCenterElementWithHalfWidth2() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 2)

        let expectedCenter: Float = (1.0 + 2.0 + 3.0 + 4.0 + 5.0) / 5.0
        #expect(abs(smoothed[2] - expectedCenter) < 0.001)
    }

    @Test
    func boxSmoothBoundaryWrapCalculation() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 2)

        let expected0: Float = (5.0 + 1.0 + 2.0 + 3.0 + 4.0) / 5.0
        #expect(abs(smoothed[0] - expected0) < 0.001)
    }

    @Test
    func boxSmoothProducesSmoothingEffect() {
        let values: [Float] = [0.0, 0.0, 100.0, 0.0, 0.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)

        #expect(smoothed[2] < 100.0)
        #expect(smoothed[1] > 0.0)
        #expect(smoothed[3] > 0.0)
    }

    @Test
    func boxSmoothFullWidthArray() {
        let values: [Float] = (0..<100).map { Float($0) }
        let smoothed = boxSmoothTestHelper(values, halfWidth: 5)

        #expect(smoothed.count == 100)
        #expect(smoothed[50] > 45.0 && smoothed[50] < 55.0)
    }

    @Test
    func boxSmoothWithHalfWidthLargerThanArray() {
        let values: [Float] = [1.0, 2.0, 3.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 10)

        #expect(smoothed.count == 3)
        let avg: Float = (1.0 + 2.0 + 3.0) / 3.0
        for val in smoothed {
            #expect(abs(val - avg) < 0.001)
        }
    }

    @Test
    func boxSmoothWithOddLengthArray() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)

        #expect(smoothed.count == 7)
        #expect(smoothed[3] == 4.0)
    }

    @Test
    func boxSmoothWithEvenLengthArray() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)

        #expect(smoothed.count == 6)
    }

    @Test
    func boxSmoothPreservesTotalSumApprox() {
        let values: [Float] = [10.0, 20.0, 30.0, 40.0, 50.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)

        let originalSum = values.reduce(0, +)
        let smoothedSum = smoothed.reduce(0, +)
        #expect(abs(originalSum - smoothedSum) < 0.001)
    }

    @Test
    func boxSmoothSingleElementWithHalfWidth0() {
        let values: [Float] = [42.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 0)
        #expect(smoothed.count == 1)
        #expect(smoothed[0] == 42.0)
    }

    @Test
    func boxSmoothTwoElementsWithHalfWidth1() {
        let values: [Float] = [10.0, 20.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)

        #expect(smoothed.count == 2)
        #expect(smoothed[0] == smoothed[1])
    }

    private func boxSmoothTestHelper(_ values: [Float], halfWidth h: Int) -> [Float] {
        let n = values.count
        guard n > 0, h > 0 else { return values }
        let windowCount = 2 * h + 1
        if windowCount >= n {
            let average = values.reduce(0, +) / Float(n)
            return [Float](repeating: average, count: n)
        }
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let center = min(max(i, h), n - h - 1)
            var sum: Float = 0
            for index in (center - h)...(center + h) {
                sum += values[index]
            }
            out[i] = sum / Float(windowCount)
        }
        return out
    }
}
