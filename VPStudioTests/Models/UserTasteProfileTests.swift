import Foundation
import Testing
import GRDB
@testable import VPStudio

// MARK: - UserTasteProfile

@Suite("UserTasteProfile")
struct UserTasteProfileTests {

    @Test
    func defaultValues() {
        let profile = UserTasteProfile()
        #expect(profile.id == "default")
        #expect(profile.likedGenres.isEmpty)
        #expect(profile.dislikedGenres.isEmpty)
        #expect(profile.preferredDecades.isEmpty)
        #expect(profile.preferredLanguages.isEmpty)
        #expect(profile.eventCount == 0)
    }

    @Test
    func customInitValues() {
        let profile = UserTasteProfile(
            id: "user-1",
            likedGenres: ["Sci-Fi"],
            dislikedGenres: ["Horror"],
            preferredDecades: ["2020s"],
            preferredLanguages: ["English"],
            eventCount: 42
        )
        #expect(profile.id == "user-1")
        #expect(profile.likedGenres == ["Sci-Fi"])
        #expect(profile.eventCount == 42)
    }

    @Test
    func grdbDecodeFallsBackToEmptyArrays() throws {
        let row = Row([
            "id": "u1",
            "likedGenres": nil,
            "dislikedGenres": nil,
            "preferredDecades": nil,
            "preferredLanguages": nil,
            "eventCount": 0,
            "updatedAt": Date(),
        ])
        let profile = try UserTasteProfile(row: row)
        #expect(profile.likedGenres.isEmpty)
        #expect(profile.dislikedGenres.isEmpty)
    }

    @Test
    func grdbDecodeFallsBackToEmptyArraysForMalformedJSON() throws {
        let malformed = Data("not-json".utf8)
        let row = Row([
            "id": "u1",
            "likedGenres": malformed,
            "dislikedGenres": malformed,
            "preferredDecades": malformed,
            "preferredLanguages": malformed,
            "eventCount": 3,
            "updatedAt": Date(),
        ])

        let profile = try UserTasteProfile(row: row)

        #expect(profile.likedGenres == [])
        #expect(profile.dislikedGenres == [])
        #expect(profile.preferredDecades == [])
        #expect(profile.preferredLanguages == [])
        #expect(profile.eventCount == 3)
    }

    @Test
    func grdbDecodeReadsValidStoredArrays() throws {
        let row = Row([
            "id": "u2",
            "likedGenres": try JSONEncoder().encode(["Action", "Mystery"]),
            "dislikedGenres": try JSONEncoder().encode(["Horror"]),
            "preferredDecades": try JSONEncoder().encode(["1980s", "2020s"]),
            "preferredLanguages": try JSONEncoder().encode(["English", "Korean"]),
            "eventCount": 7,
            "updatedAt": Date(timeIntervalSince1970: 321),
        ])

        let profile = try UserTasteProfile(row: row)

        #expect(profile.id == "u2")
        #expect(profile.likedGenres == ["Action", "Mystery"])
        #expect(profile.dislikedGenres == ["Horror"])
        #expect(profile.preferredDecades == ["1980s", "2020s"])
        #expect(profile.preferredLanguages == ["English", "Korean"])
        #expect(profile.eventCount == 7)
        #expect(profile.updatedAt == Date(timeIntervalSince1970: 321))
    }
}

// MARK: - TasteEvent

@Suite("TasteEvent")
struct TasteEventTests {

    @Test
    func defaultInit() {
        let event = TasteEvent(eventType: .watched)
        #expect(event.userId == "default")
        #expect(event.eventType == .watched)
        #expect(event.signalStrength == 1.0)
        #expect(event.metadata == [:])
    }

    @Test
    func eventTypeRawValues() {
        #expect(TasteEvent.EventType.watched.rawValue == "watched")
        #expect(TasteEvent.EventType.rated.rawValue == "rated")
        #expect(TasteEvent.EventType.added.rawValue == "added")
        #expect(TasteEvent.EventType.removed.rawValue == "removed")
        #expect(TasteEvent.EventType.searched.rawValue == "searched")
        #expect(TasteEvent.EventType.browsed.rawValue == "browsed")
        #expect(TasteEvent.EventType.skipped.rawValue == "skipped")
    }

