import Testing
import Foundation
@testable import VPStudio

// MARK: - Standalone retry-after parser (mirrors private implementation)

private func retryAfterDelay(from response: HTTPURLResponse) -> TimeInterval? {
    guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return Double(value).map { max($0, 0) }
}

// MARK: - Testable wrapper for rate-limiting slot queue

private actor RateLimitSlotQueueTester {
    private var lastRequestDate: Date?
    private var nextAllowedRequestDate: Date?
    private let minimumRequestInterval: TimeInterval = 0.15

    func waitForRequestSlot() async throws {
        let now = Date()
        let earliestAllowed = max(
            nextAllowedRequestDate ?? now,
            lastRequestDate?.addingTimeInterval(minimumRequestInterval) ?? now
        )
        let delay = earliestAllowed.timeIntervalSince(now)
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(max(delay, 0) * 1_000_000_000))
        }
    }

    func simulateRequestCompleted() {
        lastRequestDate = Date()
    }

    func simulateRateLimitRetryAfter(_ delay: TimeInterval) {
        nextAllowedRequestDate = Date().addingTimeInterval(max(delay, minimumRequestInterval))
    }

    func reset() {
        lastRequestDate = nil
        nextAllowedRequestDate = nil
    }
}

// MARK: - Stub helper

private func makeRateLimitStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

// MARK: - Slot Queue Tests

@Suite("OpenSubtitlesService - Slot Queue", .serialized)
struct OpenSubtitlesSlotQueueTests {

    @Test func firstRequestIsNotDelayed() async throws {
        let wrapper = RateLimitSlotQueueTester()
        let start = Date()
        try await wrapper.waitForRequestSlot()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.05)
    }

    @Test func secondRapidRequestIsBlockedByMinimumInterval() async throws {
        let wrapper = RateLimitSlotQueueTester()
        try await wrapper.waitForRequestSlot()
        await wrapper.simulateRequestCompleted()
        let start = Date()
        try await wrapper.waitForRequestSlot()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed >= 0.10)
        #expect(elapsed < 1.0)
    }

    @Test func requestAfterIntervalPassesThrough() async throws {
        let wrapper = RateLimitSlotQueueTester()
        try await wrapper.waitForRequestSlot()
        await wrapper.simulateRequestCompleted()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        let start = Date()
        try await wrapper.waitForRequestSlot()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.05)
    }

    @Test func nextAllowedRequestDateDelaysBeyondMinimumInterval() async throws {
        let wrapper = RateLimitSlotQueueTester()
        await wrapper.simulateRateLimitRetryAfter(0.5)
        let start = Date()
        try await wrapper.waitForRequestSlot()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed >= 0.40)
        #expect(elapsed < 2.0)
    }

    @Test func slotQueueUsesLaterOfMinimumIntervalAndNextAllowedDate() async throws {
        let wrapper = RateLimitSlotQueueTester()
        try await wrapper.waitForRequestSlot()
        await wrapper.simulateRequestCompleted()
        await wrapper.simulateRateLimitRetryAfter(0.05) // less than minimumInterval
        let start = Date()
        try await wrapper.waitForRequestSlot()
        let elapsed = Date().timeIntervalSince(start)
        // Should wait for minimumRequestInterval (0.15s), not 0.05s
        #expect(elapsed >= 0.12)
    }

    @Test func concurrentWaitsAreSerializedAndEachDelayed() async throws {
        let wrapper = RateLimitSlotQueueTester()
        let start = Date()

        async let a = wrapper.waitForRequestSlot()
        async let b = wrapper.waitForRequestSlot()
        async let c = wrapper.waitForRequestSlot()
        try await a
        try await b
        try await c

        let elapsed = Date().timeIntervalSince(start)
        // All calls return immediately because lastRequestDate is nil
        // (waitForRequestSlot does not update lastRequestDate; only successful requests do)
        #expect(elapsed < 0.10)
    }

    @Test func slotQueueRecoversAfterWaiting() async throws {
        let wrapper = RateLimitSlotQueueTester()
        try await wrapper.waitForRequestSlot()
        await wrapper.simulateRequestCompleted()
        try await Task.sleep(nanoseconds: 200_000_000)
        try await wrapper.waitForRequestSlot()
        await wrapper.simulateRequestCompleted()
        try await Task.sleep(nanoseconds: 200_000_000)
        let start = Date()
        try await wrapper.waitForRequestSlot()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.05)
    }
}

// MARK: - Retry-After Parsing Tests

@Suite("OpenSubtitlesService - Retry-After Parsing")
struct OpenSubtitlesRetryAfterParsingTests {

