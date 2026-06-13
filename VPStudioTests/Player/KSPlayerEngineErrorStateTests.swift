import Foundation
import Testing
import KSPlayer
@testable import VPStudio

// MARK: - Timeout Edge Cases

@Suite("KSPlayerEngine - Timeout Edge Cases")
struct KSPlayerEngineTimeoutEdgeCaseTests {

    @Test func uppercaseExtensionGetsContainerTimeout() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.MKV",
            fileName: "Movie.1080p.MKV"
        )
        #expect(KSPlayerEngine.timeout(for: stream) == 18)
    }

    @Test func mixedCaseExtensionGetsContainerTimeout() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.Mkv",
            fileName: "Movie.1080p.Mkv"
        )
        #expect(KSPlayerEngine.timeout(for: stream) == 18)
    }

    @Test func urlWithQueryStringUsesPathExtension() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mkv?token=abc123",
            fileName: "Movie.1080p.mkv"
        )
        #expect(KSPlayerEngine.timeout(for: stream) == 18)
    }

    @Test func urlWithFragmentUsesPathExtension() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mkv#segment",
            fileName: "Movie.1080p.mkv"
        )
        #expect(KSPlayerEngine.timeout(for: stream) == 18)
    }

    @Test func urlWithoutExtensionGetsDefaultTimeout() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie",
            fileName: "movie"
        )
        #expect(KSPlayerEngine.timeout(for: stream) == 12)
    }

    @Test func highDemandWithQueryStringStillReturns24s() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mkv?token=abc",
            quality: .uhd4k,
            fileName: "Movie.4K.UHD.mkv"
        )
        #expect(KSPlayerEngine.timeout(for: stream) == 24)
    }
}

// MARK: - Tuning Profile Edge Cases

@Suite("KSPlayerEngine - Tuning Profile Edge Cases")
struct KSPlayerEngineTuningProfileEdgeCaseTests {

    @Test func av1CodecTriggersHighDemandProfile() {
        let stream = Fixtures.stream(codec: .av1, fileName: "Movie.AV1.1080p.mkv")
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.preferredForwardBufferDuration == 2.0)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.preferredForwardBufferDuration == 3.0)
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.probesize == 6_000_000)
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func dolbyVisionTriggersHighDemandProfile() {
        let stream = Fixtures.stream(hdr: .dolbyVision, fileName: "Movie.DV.1080p.mkv")
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func hdr10PlusTriggersHighDemandProfile() {
        let stream = Fixtures.stream(hdr: .hdr10Plus, fileName: "Movie.HDR10Plus.1080p.mkv")
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func atmosAudioTriggersHighDemandProfile() {
        let stream = Fixtures.stream(audio: .atmos, fileName: "Movie.Atmos.1080p.mkv")
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func trueHDAudioTriggersHighDemandProfile() {
        let stream = Fixtures.stream(audio: .trueHD, fileName: "Movie.TrueHD.1080p.mkv")
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func dtsHDMAAudioTriggersHighDemandProfile() {
        let stream = Fixtures.stream(audio: .dtsHDMA, fileName: "Movie.DTS-HDMA.1080p.mkv")
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func bdremuxFilenameTriggersHighDemandProfile() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "Movie.2025.BDRemux.1080p.mp4"
        )
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #if os(visionOS)
        #expect(profile.maxBufferDuration == 10.0)
        #else
        #expect(profile.maxBufferDuration == 16.0)
        #endif
        #expect(profile.autoSelectEmbedSubtitle == false)
    }

    @Test func defaultProfileEnablesAutoSelectEmbedSubtitle() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            quality: .hd1080p,
            hdr: .sdr,
            fileName: "Movie.1080p.WEBDL.mp4"
        )
        let profile = KSPlayerEngine.tuningProfile(for: stream)

        #expect(profile.autoSelectEmbedSubtitle == true)
    }
}

// MARK: - Readiness Poll

@Suite("KSPlayerEngine - Readiness Poll")
@MainActor
struct KSPlayerEngineReadinessPollTests {