    @Test
    func watchedStateRawValues() {
        #expect(TasteEvent.WatchedState.watching.rawValue == "watching")
        #expect(TasteEvent.WatchedState.completed.rawValue == "completed")
        #expect(TasteEvent.WatchedState.dropped.rawValue == "dropped")
        #expect(TasteEvent.WatchedState.planToWatch.rawValue == "plan_to_watch")
    }

    @Test
    func feedbackSourceRawValues() {
        #expect(TasteEvent.FeedbackSource.manual.rawValue == "manual")
        #expect(TasteEvent.FeedbackSource.automatic.rawValue == "automatic")
        #expect(TasteEvent.FeedbackSource.ai.rawValue == "ai")
    }

    @Test
    func grdbDecodeFallsBackEventTypeToBrowsed() throws {
        let row = Row([
            "id": "e1",
            "userId": "default",
            "mediaId": nil,
            "episodeId": nil,
            "eventType": "invalid_type",
            "signalStrength": 1.0,
            "watchedState": nil,
            "feedbackScale": nil,
            "feedbackValue": nil,
            "source": nil,
            "metadata": nil,
            "createdAt": Date(),
        ])
        let event = try TasteEvent(row: row)
        #expect(event.eventType == .browsed)
    }

    @Test
    func grdbDecodeFeedbackScaleUsesFromStoredValue() throws {
        let row = Row([
            "id": "e1",
            "userId": "default",
            "mediaId": nil,
            "episodeId": nil,
            "eventType": "rated",
            "signalStrength": 1.0,
            "watchedState": nil,
            "feedbackScale": "one_to_ten",
            "feedbackValue": 8.0,
            "source": nil,
            "metadata": nil,
            "createdAt": Date(),
        ])
        let event = try TasteEvent(row: row)
        #expect(event.feedbackScale == .oneToTen)
    }

    @Test
    func grdbDecodeDropsInvalidOptionalEnumsAndMalformedMetadata() throws {
        let row = Row([
            "id": "e1",
            "userId": "default",
            "mediaId": "media-1",
            "episodeId": "episode-1",
            "eventType": "rated",
            "signalStrength": 0.5,
            "watchedState": "invalid",
            "feedbackScale": "five_star",
            "feedbackValue": 4.0,
            "source": "invalid",
            "metadata": Data("not-json".utf8),
            "createdAt": Date(),
        ])

        let event = try TasteEvent(row: row)

        #expect(event.mediaId == "media-1")
        #expect(event.episodeId == "episode-1")
        #expect(event.watchedState == nil)
        #expect(event.feedbackScale == .oneToTen)
        #expect(event.source == nil)
        #expect(event.metadata == [:])
    }

    @Test
    func grdbDecodeReadsValidOptionalEnumsAndMetadata() throws {
        let row = Row([
            "id": "e2",
            "userId": "user-2",
            "mediaId": "media-2",
            "episodeId": "episode-2",
            "eventType": "watched",
            "signalStrength": 0.75,
            "watchedState": "plan_to_watch",
            "feedbackScale": "one_to_hundred",
            "feedbackValue": 82.0,
            "source": "ai",
            "metadata": try JSONEncoder().encode(["origin": "recommendation", "rank": "1"]),
            "createdAt": Date(timeIntervalSince1970: 654),
        ])

        let event = try TasteEvent(row: row)

        #expect(event.id == "e2")
        #expect(event.userId == "user-2")
        #expect(event.mediaId == "media-2")
        #expect(event.episodeId == "episode-2")
        #expect(event.eventType == .watched)
        #expect(event.signalStrength == 0.75)
        #expect(event.watchedState == .planToWatch)
        #expect(event.feedbackScale == .oneToHundred)
        #expect(event.feedbackValue == 82)
        #expect(event.source == .ai)
        #expect(event.metadata == ["origin": "recommendation", "rank": "1"])
        #expect(event.createdAt == Date(timeIntervalSince1970: 654))
    }
}

