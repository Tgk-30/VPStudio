import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VPStudio

@Suite("HDRI Orientation Analyzer Dominant Column Fallback")
struct HDRIOrientationAnalyzerDominantColumnFallbackTests {

    @Test
    func detectScreenYawFallsBackToFrontForLeftEdgePeak() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("front-edge.png")
        let width = 200
        let height = 100
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: 0..<8)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(abs(yaw) < 20)
    }

    @Test
    func detectScreenYawFallsBackToBackForRightEdgePeak() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("back-edge.png")
        let width = 200
        let height = 100
        try writePanorama(url: imageURL, width: width, height: height, brightColumns: 192..<200)

        let yaw = try #require(await HDRIOrientationAnalyzer.detectScreenYaw(at: imageURL))

        #expect(abs(yaw - 180) < 20)
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