    @Test func waitUntilReadyRejectsZeroTimeout() async {
        let coordinator = KSVideoPlayer.Coordinator()

        do {
            try await KSPlayerEngine.waitUntilReady(
                coordinator: coordinator,
                timeout: 0,
                failureMessage: { nil }
            )
            Issue.record("Expected non-positive timeout to fail.")
        } catch PlayerEngineError.initializationFailed(let kind, let message) {
            #expect(kind == .ksPlayer)
            #expect(message.contains("Invalid readiness timeout"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func waitUntilReadyRejectsNegativeTimeout() async {
        let coordinator = KSVideoPlayer.Coordinator()

        do {
            try await KSPlayerEngine.waitUntilReady(
                coordinator: coordinator,
                timeout: -1,
                failureMessage: { nil }
            )
            Issue.record("Expected non-positive timeout to fail.")
        } catch PlayerEngineError.initializationFailed(let kind, let message) {
            #expect(kind == .ksPlayer)
            #expect(message.contains("Invalid readiness timeout"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func waitUntilReadyTimesOutForDefaultCoordinatorState() async {
        let coordinator = KSVideoPlayer.Coordinator()

        do {
            try await KSPlayerEngine.waitUntilReady(
                coordinator: coordinator,
                timeout: 0.01,
                pollInterval: .milliseconds(5),
                failureMessage: { nil }
            )
            Issue.record("Expected readiness wait to time out.")
        } catch PlayerEngineError.startupTimeout(let kind) {
            #expect(kind == .ksPlayer)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func waitUntilReadyReportsPreparingStateViaOnState() async {
        let coordinator = KSVideoPlayer.Coordinator()
        var capturedStates: [PlayerPlaybackState] = []
        var capturedMessages: [String?] = []

        do {
            try await KSPlayerEngine.waitUntilReady(
                coordinator: coordinator,
                timeout: 0.05,
                pollInterval: .milliseconds(10),
                onState: { state, message in
                    capturedStates.append(state)
                    capturedMessages.append(message)
                },
                failureMessage: { nil }
            )
            Issue.record("Expected readiness wait to time out.")
        } catch PlayerEngineError.startupTimeout(let kind) {
            #expect(kind == .ksPlayer)
            #expect(capturedStates.contains(.preparing))
            #expect(capturedMessages.contains("Initializing KSPlayer."))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func waitUntilReadyPropagatesCancellation() async {
        let coordinator = KSVideoPlayer.Coordinator()

        let task = Task {
            try await KSPlayerEngine.waitUntilReady(
                coordinator: coordinator,
                timeout: 10,
                pollInterval: .milliseconds(10),
                failureMessage: { nil }
            )
        }

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation to propagate.")
        } catch is CancellationError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - Error Handling Contracts

@Suite("KSPlayerEngine - Error Handling Contracts")
struct KSPlayerEngineErrorHandlingContractTests {

    @Test func waitUntilReadySourceContainsErrorStateCase() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        #expect(source.contains("case .error:"))
    }

    @Test func waitUntilReadySourceContainsGracePeriodSleep() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        #expect(source.contains("try await Task.sleep(for: .milliseconds(100))"))
    }

    @Test func waitUntilReadySourceContainsDetailErrorMessage() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        #expect(source.contains("\"KSPlayer decode error: \\(detail)\""))
    }

    @Test func waitUntilReadySourceContainsFallbackErrorMessage() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        #expect(source.contains("\"KSPlayer failed to initialize (no error detail from decoder)\""))
    }

    @Test func waitUntilReadySourceThrowsInitializationFailedForError() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        let errorSection = try section(from: "case .error:", to: "try await Task.sleep(for: pollInterval)", in: source)
        #expect(errorSection.contains("throw PlayerEngineError.initializationFailed(.ksPlayer, message)"))
    }

    @Test func waitUntilReadySourceThrowsStartupTimeoutAfterLoop() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        #expect(source.contains("throw PlayerEngineError.startupTimeout(.ksPlayer)"))
    }

    @Test func waitUntilReadySourceChecksFailureMessageBeforeGracePeriod() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        let errorSection = try section(from: "case .error:", to: "try await Task.sleep(for: pollInterval)", in: source)
        #expect(errorSection.contains("if failureMessage() == nil {"))
        #expect(errorSection.contains("try await Task.sleep(for: .milliseconds(100))"))
    }

    @Test func waitUntilReadySourceHandlesNilAndEmptyDetail() throws {
        let source = try contents(of: "VPStudio/Services/Player/Engines/KSPlayerEngine.swift")
        let errorSection = try section(from: "case .error:", to: "try await Task.sleep(for: pollInterval)", in: source)
        #expect(errorSection.contains("if let detail, !detail.isEmpty {"))
    }
}

// MARK: - Source Helpers

private func contents(of relativePath: String) throws -> String {
    let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
    return try String(contentsOfFile: absolutePath, encoding: .utf8)
}

private func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { break }
        url = parent
    }
    return url
}

private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
    guard let startRange = source.range(of: startToken) else {
        throw NSError(
            domain: "KSPlayerEngineErrorHandlingContractTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing start token: \(startToken)"]
        )
    }
    guard let endRange = source.range(of: endToken, range: startRange.upperBound..<source.endIndex) else {
        throw NSError(
            domain: "KSPlayerEngineErrorHandlingContractTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing end token: \(endToken)"]
        )
    }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}