// MARK: - FeedbackScaleMode

@Suite("FeedbackScaleMode")
struct UserTasteProfileFeedbackScaleModeTests {

    @Test
    func selectableCasesCount() {
        #expect(FeedbackScaleMode.selectableCases.count == 3)
        #expect(FeedbackScaleMode.selectableCases.contains(.likeDislike))
        #expect(FeedbackScaleMode.selectableCases.contains(.oneToTen))
        #expect(FeedbackScaleMode.selectableCases.contains(.oneToHundred))
    }

    @Test
    func fromStoredValueReturnsLikeDislikeForNil() {
        #expect(FeedbackScaleMode.fromStoredValue(nil) == .likeDislike)
    }

    @Test
    func fromStoredValueReturnsLikeDislikeForInvalid() {
        #expect(FeedbackScaleMode.fromStoredValue("invalid") == .likeDislike)
    }

    @Test
    func fromStoredValueMapsLegacyFiveStarToOneToTen() {
        #expect(FeedbackScaleMode.fromStoredValue("five_star") == .oneToTen)
    }

    @Test
    func fromStoredValueMapsLegacyTenPointToOneToTen() {
        #expect(FeedbackScaleMode.fromStoredValue("ten_point") == .oneToTen)
    }

    @Test
    func canonicalModePreservesCurrentModes() {
        #expect(FeedbackScaleMode.likeDislike.canonicalMode == .likeDislike)
        #expect(FeedbackScaleMode.oneToTen.canonicalMode == .oneToTen)
        #expect(FeedbackScaleMode.oneToHundred.canonicalMode == .oneToHundred)
    }

    @Test
    func displayNames() {
        #expect(FeedbackScaleMode.likeDislike.displayName == "Like / Dislike")
        #expect(FeedbackScaleMode.oneToTen.displayName == "1-10")
        #expect(FeedbackScaleMode.oneToHundred.displayName == "1-100")
    }

    @Test
    func legacyModesUseCanonicalOneToTenPresentation() {
        for mode in [FeedbackScaleMode.fiveStar, .tenPoint] {
            #expect(mode.canonicalMode == .oneToTen)
            #expect(mode.displayName == "1-10")
            #expect(mode.minimumValue == 1)
            #expect(mode.maximumValue == 10)
            #expect(mode.normalizedValue(10) == 1)
            #expect(mode.value(fromNormalized: 0.5) == 6)
            #expect(mode.format(11) == "10/10")
        }
    }

    @Test
    func minimumValues() {
        #expect(FeedbackScaleMode.likeDislike.minimumValue == 0)
        #expect(FeedbackScaleMode.oneToTen.minimumValue == 1)
        #expect(FeedbackScaleMode.oneToHundred.minimumValue == 1)
    }

    @Test
    func maximumValues() {
        #expect(FeedbackScaleMode.likeDislike.maximumValue == 1)
        #expect(FeedbackScaleMode.oneToTen.maximumValue == 10)
        #expect(FeedbackScaleMode.oneToHundred.maximumValue == 100)
        // Legacy modes map to canonicalMode, so fiveStar -> oneToTen -> max 10
        #expect(FeedbackScaleMode.fiveStar.maximumValue == 10)
        #expect(FeedbackScaleMode.tenPoint.maximumValue == 10)
    }

    @Test
    func clampWithinRange() {
        #expect(FeedbackScaleMode.oneToTen.clamp(5) == 5)
        #expect(FeedbackScaleMode.oneToTen.clamp(15) == 10)
        #expect(FeedbackScaleMode.oneToTen.clamp(0) == 1)
    }

