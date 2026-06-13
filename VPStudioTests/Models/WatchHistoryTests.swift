import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("WatchHistory Properties")
struct WatchHistoryModelTests {
    @Test
    func progressPercent() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,  // 25 minutes
            duration: 6000.0,  // 100 minutes
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.progressPercent == 0.25)
    }

    @Test
    func progressPercentClampsOutOfBoundsAndInvalidValues() {
        let tooLong = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 9000,
            duration: 300,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(tooLong.progressPercent == 1.0)

        let invalid = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: .infinity,
            duration: .infinity,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(invalid.progressPercent == 0)
    }

    @Test
    func progressPercentZeroDuration() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,
            duration: 0.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.progressPercent == 0.0)
    }

    @Test
    func progressPercentCapping() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 7000.0,  // More than duration
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.progressPercent == 1.0)
    }

    @Test
    func progressString() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,  // 25 minutes
            duration: 6000.0,  // 100 minutes
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.progressString == "25m / 100m")
    }

    @Test
    func remainingString() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,  // 25 minutes
            duration: 6000.0,  // 100 minutes
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.remainingString == "75m remaining")
    }

    @Test
    func remainingStringNegative() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 7000.0,  // More than duration
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.remainingString == "0m remaining")
    }

    @Test
    func databaseTableName() {
        #expect(WatchHistory.databaseTableName == "watch_history")
    }

    @Test
    func identifiableConformance() {
        let history = WatchHistory(
            id: "test-123",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 0.0,
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.id == "test-123")
    }

    @Test
    func equatableConformance() {
        let now = Date()
        let history1 = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,
            duration: 6000.0,
            watchedAt: now,
            isCompleted: false
        )

        let history2 = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,
            duration: 6000.0,
            watchedAt: now,
            isCompleted: false
        )

        #expect(history1 == history2)
    }
}

@Suite("WatchHistory Row Initialization")
struct WatchHistoryRowInitializationTests {
    @Test
    func rowInitializerPreservesStoredFieldsAndTrimsOptionalStrings() {
        let watchedAt = Date(timeIntervalSince1970: 123456789)
        let row = Row([
            "id": "history-row",
            "mediaId": "media-row",
            "episodeId": "episode-row",
            "title": "Episode Row",
            "progress": 120.0,
            "duration": 600.0,
            "quality": "  4K  ",
            "debridService": "  real_debrid  ",
            "streamURL": "  https://cdn.example.com/video.mkv  ",
            "watchedAt": watchedAt,
            "isCompleted": true,
        ])

        let history = WatchHistory(row: row)

        #expect(history.id == "history-row")
        #expect(history.mediaId == "media-row")
        #expect(history.episodeId == "episode-row")
        #expect(history.title == "Episode Row")
        #expect(history.progress == 120)
        #expect(history.duration == 600)
        #expect(history.quality == "4K")
        #expect(history.debridService == "real_debrid")
        #expect(history.streamURL == "https://cdn.example.com/video.mkv")
        #expect(history.watchedAt == watchedAt)
        #expect(history.isCompleted)
        #expect(history.hasFiniteNumericValues)
    }

    @Test
    func rowInitializerFallsBackForMissingValuesAndSanitizesInvalidNumbers() {
        let before = Date()
        let row = Row([
            "id": nil,
            "mediaId": nil,
            "episodeId": nil,
            "title": nil,
            "progress": Double.infinity,
            "duration": Double.infinity,
            "quality": " ",
            "debridService": "\n",
            "streamURL": "\t",
            "watchedAt": nil,
            "isCompleted": nil,
        ])

        let history = WatchHistory(row: row)

        #expect(!history.id.isEmpty)
        #expect(history.mediaId == "")
        #expect(history.episodeId == nil)
        #expect(history.title == "")
        #expect(history.progress == 0)
        #expect(history.duration == 0)
        #expect(history.quality == nil)
        #expect(history.debridService == nil)
        #expect(history.streamURL == nil)
        #expect(history.watchedAt >= before)
        #expect(history.isCompleted == false)
        #expect(history.hasFiniteNumericValues == false)
    }
}

@Suite("WatchHistory Initialization")
struct WatchHistoryInitializationTests {
    @Test
    func negativeProgressNormalization() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: -100.0,
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.progress == 0.0)
    }

    @Test
    func progressExceedsDuration() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 7000.0,
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.progress == 6000.0)
    }

    @Test
    func negativeDurationNormalization() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,
            duration: -1000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.duration == 0.0)
        #expect(history.progress == 1500.0)  // Progress not capped when duration is 0
    }

    @Test
    func optionalStringNormalization() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 0.0,
            duration: 6000.0,
            quality: "  1080p  ",
            debridService: "  RealDebrid  ",
            streamURL: "  https://example.com  ",
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.quality == "1080p")
        #expect(history.debridService == "RealDebrid")
        #expect(history.streamURL == "https://example.com")
    }

    @Test
    func emptyStringNormalization() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 0.0,
            duration: 6000.0,
            quality: "   ",
            debridService: "",
            streamURL: "\n\t",
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(history.quality == nil)
        #expect(history.debridService == nil)
        #expect(history.streamURL == nil)
    }

    @Test
    func nonFiniteInitializationValuesAreSanitized() {
        let history = WatchHistory(
            id: "test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: .infinity,
            duration: .infinity,
            watchedAt: Date(),
            isCompleted: false
        )

        #expect(history.duration == 0)
        #expect(history.progress == 0)
        #expect(history.hasFiniteNumericValues == false)
    }
}

