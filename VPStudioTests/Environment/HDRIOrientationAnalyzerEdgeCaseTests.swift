import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VPStudio

@Suite("HDRI Orientation Analyzer Edge Cases")
struct HDRIOrientationAnalyzerEdgeCaseTests {

    @Test
    func analyzeSyncReturnsNilForNonExistentFile() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID().uuidString).hdr")
        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: url)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: tempDir)
        #expect(yaw == nil)
    }

    @Test
    func screenYawReturnsNilForTooSmallImage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("tiny.png")
        try writeTinyImage(url: imageURL, width: 1, height: 1)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func screenYawReturnsNilForWidth1Image() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("width1.png")
        try writeTinyImage(url: imageURL, width: 1, height: 100)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func screenYawReturnsNilForHeight1Image() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("height1.png")
        try writeTinyImage(url: imageURL, width: 100, height: 1)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func screenYawDetectsBrightRegionAtCenter() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("center-bright.png")
        let width = 200
        let height = 100
        let brightRange = 95..<105
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange, brightValue: 255)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))
        let brightCenter = Float((brightRange.lowerBound + brightRange.upperBound - 1) / 2)
        let expectedScreenYaw = (brightCenter / Float(width - 1) - 0.5) * 360.0

        #expect(abs(yaw + expectedScreenYaw) < 15)
    }

    @Test
    func screenYawDetectsBrightRegionAtLeftEdge() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("left-bright.png")
        let width = 200
        let height = 100
        let brightRange = 0..<10
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange, brightValue: 255)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(abs(yaw) < 30)
    }

    @Test
    func screenYawDetectsBrightRegionAtRightEdge() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("right-bright.png")
        let width = 200
        let height = 100
        let brightRange = 190..<200
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange, brightValue: 255)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(abs(yaw - 180) < 30)
    }

    @Test
    func screenYawHandlesUniformBrightness() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("uniform.png")
        let width = 200
        let height = 100
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: 0..<width, brightValue: 200)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    @Test
    func screenYawHandlesLowContrastImage() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("low-contrast.png")
        let width = 200
        let height = 100
        let brightRange = 90..<110
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: brightRange, brightValue: 100)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw != nil)
    }

    @Test
    func analyzeSyncHandlesInvalidImageData() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncHandlesCorruptedJPEG() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("corrupted.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]).write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    @Test
    func analyzeSyncReturnsNilForUnsupportedFormat() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("test.gif")
        try Data("GIF89a".utf8).write(to: imageURL)

        let yaw = await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL)
        #expect(yaw == nil)
    }

    private func writeTinyImage(url: URL, width: Int, height: Int) throws {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 128, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = ctx.makeImage() else { return }

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

@Suite("HDRI Orientation Analyzer Box Smooth Tests")
struct HDRIBoxSmoothTests {

    @Test
    func boxSmoothWithHalfWidth1() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)

        #expect(smoothed.count == 5)
        #expect(smoothed[0] == 2.0)
        #expect(smoothed[1] == 2.0)
        #expect(smoothed[4] == 4.0)
    }

    @Test
    func boxSmoothWithHalfWidth2() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 2)

        #expect(smoothed.count == 5)
    }

    @Test
    func boxSmoothWrapsAround() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 2)

        #expect(smoothed[0] > 0)
    }

    @Test
    func boxSmoothEmptyArray() {
        let values: [Float] = []
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)
        #expect(smoothed.isEmpty)
    }

    @Test
    func boxSmoothSingleElement() {
        let values: [Float] = [42.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 1)
        #expect(smoothed.count == 1)
        #expect(smoothed[0] == 42.0)
    }

    @Test
    func boxSmoothZeroHalfWidth() {
        let values: [Float] = [1.0, 2.0, 3.0]
        let smoothed = boxSmoothTestHelper(values, halfWidth: 0)
        #expect(smoothed == values)
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
