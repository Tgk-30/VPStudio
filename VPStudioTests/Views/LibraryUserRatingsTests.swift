import Testing
import Foundation
@testable import VPStudio

/// Tests the user-rating lookup logic used by Library, Discover, and Search to
/// pass `userRating` into `MediaCardView`.
@Suite("Library User Ratings Lookup")
struct LibraryUserRatingsLookupTests {

    // MARK: - Dictionary keying

    @Test func ratingsKeyedByMediaId() {
        let events = [
            TasteEvent(mediaId: "media-001", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 8),
            TasteEvent(mediaId: "media-002", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 3),
        ]
        let dict = TasteRatingLookupPolicy.lookup(from: events)
        #expect(dict.count == 2)
        #expect(dict["media-001"]?.feedbackValue == 8)
        #expect(dict["media-002"]?.feedbackValue == 3)
    }

    @Test func nilMediaIdEventsAreSkipped() {
        let event = TasteEvent(mediaId: nil, eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 7)
        let dict = TasteRatingLookupPolicy.lookup(from: [event])
        #expect(dict.isEmpty)
    }

    @Test func latestEventWinsRegardlessOfFetchOrder() {
        let early = TasteEvent(
            id: "e1", mediaId: "tt001", eventType: .rated,
            feedbackScale: .oneToTen, feedbackValue: 5,
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let late = TasteEvent(
            id: "e2", mediaId: "tt001", eventType: .rated,
            feedbackScale: .oneToTen, feedbackValue: 9,
            createdAt: Date(timeIntervalSince1970: 2000)
        )
        let chronological = TasteRatingLookupPolicy.lookup(from: [early, late])
        let newestFirst = TasteRatingLookupPolicy.lookup(from: [late, early])
        #expect(chronological["tt001"]?.feedbackValue == 9, "Latest rating should win")
        #expect(newestFirst["tt001"]?.feedbackValue == 9, "Latest rating should win")
    }

    @Test func imdbCompositeRatingsAreAvailableByBareIMDbID() {
        let event = TasteEvent(
            mediaId: "movie-imdb-tt1160419",
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 8
        )
        let dict = TasteRatingLookupPolicy.lookup(from: [event])
        #expect(dict["movie-imdb-tt1160419"]?.feedbackValue == 8)
        #expect(dict["tt1160419"]?.feedbackValue == 8)
        #expect(dict["series-imdb-tt1160419"]?.feedbackValue == 8)
        #expect(dict["movie-omdb-tt1160419"]?.feedbackValue == 8)
        #expect(dict["series-omdb-tt1160419"]?.feedbackValue == 8)
    }

    @Test func bareIMDbRatingsAreAvailableByCompositeIDs() {
        let event = TasteEvent(
            mediaId: "tt1160419",
            eventType: .rated,
            feedbackScale: .oneToHundred,
            feedbackValue: 82
        )
        let dict = TasteRatingLookupPolicy.lookup(from: [event])
        #expect(dict["tt1160419"]?.feedbackValue == 82)
        #expect(dict["movie-imdb-tt1160419"]?.feedbackValue == 82)
        #expect(dict["series-imdb-tt1160419"]?.feedbackValue == 82)
        #expect(dict["movie-omdb-tt1160419"]?.feedbackValue == 82)
        #expect(dict["series-omdb-tt1160419"]?.feedbackValue == 82)
    }

    @Test func omdbCompositeRatingsAreAvailableByIMDbAliases() {
        let event = TasteEvent(
            mediaId: "movie-omdb-tt1160419",
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 7
        )
        let dict = TasteRatingLookupPolicy.lookup(from: [event])
        #expect(dict["movie-omdb-tt1160419"]?.feedbackValue == 7)
        #expect(dict["tt1160419"]?.feedbackValue == 7)
        #expect(dict["movie-imdb-tt1160419"]?.feedbackValue == 7)
        #expect(dict["series-omdb-tt1160419"]?.feedbackValue == 7)
    }

    @Test func tmdbCompositeRatingsAreAvailableByTMDBAliases() {
        let event = TasteEvent(
            mediaId: "movie-tmdb-438631",
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 6
        )
        let dict = TasteRatingLookupPolicy.lookup(from: [event])
        #expect(dict["movie-tmdb-438631"]?.feedbackValue == 6)
        #expect(dict["tmdb-438631"]?.feedbackValue == 6)
        #expect(dict["series-tmdb-438631"]?.feedbackValue == 6)
    }

    @Test func ratingLookupUsesResolvedOMDbIDForLegacyTMDBLibraryRows() {
        let event = TasteEvent(
            mediaId: "movie-omdb-tt1160419",
            eventType: .rated,
            feedbackScale: .oneToTen,
            feedbackValue: 9
        )
        let dict = TasteRatingLookupPolicy.lookup(from: [event])

        let rating = TasteRatingLookupPolicy.rating(
            in: dict,
            mediaId: "movie-tmdb-438631",
            type: .movie,
            tmdbId: 438631,
            resolvedMediaId: "movie-omdb-tt1160419"
        )

        #expect(rating?.feedbackValue == 9)
    }

    @Test func ratingLookupUsesTMDBAliasWhenRatingWasStoredBeforeOMDbResolution() {
        let event = TasteEvent(
            mediaId: "tmdb-438631",
            eventType: .rated,
            feedbackScale: .oneToHundred,
            feedbackValue: 88
        )
        let dict = TasteRatingLookupPolicy.lookup(from: [event])

        let rating = TasteRatingLookupPolicy.rating(
            in: dict,
            mediaId: "movie-omdb-tt1160419",
            type: .movie,
            tmdbId: 438631,
            resolvedMediaId: "movie-omdb-tt1160419"
        )

        #expect(rating?.feedbackValue == 88)
    }

    @Test func lookupReturnsNilForUnratedMedia() {
        let dict = TasteRatingLookupPolicy.lookup(from: [
            TasteEvent(mediaId: "tt001", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 7),
        ])
        #expect(dict["tt999"] == nil)
    }

    @Test func onlyRatedEventsAreRelevant() {
        // Non-rated events (watched, browsed) should not appear in the ratings dict
        // The DB query filters by eventType: .rated, but verify the keying logic handles mixed input
        let events = [
            TasteEvent(mediaId: "media-001", eventType: .watched),
            TasteEvent(mediaId: "media-002", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 8),
            TasteEvent(mediaId: "media-003", eventType: .browsed),
        ]
        let dict = TasteRatingLookupPolicy.lookup(from: events)
        #expect(dict.count == 1)
        #expect(dict["media-002"]?.feedbackValue == 8)
    }

    // MARK: - Scale display consistency

    @Test func differentScalesPreservedInLookup() {
        let events = [
            TasteEvent(mediaId: "tt001", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 8),
            TasteEvent(mediaId: "tt002", eventType: .rated, feedbackScale: .likeDislike, feedbackValue: 1),
            TasteEvent(mediaId: "tt003", eventType: .rated, feedbackScale: .oneToHundred, feedbackValue: 75),
        ]
        let dict = TasteRatingLookupPolicy.lookup(from: events)
        #expect(dict["tt001"]?.feedbackScale == .oneToTen)
        #expect(dict["tt002"]?.feedbackScale == .likeDislike)
        #expect(dict["tt003"]?.feedbackScale == .oneToHundred)
    }

    @Test func emptyEventsListProducesEmptyDict() {
        let events: [TasteEvent] = []
        let dict = TasteRatingLookupPolicy.lookup(from: events)
        #expect(dict.isEmpty)
    }
}