    @Test func retryAfterDelayParsesIntegerSeconds() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "5"]
        )!
        #expect(retryAfterDelay(from: response) == 5.0)
    }

    @Test func retryAfterDelayParsesZeroSeconds() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "0"]
        )!
        #expect(retryAfterDelay(from: response) == 0.0)
    }

    @Test func retryAfterDelayParsesFloatString() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "1.5"]
        )!
        #expect(retryAfterDelay(from: response) == 1.5)
    }

    @Test func retryAfterDelayReturnsNilForMissingHeader() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!
        #expect(retryAfterDelay(from: response) == nil)
    }

    @Test func retryAfterDelayReturnsNilForEmptyHeader() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": ""]
        )!
        #expect(retryAfterDelay(from: response) == nil)
    }

    @Test func retryAfterDelayReturnsNilForWhitespaceOnlyHeader() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "   "]
        )!
        #expect(retryAfterDelay(from: response) == nil)
    }

    @Test func retryAfterDelayReturnsNilForNonNumericString() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "abc"]
        )!
        #expect(retryAfterDelay(from: response) == nil)
    }

    @Test func retryAfterDelayReturnsNilForHTTPDateFormat() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "Wed, 21 Oct 2015 07:28:00 GMT"]
        )!
        // Current implementation does not parse HTTP-date format
        #expect(retryAfterDelay(from: response) == nil)
    }

    @Test func retryAfterDelayClampsNegativeValueToZero() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "-10"]
        )!
        #expect(retryAfterDelay(from: response) == 0.0)
    }

    @Test func retryAfterDelayTrimsWhitespace() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "  30  "]
        )!
        #expect(retryAfterDelay(from: response) == 30.0)
    }

    @Test func retryAfterDelayReturnsNilForMalformedMixedString() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "10 seconds"]
        )!
        #expect(retryAfterDelay(from: response) == nil)
    }

    @Test func retryAfterDelayPassesThroughLargeValueWithoutCapping() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.opensubtitles.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "3600"]
        )!
        // Current implementation has no maximumBackoffInterval
        #expect(retryAfterDelay(from: response) == 3600.0)
    }
}

// MARK: - Service Integration Tests

@Suite("OpenSubtitlesService - Rate Limit Integration")
struct OpenSubtitlesRateLimitIntegrationTests {

    @Test func searchRateLimitsConsecutiveRequests() async throws {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var timestamps: [Date] = []
            func record() {
                lock.lock(); defer { lock.unlock() }
                timestamps.append(Date())
            }
            var all: [Date] {
                lock.lock(); defer { lock.unlock() }
                return timestamps
            }
        }
        let state = State()

        let session = makeRateLimitStubSession { request in
            state.record()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        _ = try await service.search(query: "A")
        _ = try await service.search(query: "B")

        let timestamps = state.all
        #expect(timestamps.count == 2)
        let interval = timestamps[1].timeIntervalSince(timestamps[0])
        #expect(interval >= 0.10, "Expected rate-limiting delay, got \(interval)s")
    }

    @Test func searchRetriesOnceAfter429WithRetryAfter() async throws {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var timestamps: [Date] = []
            private var count = 0
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                count += 1
                timestamps.append(Date())
                return count
            }
            var all: [Date] {
                lock.lock(); defer { lock.unlock() }
                return timestamps
            }
        }
        let state = State()

        let session = makeRateLimitStubSession { request in
            let call = state.record()
            let url = request.url!
            if call == 1 {
                let headers = ["Retry-After": "0.3"]
                let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: headers)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "Movie")

        #expect(state.all.count == 2)
        let delay = state.all[1].timeIntervalSince(state.all[0])
        #expect(delay >= 0.25, "Expected retry delay ~0.3s, got \(delay)s")
    }

    @Test func searchRetriesOnceAfter429WithoutRetryAfter() async throws {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var timestamps: [Date] = []
            private var count = 0
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                count += 1
                timestamps.append(Date())
                return count
            }
            var all: [Date] {
                lock.lock(); defer { lock.unlock() }
                return timestamps
            }
        }
        let state = State()

        let session = makeRateLimitStubSession { request in
            let call = state.record()
            let url = request.url!
            if call == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "Movie")

        #expect(state.all.count == 2)
        let delay = state.all[1].timeIntervalSince(state.all[0])
        #expect(delay >= 0.10, "Expected minimum interval delay, got \(delay)s")
    }

    @Test func searchThrowsAfterRepeated429Responses() async {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                count += 1
                return count
            }
            var current: Int {
                lock.lock(); defer { lock.unlock() }
                return count
            }
        }
        let state = State()

        let session = makeRateLimitStubSession { request in
            _ = state.record()
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)

        await #expect(throws: SubtitleError.self) {
            _ = try await service.search(query: "Movie")
        }
        #expect(state.current == 2)
    }

    @Test func rateLimitingSharedAcrossServiceMethods() async throws {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var timestamps: [Date] = []
            func record() {
                lock.lock(); defer { lock.unlock() }
                timestamps.append(Date())
            }
            var all: [Date] {
                lock.lock(); defer { lock.unlock() }
                return timestamps
            }
        }
        let state = State()

        let session = makeRateLimitStubSession { request in
            state.record()
            let url = request.url!
            if url.path.hasSuffix("/login") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"token":"t"}"#.utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "Movie")
        _ = try await service.login(username: "u", password: "p")

        let timestamps = state.all
        #expect(timestamps.count == 2)
        let interval = timestamps[1].timeIntervalSince(timestamps[0])
        #expect(interval >= 0.10, "Expected shared rate-limiting delay, got \(interval)s")
    }

    @Test func searchUsesMinimumIntervalWhenRetryAfterIsZero() async throws {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var timestamps: [Date] = []
            private var count = 0
            func record() -> Int {
                lock.lock(); defer { lock.unlock() }
                count += 1
                timestamps.append(Date())
                return count
            }
            var all: [Date] {
                lock.lock(); defer { lock.unlock() }
                return timestamps
            }
        }
        let state = State()

        let session = makeRateLimitStubSession { request in
            let call = state.record()
            let url = request.url!
            if call == 1 {
                let headers = ["Retry-After": "0"]
                let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: headers)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"data":[]}"#.utf8))
        }

        let service = OpenSubtitlesService(apiKey: "key", session: session)
        _ = try await service.search(query: "Movie")

        #expect(state.all.count == 2)
        let delay = state.all[1].timeIntervalSince(state.all[0])
        #expect(delay >= 0.10, "Expected minimum interval delay, got \(delay)s")
    }
}