@Suite("WatchHistory Codable")
struct WatchHistoryCodableTests {
    @Test
    func codableRoundTrip() throws {
        let original = WatchHistory(
            id: "history-123",
            mediaId: "media-456",
            episodeId: "episode-789",
            title: "Test Episode",
            progress: 1500.0,
            duration: 6000.0,
            quality: "1080p",
            debridService: "RealDebrid",
            streamURL: "https://example.com/stream",
            watchedAt: Date(timeIntervalSince1970: 123456789),
            isCompleted: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchHistory.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.mediaId == original.mediaId)
        #expect(decoded.episodeId == original.episodeId)
        #expect(decoded.title == original.title)
        #expect(decoded.progress == original.progress)
        #expect(decoded.duration == original.duration)
        #expect(decoded.quality == original.quality)
        #expect(decoded.debridService == original.debridService)
        #expect(decoded.streamURL == original.streamURL)
        #expect(decoded.watchedAt == original.watchedAt)
        #expect(decoded.isCompleted == original.isCompleted)
    }

    @Test
    func codableWithNilOptionals() throws {
        let original = WatchHistory(
            id: "history-123",
            mediaId: "media-456",
            episodeId: nil,
            title: "Test Movie",
            progress: 0.0,
            duration: 6000.0,
            quality: nil,
            debridService: nil,
            streamURL: nil,
            watchedAt: Date(),
            isCompleted: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchHistory.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.mediaId == original.mediaId)
        #expect(decoded.episodeId == nil)
        #expect(decoded.title == original.title)
        #expect(decoded.progress == original.progress)
        #expect(decoded.duration == original.duration)
        #expect(decoded.quality == nil)
        #expect(decoded.debridService == nil)
        #expect(decoded.streamURL == nil)
        #expect(decoded.isCompleted == original.isCompleted)
    }
}

@Suite("WatchHistory Database Round-Trip")
struct WatchHistoryDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "watch-history-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test
    func roundTripsBasicHistory() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let history = WatchHistory(
            id: "history-1",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 1500.0,
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        try await database.saveWatchHistory(history)
        let fetched = try await database.fetchWatchHistory(mediaId: "media-123")

        #expect(fetched != nil)
        #expect(fetched?.id == history.id)
        #expect(fetched?.mediaId == history.mediaId)
        #expect(fetched?.title == history.title)
        #expect(fetched?.progress == history.progress)
        #expect(fetched?.duration == history.duration)
    }

    @Test
    func roundTripsFullHistory() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let history = WatchHistory(
            id: "full-history",
            mediaId: "series-456",
            episodeId: "episode-789",
            title: "Test Episode",
            progress: 3000.0,
            duration: 6000.0,
            quality: "1080p",
            debridService: "RealDebrid",
            streamURL: "https://example.com/stream",
            watchedAt: Date(timeIntervalSince1970: 123456789),
            isCompleted: true
        )
        try await database.saveWatchHistory(history)
        let fetched = try await database.fetchWatchHistory(mediaId: "series-456", episodeId: "episode-789")

        #expect(fetched != nil)
        #expect(fetched?.episodeId == "episode-789")
        #expect(fetched?.quality == "1080p")
        #expect(fetched?.debridService == "RealDebrid")
        #expect(fetched?.streamURL == nil)
        #expect(fetched?.isCompleted == true)
    }

    @Test
    func roundTripsMultipleHistories() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let histories = [
            WatchHistory(id: "h1", mediaId: "m1", title: "Movie 1", progress: 0.0, duration: 6000.0, watchedAt: Date(), isCompleted: false),
            WatchHistory(id: "h2", mediaId: "m2", title: "Movie 2", progress: 3000.0, duration: 6000.0, watchedAt: Date(), isCompleted: false),
            WatchHistory(id: "h3", mediaId: "m3", title: "Movie 3", progress: 6000.0, duration: 6000.0, watchedAt: Date(), isCompleted: true)
        ]

        for history in histories {
            try await database.saveWatchHistory(history)
        }

        let fetched = try await database.fetchWatchHistory(limit: 100)
        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.id == "h1" })
        #expect(fetched.contains { $0.id == "h2" })
        #expect(fetched.contains { $0.id == "h3" })
    }

    @Test
    func roundTripsUpdatedProgress() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let history = WatchHistory(
            id: "progress-test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 0.0,
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: false
        )
        try await database.saveWatchHistory(history)

        var updated = history
        updated.progress = 3000.0
        try await database.saveWatchHistory(updated)

        let fetched = try await database.fetchWatchHistory(mediaId: "media-123")
        #expect(fetched?.progress == 3000.0)
    }

    @Test
    func roundTripsCompletedHistory() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let history = WatchHistory(
            id: "completed-test",
            mediaId: "media-123",
            title: "Test Movie",
            progress: 6000.0,
            duration: 6000.0,
            watchedAt: Date(),
            isCompleted: true
        )
        try await database.saveWatchHistory(history)
        let fetched = try await database.fetchWatchHistory(mediaId: "media-123")

        #expect(fetched != nil)
        #expect(fetched?.isCompleted == true)
        #expect(fetched?.progress == 6000.0)
    }
}
