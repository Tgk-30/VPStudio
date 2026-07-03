import Testing
import Foundation
@testable import VPStudio

@Suite("UserTasteProfile Codable Round-Trip")
struct UserTasteProfileCodableTests {
    @Test("UserTasteProfile encodes and decodes correctly")
    func userTasteProfileCodableRoundTrip() throws {
        let original = UserTasteProfile(
            id: "profile-123",
            likedGenres: ["Sci-Fi", "Action", "Drama"],
            dislikedGenres: ["Horror", "Romance"],
            preferredDecades: ["2020s", "1990s"],
            preferredLanguages: ["English", "Japanese", "Korean"],
            eventCount: 150,
            updatedAt: Date(timeIntervalSince1970: 123456789)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserTasteProfile.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.likedGenres == original.likedGenres)
        #expect(decoded.dislikedGenres == original.dislikedGenres)
        #expect(decoded.preferredDecades == original.preferredDecades)
        #expect(decoded.preferredLanguages == original.preferredLanguages)
        #expect(decoded.eventCount == original.eventCount)
        #expect(decoded.updatedAt == original.updatedAt)
    }

    @Test("UserTasteProfile with empty arrays encodes and decodes correctly")
    func userTasteProfileEmptyArraysCodableRoundTrip() throws {
        let original = UserTasteProfile(
            id: "empty-profile",
            likedGenres: [],
            dislikedGenres: [],
            preferredDecades: [],
            preferredLanguages: [],
            eventCount: 0
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserTasteProfile.self, from: encoded)

        #expect(decoded.likedGenres == [])
        #expect(decoded.dislikedGenres == [])
        #expect(decoded.preferredDecades == [])
        #expect(decoded.preferredLanguages == [])
    }

    @Test("UserTasteProfile default id is 'default'")
    func userTasteProfileDefaultId() throws {
        let profile = UserTasteProfile()
        #expect(profile.id == "default")
    }
}

@Suite("TasteEvent Codable Round-Trip")
struct TasteEventCodableTests {
    @Test("TasteEvent encodes and decodes correctly")
    func tasteEventCodableRoundTrip() throws {
        let original = TasteEvent(
            id: "event-123",
            userId: "user-456",
            mediaId: "media-789",
            episodeId: "episode-101",
            eventType: .rated,
            signalStrength: 0.85,
            watchedState: .completed,
            feedbackScale: .oneToTen,
            feedbackValue: 8.5,
            source: .manual,
            metadata: ["key1": "value1", "key2": "value2"],
            createdAt: Date(timeIntervalSince1970: 123456789)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TasteEvent.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.userId == original.userId)
        #expect(decoded.mediaId == original.mediaId)
        #expect(decoded.episodeId == original.episodeId)
        #expect(decoded.eventType == original.eventType)
        #expect(decoded.signalStrength == original.signalStrength)
        #expect(decoded.watchedState == original.watchedState)
        #expect(decoded.feedbackScale == original.feedbackScale)
        #expect(decoded.feedbackValue == original.feedbackValue)
        #expect(decoded.source == original.source)
        #expect(decoded.metadata == original.metadata)
        #expect(decoded.createdAt == original.createdAt)
    }

    @Test("TasteEvent with nil optionals encodes and decodes correctly")
    func tasteEventNilOptionalsCodableRoundTrip() throws {
        let original = TasteEvent(
            id: "minimal-event",
            userId: "user",
            mediaId: nil,
            episodeId: nil,
            eventType: .browsed,
            signalStrength: 1.0,
            watchedState: nil,
            feedbackScale: nil,
            feedbackValue: nil,
            source: nil,
            metadata: [:]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TasteEvent.self, from: encoded)

        #expect(decoded.mediaId == nil)
        #expect(decoded.episodeId == nil)
        #expect(decoded.watchedState == nil)
        #expect(decoded.feedbackScale == nil)
        #expect(decoded.feedbackValue == nil)
        #expect(decoded.source == nil)
        #expect(decoded.metadata == [:])
    }

    @Test("TasteEvent EventType all cases encode and decode correctly")
    func tasteEventEventTypeAllCasesCodableRoundTrip() throws {
        let eventTypes: [TasteEvent.EventType] = [.watched, .rated, .added, .removed, .searched, .browsed, .skipped]

        for eventType in eventTypes {
            let event = TasteEvent(id: "event-\(eventType.rawValue)", userId: "user", eventType: eventType)
            let encoded = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(TasteEvent.self, from: encoded)
            #expect(decoded.eventType == eventType)
        }
    }

    @Test("TasteEvent WatchedState all cases encode and decode correctly")
    func tasteEventWatchedStateAllCasesCodableRoundTrip() throws {
        let states: [TasteEvent.WatchedState] = [.watching, .completed, .dropped, .planToWatch]

        for state in states {
            let event = TasteEvent(id: "event", userId: "user", eventType: .watched, watchedState: state)
            let encoded = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(TasteEvent.self, from: encoded)
            #expect(decoded.watchedState == state)
        }
    }

    @Test("TasteEvent FeedbackSource all cases encode and decode correctly")
    func tasteEventFeedbackSourceAllCasesCodableRoundTrip() throws {
        let sources: [TasteEvent.FeedbackSource] = [.manual, .automatic, .ai]

        for source in sources {
            let event = TasteEvent(id: "event", userId: "user", eventType: .rated, source: source)
            let encoded = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(TasteEvent.self, from: encoded)
            #expect(decoded.source == source)
        }
    }
}

@Suite("FeedbackSentiment Codable Round-Trip")
struct FeedbackSentimentCodableTests {
    @Test("FeedbackSentiment all cases encode and decode correctly")
    func feedbackSentimentAllCasesCodableRoundTrip() throws {
        let sentiments: [FeedbackSentiment] = [.liked, .disliked, .neutral]

        for sentiment in sentiments {
            let encoded = try JSONEncoder().encode(sentiment)
            let decoded = try JSONDecoder().decode(FeedbackSentiment.self, from: encoded)
            #expect(decoded == sentiment)
        }
    }
}