    @Test
    func normalizedValueForLikeDislike() {
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(0) == 0)
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(0.4) == 0)
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(0.5) == 1)
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(1) == 1)
    }

    @Test
    func normalizedValueForOneToTen() {
        let mode = FeedbackScaleMode.oneToTen
        #expect(mode.normalizedValue(1) == 0)
        #expect(mode.normalizedValue(5.5) == 0.5)
        #expect(mode.normalizedValue(10) == 1)
    }

    @Test
    func normalizedValueForOneToHundredAndLegacyModes() {
        #expect(FeedbackScaleMode.oneToHundred.normalizedValue(1) == 0)
        #expect(FeedbackScaleMode.oneToHundred.normalizedValue(50.5) == 0.5)
        #expect(FeedbackScaleMode.oneToHundred.normalizedValue(100) == 1)
        #expect(FeedbackScaleMode.fiveStar.normalizedValue(10) == 1)
        #expect(FeedbackScaleMode.tenPoint.normalizedValue(1) == 0)
    }

    @Test
    func valueFromNormalizedReversesOneToTen() {
        let mode = FeedbackScaleMode.oneToTen
        #expect(mode.value(fromNormalized: 0) == 1)
        // round((0.5 * 9.0) + 1.0) = round(5.5) = 6
        #expect(mode.value(fromNormalized: 0.5) == 6)
        #expect(mode.value(fromNormalized: 1) == 10)
    }

    @Test
    func valueFromNormalizedClampsAndFormatsEveryScale() {
        #expect(FeedbackScaleMode.likeDislike.value(fromNormalized: 0.49) == 0)
        #expect(FeedbackScaleMode.likeDislike.value(fromNormalized: 0.5) == 1)
        #expect(FeedbackScaleMode.oneToHundred.value(fromNormalized: 0.5) == 51)
        #expect(FeedbackScaleMode.oneToHundred.value(fromNormalized: 2) == 100)
        #expect(FeedbackScaleMode.oneToTen.value(fromNormalized: -1) == 1)
        #expect(FeedbackScaleMode.fiveStar.value(fromNormalized: 0.5) == 6)
        #expect(FeedbackScaleMode.tenPoint.value(fromNormalized: 0.5) == 6)
    }

    @Test
    func sentimentForLikeDislike() {
        let mode = FeedbackScaleMode.likeDislike
        #expect(mode.sentiment(for: 1) == .liked)
        #expect(mode.sentiment(for: 0) == .disliked)
    }

    @Test
    func sentimentForOneToTen() {
        let mode = FeedbackScaleMode.oneToTen
        #expect(mode.sentiment(for: 10) == .liked)
        #expect(mode.sentiment(for: 1) == .disliked)
        #expect(mode.sentiment(for: 5) == .neutral)
    }

    @Test
    func formatLikeDislike() {
        #expect(FeedbackScaleMode.likeDislike.format(1) == "Liked")
        #expect(FeedbackScaleMode.likeDislike.format(0) == "Disliked")
    }

    @Test
    func formatOneToTen() {
        #expect(FeedbackScaleMode.oneToTen.format(8) == "8/10")
    }

    @Test
    func formatOneToHundred() {
        #expect(FeedbackScaleMode.oneToHundred.format(75) == "75/100")
    }

    @Test
    func formatClampsValuesBeforeRendering() {
        #expect(FeedbackScaleMode.likeDislike.format(0.49) == "Disliked")
        #expect(FeedbackScaleMode.likeDislike.format(0.5) == "Liked")
        #expect(FeedbackScaleMode.oneToTen.format(99) == "10/10")
        #expect(FeedbackScaleMode.oneToHundred.format(-10) == "1/100")
        #expect(FeedbackScaleMode.fiveStar.format(5) == "5/10")
        #expect(FeedbackScaleMode.tenPoint.format(11) == "10/10")
    }
}

// MARK: - FeedbackSentiment

@Suite("FeedbackSentiment")
struct UserTasteProfileFeedbackSentimentTests {

    @Test
    func rawValues() {
        #expect(FeedbackSentiment.liked.rawValue == "liked")
        #expect(FeedbackSentiment.disliked.rawValue == "disliked")
        #expect(FeedbackSentiment.neutral.rawValue == "neutral")
    }
}

