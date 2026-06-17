import Testing
@testable import VPStudio

@Suite("Detail Initial Action Policy")
struct DetailInitialActionPolicyTests {
    @Test func resumePlaybackDefersUntilMediaLoads() {
        #expect(DetailInitialActionPolicy.shouldDeferUntilMediaLoads(
            action: .resumePlayback,
            hasMediaItem: false
        ))
        #expect(!DetailInitialActionPolicy.shouldAttemptResumePlayback(
            action: .resumePlayback,
            hasMediaItem: false
        ))
    }

    @Test func resumePlaybackCanRunAfterMediaLoads() {
        #expect(!DetailInitialActionPolicy.shouldDeferUntilMediaLoads(
            action: .resumePlayback,
            hasMediaItem: true
        ))
        #expect(DetailInitialActionPolicy.shouldAttemptResumePlayback(
            action: .resumePlayback,
            hasMediaItem: true
        ))
    }

    @Test func noneNeverAttemptsResumePlayback() {
        #expect(!DetailInitialActionPolicy.shouldDeferUntilMediaLoads(
            action: .none,
            hasMediaItem: false
        ))
        #expect(!DetailInitialActionPolicy.shouldAttemptResumePlayback(
            action: .none,
            hasMediaItem: true
        ))
    }

    @Test func resumePlaybackOutcomeDefersUntilMediaLoads() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .resumePlayback,
            hasMediaItem: false,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .deferUntilMediaLoads)
    }

    @Test func resumePlaybackOutcomeIgnoresNonResumeActions() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .none,
            hasMediaItem: true,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .ignore)
    }

    @Test func resumePlaybackOutcomeRequiresSelectedEpisodeForSeries() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .resumePlayback,
            hasMediaItem: true,
            previewType: .series,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .missingEpisode)

        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .resumePlayback,
            hasMediaItem: true,
            previewType: .series,
            hasSelectedEpisode: true,
            hasActivePlayerSession: false
        ) == .searchAndPlay)
    }

    @Test func resumePlaybackOutcomeSurfacesActiveSessionBeforeSearching() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .resumePlayback,
            hasMediaItem: true,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: true
        ) == .activeSession)
    }

    @Test func resumePlaybackOutcomeSurfacesActiveSessionBeforeMissingSeriesEpisode() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .resumePlayback,
            hasMediaItem: true,
            previewType: .series,
            hasSelectedEpisode: false,
            hasActivePlayerSession: true
        ) == .activeSession)
    }

    @Test func resumePlaybackOutcomeSearchesAndPlaysWhenReady() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .resumePlayback,
            hasMediaItem: true,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .searchAndPlay)
    }

    @Test func handlingMapsEachOutcomeToExpectedBehaviorContract() {
        #expect(
            DetailInitialActionHandlingPolicy.handling(for: .deferUntilMediaLoads)
                == .deferUntilMediaLoads
        )
        #expect(
            DetailInitialActionHandlingPolicy.handling(for: .ignore)
                == .ignore
        )
        #expect(
            DetailInitialActionHandlingPolicy.handling(for: .missingEpisode)
                == .showMissingEpisodeError
        )
        #expect(
            DetailInitialActionHandlingPolicy.handling(for: .activeSession)
                == .showActiveSessionToast
        )
        #expect(
            DetailInitialActionHandlingPolicy.handling(for: .searchAndPlay)
                == .beginPlayback
        )
        #expect(
            DetailInitialActionHandlingPolicy.handling(for: .searchAndPlayBestCached)
                == .beginBestCachedPlayback
        )
    }

    // MARK: - playBestCached (one-tap play)

    @Test func playBestCachedIsTreatedAsPlayOnOpen() {
        #expect(DetailInitialActionPolicy.isPlayOnOpen(.playBestCached))
        #expect(DetailInitialActionPolicy.isPlayOnOpen(.resumePlayback))
        #expect(!DetailInitialActionPolicy.isPlayOnOpen(.none))
    }

    @Test func playBestCachedDefersUntilMediaLoads() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .playBestCached,
            hasMediaItem: false,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .deferUntilMediaLoads)
    }

    @Test func playBestCachedSurfacesActiveSessionBeforeSearching() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .playBestCached,
            hasMediaItem: true,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: true
        ) == .activeSession)
    }

    @Test func playBestCachedRequiresSelectedEpisodeForSeries() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .playBestCached,
            hasMediaItem: true,
            previewType: .series,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .missingEpisode)
    }

    @Test func playBestCachedSearchesAndPlaysBestCachedWhenReady() {
        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .playBestCached,
            hasMediaItem: true,
            previewType: .movie,
            hasSelectedEpisode: false,
            hasActivePlayerSession: false
        ) == .searchAndPlayBestCached)

        #expect(DetailInitialActionPolicy.resumePlaybackOutcome(
            action: .playBestCached,
            hasMediaItem: true,
            previewType: .series,
            hasSelectedEpisode: true,
            hasActivePlayerSession: false
        ) == .searchAndPlayBestCached)
    }
}
