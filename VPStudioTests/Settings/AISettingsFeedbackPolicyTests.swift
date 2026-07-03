import Testing
@testable import VPStudio

@Suite("AI Settings Feedback Policy")
struct AISettingsFeedbackPolicyTests {
    @Test
    func metadataTitleWinsOverDatabaseAndMediaIDFallbacks() {
        let event = TasteEvent(
            mediaId: "tt0133093",
            eventType: .rated,
            metadata: ["title": "  Metadata Title  "]
        )

        #expect(
            AISettingsFeedbackPolicy.resolvedFeedbackTitle(
                for: event,
                titleByMediaID: ["tt0133093": "Database Title"]
            ) == "Metadata Title"
        )
    }

    @Test
    func databaseTitleWinsWhenMetadataTitleIsBlank() {
        let event = TasteEvent(
            mediaId: "tt0133093",
            eventType: .rated,
            metadata: ["title": "   "]
        )

        #expect(
            AISettingsFeedbackPolicy.resolvedFeedbackTitle(
                for: event,
                titleByMediaID: ["tt0133093": "Database Title"]
            ) == "Database Title"
        )
    }

    @Test
    func databaseTitleIsTrimmedAndBlankValuesFallBackToMediaID() {
        let event = TasteEvent(
            mediaId: "tt0133093",
            eventType: .rated,
            metadata: ["title": "   "]
        )

        #expect(
            AISettingsFeedbackPolicy.resolvedFeedbackTitle(
                for: event,
                titleByMediaID: ["tt0133093": "  Database Title  "]
            ) == "Database Title"
        )

        #expect(
            AISettingsFeedbackPolicy.resolvedFeedbackTitle(
                for: event,
                titleByMediaID: ["tt0133093": "   "]
            ) == "tt0133093"
        )
    }

    @Test
    func mediaIDAndUnknownTitleAreLastResortFallbacks() {
        #expect(
            AISettingsFeedbackPolicy.resolvedFeedbackTitle(
                for: TasteEvent(mediaId: "tt0133093", eventType: .rated),
                titleByMediaID: [:]
            ) == "tt0133093"
        )

        #expect(
            AISettingsFeedbackPolicy.resolvedFeedbackTitle(
                for: TasteEvent(eventType: .rated),
                titleByMediaID: [:]
            ) == "Unknown title"
        )
    }

    @Test
    func feedbackSummaryGroupsSentimentDedupesTitlesAndKeepsRecentRatings() {
        let events = [
            TasteEvent(
                mediaId: "tt001",
                eventType: .rated,
                feedbackScale: .oneToTen,
                feedbackValue: 8,
                metadata: ["title": "Arrival"]
            ),
            TasteEvent(
                mediaId: "tt001",
                eventType: .rated,
                feedbackScale: .oneToTen,
                feedbackValue: 9,
                metadata: ["title": " arrival "]
            ),
            TasteEvent(
                mediaId: "tt002",
                eventType: .rated,
                feedbackScale: .oneToTen,
                feedbackValue: 2
            ),
            TasteEvent(
                mediaId: "tt003",
                eventType: .rated,
                feedbackScale: .oneToTen,
                feedbackValue: 5,
                metadata: ["title": "Middle"]
            ),
            TasteEvent(
                mediaId: "tt004",
                eventType: .rated,
                feedbackScale: nil,
                feedbackValue: 1,
                metadata: ["title": "Fallback Like"]
            ),
            TasteEvent(
                mediaId: "tt005",
                eventType: .rated,
                feedbackScale: .likeDislike,
                feedbackValue: nil,
                metadata: ["title": "Skipped"]
            ),
        ]

        let summary = AISettingsFeedbackPolicy.feedbackSummary(
            events: events,
            titleByMediaID: ["tt002": "Blade Runner"],
            fallbackScaleMode: .likeDislike
        )

        #expect(summary.likedTitles == ["Arrival", "Fallback Like"])
        #expect(summary.dislikedTitles == ["Blade Runner"])
        #expect(summary.recentRatings == [
            "Arrival (8/10)",
            "arrival (9/10)",
            "Blade Runner (2/10)",
            "Middle (5/10)",
            "Fallback Like (Liked)",
        ])
    }

    @Test
    func feedbackSummaryCapsRecentRatingsAndDedupesIdenticalLines() {
        var events = [
            TasteEvent(
                mediaId: "tt000",
                eventType: .rated,
                feedbackScale: .oneToHundred,
                feedbackValue: 90,
                metadata: ["title": "Title 0"]
            ),
            TasteEvent(
                mediaId: "tt000",
                eventType: .rated,
                feedbackScale: .oneToHundred,
                feedbackValue: 90,
                metadata: ["title": "title 0"]
            ),
        ]
        events.append(contentsOf: (1...25).map { index in
            TasteEvent(
                mediaId: "tt\(index)",
                eventType: .rated,
                feedbackScale: .oneToHundred,
                feedbackValue: 90,
                metadata: ["title": "Title \(index)"]
            )
        })

        let summary = AISettingsFeedbackPolicy.feedbackSummary(
            events: events,
            titleByMediaID: [:],
            fallbackScaleMode: .oneToHundred
        )

        #expect(summary.recentRatings.count == 20)
        #expect(summary.recentRatings.first == "Title 0 (90/100)")
        #expect(summary.recentRatings.last == "Title 19 (90/100)")
        #expect(summary.recentRatings.filter { $0.lowercased() == "title 0 (90/100)" }.count == 1)
        #expect(Array(summary.likedTitles.prefix(3)) == ["Title 0", "Title 1", "Title 2"])
    }
}