@Suite("UserTasteProfile Database Round-Trip")
struct UserTasteProfileDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "user-taste-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = UserTasteProfile(
            id: "default",
            likedGenres: ["Sci-Fi", "Action"],
            dislikedGenres: ["Horror"],
            preferredDecades: ["2020s"],
            preferredLanguages: ["English"],
            eventCount: 10
        )
        try await database.saveUserTasteProfile(profile)
        let fetched = try await database.fetchUserTasteProfile(userId: "default")

        #expect(fetched != nil)
        #expect(fetched?.id == profile.id)
        #expect(fetched?.likedGenres == ["Sci-Fi", "Action"])
        #expect(fetched?.dislikedGenres == ["Horror"])
    }

    @Test
    func userTasteProfileWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = UserTasteProfile(
            id: "user-full",
            likedGenres: ["Drama", "Comedy"],
            dislikedGenres: ["Horror", "Thriller"],
            preferredDecades: ["1980s", "1990s"],
            preferredLanguages: ["English", "Japanese"],
            eventCount: 100
        )
        try await database.saveUserTasteProfile(profile)
        let fetched = try await database.fetchUserTasteProfile(userId: "user-full")

        #expect(fetched != nil)
        #expect(fetched?.likedGenres == ["Drama", "Comedy"])
        #expect(fetched?.dislikedGenres == ["Horror", "Thriller"])
        #expect(fetched?.preferredDecades == ["1980s", "1990s"])
        #expect(fetched?.eventCount == 100)
    }
}

@Suite("TasteEvent Database Round-Trip")
struct TasteEventDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "taste-event-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let event = TasteEvent(
            id: "event-1",
            userId: "default",
            mediaId: "media-123",
            eventType: .watched,
            signalStrength: 1.0
        )
        try await database.saveTasteEvent(event)
        let fetched = try await database.fetchTasteEvents(userId: "default")

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == event.id)
        #expect(fetched.first?.eventType == .watched)
        #expect(fetched.first?.mediaId == "media-123")
    }

    @Test
    func tasteEventWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let event = TasteEvent(
            id: "full-event",
            userId: "user-x",
            mediaId: "media-456",
            episodeId: "episode-789",
            eventType: .rated,
            signalStrength: 0.8,
            watchedState: .completed,
            feedbackScale: .oneToTen,
            feedbackValue: 8.0,
            source: .manual,
            metadata: ["key": "value"]
        )
        try await database.saveTasteEvent(event)
        let fetched = try await database.fetchTasteEvents(userId: "user-x")

        #expect(fetched.count == 1)
        #expect(fetched.first?.episodeId == "episode-789")
        #expect(fetched.first?.watchedState == .completed)
        #expect(fetched.first?.feedbackValue == 8.0)
    }

    @Test func multipleTasteEventsRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let events = [
            TasteEvent(id: "e1", userId: "u1", eventType: .watched),
            TasteEvent(id: "e2", userId: "u1", eventType: .rated),
            TasteEvent(id: "e3", userId: "u1", eventType: .added)
        ]

        for event in events {
            try await database.saveTasteEvent(event)
        }

        let fetched = try await database.fetchTasteEvents(userId: "u1")
        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.id == "e1" })
        #expect(fetched.contains { $0.id == "e2" })
        #expect(fetched.contains { $0.id == "e3" })
    }

    @Test func tasteEventFilterByEventTypeWorks() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let events = [
            TasteEvent(id: "w1", userId: "u2", eventType: .watched),
            TasteEvent(id: "r1", userId: "u2", eventType: .rated),
            TasteEvent(id: "r2", userId: "u2", eventType: .rated)
        ]

        for event in events {
            try await database.saveTasteEvent(event)
        }

        let fetched = try await database.fetchTasteEvents(userId: "u2", eventType: .rated)
        #expect(fetched.count == 2)
        #expect(fetched.allSatisfy { $0.eventType == .rated })
    }
}
