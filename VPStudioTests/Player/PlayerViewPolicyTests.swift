import Foundation
import Testing
@testable import VPStudio

// MARK: - Transport Controls Placement

@Suite("Player Transport Controls Policy")
struct PlayerViewTransportControlsPolicyTests {

    @Test
    func showsRightTransportEnvironmentControlWhenPlacedRight() {
        #expect(
            PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl(
                placement: .rightTransportControls
            ) == true
        )
    }

    @Test
    func showsRightTransportEnvironmentControlWhenPlacedLeft() {
        #expect(
            PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl(
                placement: .leftNavigation
            ) == false
        )
    }

    @Test
    func defaultPlacementIsLeftNavigation() {
        #expect(PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl() == false)
    }
}

// MARK: - Playback State Titles

@Suite("Player View Policy — Playback State Title")
struct PlaybackStateTitleTests {

    @Test
    func preparingStateTitle() {
        #expect(PlayerViewPolicy.playbackStateTitle(for: .preparing) == "Preparing Playback")
    }

    @Test
    func bufferingStateTitle() {
        #expect(PlayerViewPolicy.playbackStateTitle(for: .buffering) == "Buffering")
    }

    @Test
    func playingStateTitle() {
        #expect(PlayerViewPolicy.playbackStateTitle(for: .playing) == "Playing")
    }

    @Test
    func failedStateTitle() {
        #expect(PlayerViewPolicy.playbackStateTitle(for: .failed) == "Playback Failed")
    }
}

// MARK: - Audio Track Refresh Deduplication

@Suite("Player View Policy — Audio Track Refresh")
struct AudioTrackRefreshPolicyTests {

    @Test
    func refreshRunsWhenStreamIDsMatch() {
        #expect(
            PlayerViewPolicy.audioTrackRefreshShouldRun(
                requestedStreamID: "abc",
                currentStreamID: "abc"
            ) == true
        )
    }

    @Test
    func refreshSkipsWhenStreamIDsDiffer() {
        #expect(
            PlayerViewPolicy.audioTrackRefreshShouldRun(
                requestedStreamID: "abc",
                currentStreamID: "def"
            ) == false
        )
    }

    @Test
    func refreshSkipsWhenCurrentStreamIDIsNil() {
        #expect(
            PlayerViewPolicy.audioTrackRefreshShouldRun(
                requestedStreamID: "abc",
                currentStreamID: nil
            ) == false
        )
    }
}

// MARK: - Playback Preparation Guard

@Suite("Player View Policy — Playback Preparation")
struct PreparePlaybackPolicyTests {

    @Test
    func preparationRunsWhenIDsMatch() {
        let id = UUID()
        #expect(
            PlayerViewPolicy.preparePlaybackShouldRun(
                requestedPreparationID: id,
                activePreparationID: id
            ) == true
        )
    }

    @Test
    func preparationSkipsWhenIDsDiffer() {
        #expect(
            PlayerViewPolicy.preparePlaybackShouldRun(
                requestedPreparationID: UUID(),
                activePreparationID: UUID()
            ) == false
        )
    }

    @Test
    func preparationSkipsWhenActiveIDIsNil() {
        #expect(
            PlayerViewPolicy.preparePlaybackShouldRun(
                requestedPreparationID: UUID(),
                activePreparationID: nil
            ) == false
        )
    }
}

// MARK: - Scrobble Progress

@Suite("Player View Policy — Scrobble Progress")
struct PlayerScrobbleProgressPolicyTests {

    @Test
    func returnsZeroWhenDurationIsNonPositiveOrNonFinite() {
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 10, duration: 0) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 10, duration: -5) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 10, duration: .nan) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: .infinity, duration: 100) == 0)
    }

    @Test
    func scalesCurrentTimeToPercent() {
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 25, duration: 100) == 25)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 90, duration: 120) == 75)
    }

    @Test
    func clampsProgressToClosedPercentageRange() {
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: -10, duration: 100) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 150, duration: 100) == 100)
    }
}

// MARK: - Subtitle Refresh and Appearance

@Suite("Player View Policy — Subtitle Refresh")
struct PlayerSubtitleRefreshPolicyTests {

    @Test
    func subtitleTextRefreshesWhenSubtitleTrackIsActive() {
        #expect(
            PlayerViewPolicy.subtitleTextRefreshShouldRun(
                selectedSubtitleTrack: 0,
                currentSubtitleText: nil
            )
        )
    }

    @Test
    func subtitleTextRefreshesWhenSubtitleTextIsVisible() {
        #expect(
            PlayerViewPolicy.subtitleTextRefreshShouldRun(
                selectedSubtitleTrack: -1,
                currentSubtitleText: "Visible"
            )
        )
    }

    @Test
    func subtitleTextDoesNotRefreshWhenNoSubtitleSignalPresent() {
        #expect(
            PlayerViewPolicy.subtitleTextRefreshShouldRun(
                selectedSubtitleTrack: -1,
                currentSubtitleText: nil
            ) == false
        )
    }
}

@Suite("Player View Policy — Buffered Percent")
struct PlayerBufferedPercentPolicyTests {

    @Test
    func bufferedPercentReturnsNilForInvalidDurationOrRanges() {
        #expect(PlayerViewPolicy.bufferedPercent(loadedRangeStart: 0, loadedRangeDuration: 5, itemDuration: 0) == nil)
        #expect(PlayerViewPolicy.bufferedPercent(loadedRangeStart: 0, loadedRangeDuration: 5, itemDuration: .nan) == nil)
        #expect(PlayerViewPolicy.bufferedPercent(loadedRangeStart: .infinity, loadedRangeDuration: 5, itemDuration: 10) == nil)
        #expect(PlayerViewPolicy.bufferedPercent(loadedRangeStart: 0, loadedRangeDuration: .nan, itemDuration: 10) == nil)
    }

    @Test
    func bufferedPercentReturnsNilWhenBufferedEndOverflows() {
        #expect(
            PlayerViewPolicy.bufferedPercent(
                loadedRangeStart: .greatestFiniteMagnitude,
                loadedRangeDuration: .greatestFiniteMagnitude,
                itemDuration: 100
            ) == nil
        )
    }

    @Test
    func bufferedPercentReturnsExactFractionForNormalInput() {
        #expect(
            PlayerViewPolicy.bufferedPercent(
                loadedRangeStart: 10,
                loadedRangeDuration: 20,
                itemDuration: 100
            ) == 0.3
        )
    }

    @Test
    func bufferedPercentClampsToClosedUnitRange() {
        #expect(
            PlayerViewPolicy.bufferedPercent(
                loadedRangeStart: 95,
                loadedRangeDuration: 20,
                itemDuration: 100
            ) == 1
        )
        #expect(
            PlayerViewPolicy.bufferedPercent(
                loadedRangeStart: -20,
                loadedRangeDuration: 5,
                itemDuration: 100
            ) == 0
        )
    }
}

@Suite("Player View Policy — Subtitle Font Size")
struct PlayerSubtitleFontSizePolicyTests {

    @Test
    func resolvesDefaultSubtitleFontSizeWhenMissingOrNonFinite() {
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: nil) == 24)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: .nan) == 24)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: .infinity) == 24)
    }

    @Test
    func clampsSubtitleFontSizeToSupportedRange() {
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: 12) == 16)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: 72) == 48)
    }

    @Test
    func preservesSubtitleFontSizeInRange() {
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: 32) == 32)
    }
}

@Suite("Player Track Presentation Policy")
struct PlayerTrackPresentationPolicyTests {
    @Test
    func audioTrackCountUsesLargestDetectedSource() {
        #expect(PlayerTrackPresentationPolicy.availableAudioTrackCount(avMediaOptionCount: 0, engineTrackCount: 0) == 0)
        #expect(PlayerTrackPresentationPolicy.availableAudioTrackCount(avMediaOptionCount: 3, engineTrackCount: 1) == 3)
        #expect(PlayerTrackPresentationPolicy.availableAudioTrackCount(avMediaOptionCount: 1, engineTrackCount: 4) == 4)
    }

    @Test
    func subtitlePresentationAndOffStateMirrorEngineEnablement() {
        #expect(PlayerTrackPresentationPolicy.isSubtitlePresentationActive(subtitlesEnabled: true))
        #expect(!PlayerTrackPresentationPolicy.isSubtitlePresentationActive(subtitlesEnabled: false))
        #expect(!PlayerTrackPresentationPolicy.isSubtitleSelectionOff(subtitlesEnabled: true))
        #expect(PlayerTrackPresentationPolicy.isSubtitleSelectionOff(subtitlesEnabled: false))
    }

    @Test
    func trackListRefreshRequiresAnActivePlaybackBackend() {
        #expect(!PlayerTrackPresentationPolicy.canRefreshTrackList(hasAVPlayer: false, hasKSPlayerCoordinator: false))
        #expect(PlayerTrackPresentationPolicy.canRefreshTrackList(hasAVPlayer: true, hasKSPlayerCoordinator: false))
        #expect(PlayerTrackPresentationPolicy.canRefreshTrackList(hasAVPlayer: false, hasKSPlayerCoordinator: true))
        #expect(PlayerTrackPresentationPolicy.canRefreshTrackList(hasAVPlayer: true, hasKSPlayerCoordinator: true))
    }

    @Test
    func directAndEngineTrackSelectionsAreStrictMatches() {
        #expect(PlayerTrackPresentationPolicy.isDirectTrackSelected(selectedID: "en-0", trackID: "en-0"))
        #expect(!PlayerTrackPresentationPolicy.isDirectTrackSelected(selectedID: "en-0", trackID: "fr-1"))
        #expect(!PlayerTrackPresentationPolicy.isDirectTrackSelected(selectedID: nil, trackID: "fr-1"))

        #expect(PlayerTrackPresentationPolicy.isEngineTrackSelected(selectedTrackID: 2, trackID: 2))
        #expect(!PlayerTrackPresentationPolicy.isEngineTrackSelected(selectedTrackID: 1, trackID: 2))
    }

    @Test
    func externalSubtitleSelectionRequiresNoActiveAVSubtitleAndMatchingEngineTrack() {
        #expect(PlayerTrackPresentationPolicy.isExternalSubtitleSelected(
            selectedAVSubtitleID: nil,
            selectedEngineSubtitleTrack: 3,
            trackID: 3
        ))
        #expect(!PlayerTrackPresentationPolicy.isExternalSubtitleSelected(
            selectedAVSubtitleID: "direct-en",
            selectedEngineSubtitleTrack: 3,
            trackID: 3
        ))
        #expect(!PlayerTrackPresentationPolicy.isExternalSubtitleSelected(
            selectedAVSubtitleID: nil,
            selectedEngineSubtitleTrack: 2,
            trackID: 3
        ))
    }
}

@Suite("Player Subtitle Selection Policy")
struct PlayerSubtitleSelectionPolicyTests {
    @Test
    func resolvedKSSubtitlePrefersExplicitSubtitleModelSelectionWhenValid() {
        #expect(
            PlayerSubtitleSelectionPolicy.resolvedKSSubtitleID(
                selectedSubtitleInfoID: "sub-fr",
                enabledTrackID: "sub-en",
                optionIDs: ["sub-en", "sub-fr"]
            ) == "sub-fr"
        )
    }

    @Test
    func resolvedKSSubtitleFallsBackToEnabledTrackWhenExplicitSelectionIsMissingOrStale() {
        #expect(
            PlayerSubtitleSelectionPolicy.resolvedKSSubtitleID(
                selectedSubtitleInfoID: nil,
                enabledTrackID: "sub-en",
                optionIDs: ["sub-en", "sub-fr"]
            ) == "sub-en"
        )
        #expect(
            PlayerSubtitleSelectionPolicy.resolvedKSSubtitleID(
                selectedSubtitleInfoID: "stale",
                enabledTrackID: "sub-fr",
                optionIDs: ["sub-en", "sub-fr"]
            ) == "sub-fr"
        )
    }

    @Test
    func resolvedKSSubtitleReturnsNilWhenNoCurrentSelectionMapsToAnOption() {
        #expect(
            PlayerSubtitleSelectionPolicy.resolvedKSSubtitleID(
                selectedSubtitleInfoID: "missing",
                enabledTrackID: "stale",
                optionIDs: ["sub-en", "sub-fr"]
            ) == nil
        )
        #expect(
            PlayerSubtitleSelectionPolicy.resolvedKSSubtitleID(
                selectedSubtitleInfoID: nil,
                enabledTrackID: nil,
                optionIDs: ["sub-en", "sub-fr"]
            ) == nil
        )
    }
}

@Suite("Player Subtitle Service Policy")
struct PlayerSubtitleServicePolicyTests {
    @Test
    func normalizedAPIKeyTrimsWhitespaceAndRejectsEmptyValues() {
        #expect(PlayerSubtitleServicePolicy.normalizedAPIKey("  key-123  ") == "key-123")
        #expect(PlayerSubtitleServicePolicy.normalizedAPIKey("   ") == nil)
        #expect(PlayerSubtitleServicePolicy.normalizedAPIKey(nil) == nil)
    }

    @Test
    func imdbSearchIDOnlyUsesIMDbStyleMediaIdentifiers() {
        #expect(PlayerSubtitleServicePolicy.imdbSearchID(from: "tt0133093") == "tt0133093")
        #expect(PlayerSubtitleServicePolicy.imdbSearchID(from: "12345") == nil)
        #expect(PlayerSubtitleServicePolicy.imdbSearchID(from: nil) == nil)
    }

    @Test
    func supportedCatalogCandidatesRequireFileIDAndRenderableFormatAndApplyLimit() {
        let supported = subtitle(id: "supported", fileName: "Movie.en.srt", format: .srt, fileId: 101)
        let missingFileID = subtitle(id: "missing-file", fileName: "Movie.es.srt", format: .srt, fileId: nil)
        let unsupported = subtitle(id: "unsupported", fileName: "Movie.fr.txt", format: .unknown, fileId: 303)
        let overflow = (0..<35).map {
            subtitle(id: "overflow-\($0)", fileName: "Movie.\($0).vtt", format: .vtt, fileId: 500 + $0)
        }

        let candidates = PlayerSubtitleServicePolicy.supportedCatalogCandidates(
            [supported, missingFileID, unsupported] + overflow,
            limit: 30
        )

        #expect(candidates.count == 30)
        #expect(candidates.first == supported)
        #expect(!candidates.contains(missingFileID))
        #expect(!candidates.contains(unsupported))
    }

    @Test
    func catalogMessagesAreActionableForMissingInputsAndEmptyResults() {
        #expect(PlayerSubtitleServicePolicy.missingCatalogAPIKeyMessage == "Set an OpenSubtitles API key in Settings to browse subtitle options.")
        #expect(PlayerSubtitleServicePolicy.emptyCatalogQueryMessage == "Could not build subtitle query for this stream.")
        #expect(PlayerSubtitleServicePolicy.missingDownloadAPIKeyMessage == "OpenSubtitles API key is required.")
        #expect(PlayerSubtitleServicePolicy.unsupportedSubtitleMessage == "That subtitle format is not supported for rendering.")
        #expect(PlayerSubtitleServicePolicy.catalogResultMessage(candidateCount: 0) == "No subtitle matches found.")
        #expect(PlayerSubtitleServicePolicy.catalogResultMessage(candidateCount: 2) == nil)
    }

    @Test
    func automaticDownloadFailureMessageIncludesUnderlyingReason() {
        #expect(
            PlayerSubtitleServicePolicy.automaticDownloadFailureMessage(errorDescription: "rate limited")
                == "Automatic subtitle download failed. Open subtitles to retry. rate limited"
        )
    }

    private func subtitle(
        id: String,
        fileName: String,
        format: SubtitleFormat,
        fileId: Int?
    ) -> Subtitle {
        Subtitle(
            id: id,
            language: "en",
            fileName: fileName,
            url: "https://example.com/\(fileName)",
            format: format,
            fileId: fileId,
            rating: nil,
            downloadCount: nil,
            isHearingImpaired: nil,
            source: "OpenSubtitles"
        )
    }
}

@Suite("Player Media Option ID Policy")
struct PlayerMediaOptionIDPolicyTests {
    @Test
    func idPrefersLocaleIdentifierThenExtendedTagThenUndeterminedLanguage() {
        #expect(
            PlayerMediaOptionIDPolicy.id(
                localeIdentifier: "en_US",
                extendedLanguageTag: "fr-CA",
                displayName: "English",
                index: 0
            ) == "en_US-English-0"
        )
        #expect(
            PlayerMediaOptionIDPolicy.id(
                localeIdentifier: nil,
                extendedLanguageTag: "fr-CA",
                displayName: "French",
                index: 1
            ) == "fr-CA-French-1"
        )
        #expect(
            PlayerMediaOptionIDPolicy.id(
                localeIdentifier: nil,
                extendedLanguageTag: nil,
                displayName: "Commentary",
                index: 2
            ) == "und-Commentary-2"
        )
    }

    @Test
    func idKeepsDuplicateDisplayNamesDistinctByIndex() {
        let first = PlayerMediaOptionIDPolicy.id(
            localeIdentifier: "en",
            extendedLanguageTag: nil,
            displayName: "Stereo",
            index: 0
        )
        let second = PlayerMediaOptionIDPolicy.id(
            localeIdentifier: "en",
            extendedLanguageTag: nil,
            displayName: "Stereo",
            index: 1
        )

        #expect(first == "en-Stereo-0")
        #expect(second == "en-Stereo-1")
        #expect(first != second)
    }
}

@Suite("Player AV Media Selection Policy")
struct PlayerAVMediaSelectionPolicyTests {
    @Test
    func selectionPlanPreservesCurrentSelectionWithoutAutoSelecting() {
        let plan = PlayerAVMediaSelectionPolicy.selectionPlan(
            currentSelectedIndex: 1,
            candidates: [
                candidate(id: "en-English-0", localeIdentifier: "en_US"),
                candidate(id: "fr-French-1", localeIdentifier: "fr_FR"),
            ],
            preferredLanguages: ["en"],
            allowsPreferredAutoSelection: true
        )

        #expect(plan.selectedID == "fr-French-1")
        #expect(plan.autoSelectIndex == nil)
    }

    @Test
    func selectionPlanAutoSelectsFirstPreferredLanguageWhenAllowed() {
        let plan = PlayerAVMediaSelectionPolicy.selectionPlan(
            currentSelectedIndex: nil,
            candidates: [
                candidate(id: "fr-French-0", localeIdentifier: "fr_FR"),
                candidate(id: "en-English-1", localeIdentifier: "en_US"),
                candidate(id: "en-Commentary-2", localeIdentifier: "en_GB"),
            ],
            preferredLanguages: ["en"],
            allowsPreferredAutoSelection: true
        )

        #expect(plan.selectedID == "en-English-1")
        #expect(plan.autoSelectIndex == 1)
    }

    @Test
    func selectionPlanDoesNotAutoSelectWhenManualModeDisallowsPreferredSelection() {
        let plan = PlayerAVMediaSelectionPolicy.selectionPlan(
            currentSelectedIndex: nil,
            candidates: [
                candidate(id: "en-English-0", localeIdentifier: "en_US"),
            ],
            preferredLanguages: ["en"],
            allowsPreferredAutoSelection: false
        )

        #expect(plan == .none)
    }

    @Test
    func selectionPlanTreatsStaleCurrentIndexAsUnselected() {
        let plan = PlayerAVMediaSelectionPolicy.selectionPlan(
            currentSelectedIndex: 5,
            candidates: [
                candidate(id: "es-Spanish-0", extendedLanguageTag: "es-MX"),
            ],
            preferredLanguages: ["es"],
            allowsPreferredAutoSelection: true
        )

        #expect(plan.selectedID == "es-Spanish-0")
        #expect(plan.autoSelectIndex == 0)
    }

    @Test
    func selectionPlanReturnsNoneWhenNoCandidateMatchesPreferredLanguages() {
        let plan = PlayerAVMediaSelectionPolicy.selectionPlan(
            currentSelectedIndex: nil,
            candidates: [
                candidate(id: "fr-French-0", localeIdentifier: "fr_FR"),
            ],
            preferredLanguages: ["en"],
            allowsPreferredAutoSelection: true
        )

        #expect(plan == .none)
    }

    private func candidate(
        id: String,
        localeIdentifier: String? = nil,
        extendedLanguageTag: String? = nil
    ) -> PlayerAVMediaSelectionPolicy.Candidate {
        PlayerAVMediaSelectionPolicy.Candidate(
            id: id,
            localeIdentifier: localeIdentifier,
            extendedLanguageTag: extendedLanguageTag
        )
    }
}

// MARK: - Seek Clamping (currentTime + offset)

@Suite("Player View Policy — Clamped Seek Target (Offset)")
struct ClampedSeekTargetOffsetTests {

    @Test
    func offsetSeekWithinBounds() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            currentTime: 100,
            offset: 10,
            duration: 200
        )
        #expect(result == 110)
    }

    @Test
    func offsetSeekClampsToZero() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            currentTime: 5,
            offset: -10,
            duration: 200
        )
        #expect(result == 0)
    }

    @Test
    func offsetSeekClampsToDuration() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            currentTime: 195,
            offset: 10,
            duration: 200
        )
        #expect(result == 200)
    }

    @Test
    func offsetSeekAtStartWithPositiveOffset() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            currentTime: 0,
            offset: 30,
            duration: 100
        )
        #expect(result == 30)
    }

    @Test
    func offsetSeekAtEndWithNegativeOffset() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            currentTime: 100,
            offset: -30,
            duration: 100
        )
        #expect(result == 70)
    }
}

// MARK: - Seek Clamping (percent)

@Suite("Player View Policy — Clamped Seek Target (Percent)")
struct ClampedSeekTargetPercentTests {

    @Test
    func percentSeekAtZero() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            percent: 0,
            duration: 200
        )
        #expect(result == 0)
    }

    @Test
    func percentSeekAtOne() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            percent: 1,
            duration: 200
        )
        #expect(result == 200)
    }

    @Test
    func percentSeekAtMidpoint() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            percent: 0.5,
            duration: 200
        )
        #expect(result == 100)
    }

    @Test
    func percentSeekClampsBelowZero() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            percent: -0.5,
            duration: 200
        )
        #expect(result == 0)
    }

    @Test
    func percentSeekClampsAboveOne() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            percent: 1.5,
            duration: 200
        )
        #expect(result == 200)
    }
}

// MARK: - Seek Clamping (absolute time)

@Suite("Player View Policy — Clamped Seek Target (Time)")
struct ClampedSeekTargetTimeTests {

    @Test
    func timeSeekWithinBounds() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            time: 150,
            duration: 200
        )
        #expect(result == 150)
    }

    @Test
    func timeSeekClampsToZero() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            time: -10,
            duration: 200
        )
        #expect(result == 0)
    }

    @Test
    func timeSeekClampsToDuration() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            time: 250,
            duration: 200
        )
        #expect(result == 200)
    }

    @Test
    func timeSeekAtExactlyZero() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            time: 0,
            duration: 200
        )
        #expect(result == 0)
    }

    @Test
    func timeSeekAtExactlyDuration() {
        let result = PlayerViewPolicy.clampedSeekTarget(
            time: 200,
            duration: 200
        )
        #expect(result == 200)
    }
}

// MARK: - Scrubber Accessibility Value

@Suite("Player View Policy — Scrubber Accessibility Value")
struct ScrubberAccessibilityValueTests {

    @Test
    func nonScrubbingShowsCurrentTimeOfDuration() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 65,
            duration: 200,
            isScrubbing: false,
            scrubTime: 30
        )
        #expect(value == "1:05 of 3:20")
    }

    @Test
    func scrubbingShowsScrubTimeOfDuration() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 65,
            duration: 200,
            isScrubbing: true,
            scrubTime: 30
        )
        #expect(value == "0:30 of 3:20")
    }

    @Test
    func zeroDurationReturnsOnlyCurrentTime() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 45,
            duration: 0,
            isScrubbing: false,
            scrubTime: 30
        )
        #expect(value == "0:45")
    }

    @Test
    func negativeDurationReturnsOnlyCurrentTime() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 45,
            duration: -1,
            isScrubbing: false,
            scrubTime: 30
        )
        #expect(value == "0:45")
    }

    @Test
    func hoursFormatIsPreserved() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 3665,
            duration: 7200,
            isScrubbing: false,
            scrubTime: 0
        )
        #expect(value == "1:01:05 of 2:00:00")
    }

    @Test
    func scrubbingAtZeroDurationFallsBackToScrubTime() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 10,
            duration: 0,
            isScrubbing: true,
            scrubTime: 25
        )
        #expect(value == "0:25")
    }

    @Test
    func scrubbingWithNonFiniteTimesFallsBackToCurrentWhenScrubbing() {
        let value = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 10,
            duration: 200,
            isScrubbing: true,
            scrubTime: .nan
        )
        #expect(value == "0:10 of 3:20")
    }
}

// MARK: - Periodic Observer Interval

@Suite("Player View Policy — Constants")
struct PlayerViewPolicyConstantsTests {

    @Test
    func periodicObserverIntervalIsQuarterSecond() {
        #expect(PlayerViewPolicy.avPlayerPeriodicObserverIntervalSeconds == 0.25)
    }
}

// MARK: - Auto-Play Next Countdown

@Suite("Player Auto-Play Next Policy")
struct PlayerAutoplayNextPolicyTests {

    @Test
    func countdownStartsWhenNextEpisodeIsInsideTriggerWindow() {
        #expect(PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 590,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
    }

    @Test
    func countdownDoesNotStartBeforeTriggerWindow() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 589,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
    }

    @Test
    func countdownStartsAtExactTriggerBoundary() {
        #expect(PlayerAutoplayNextPolicy.countdownTriggerRemainingTime == 10)
        #expect(PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 590,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
    }

    @Test
    func countdownDoesNotStartWithoutNextEpisode() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 590,
            duration: 600,
            hasNextEpisode: false,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
    }

    @Test
    func countdownDoesNotRestartAfterPromptWasCancelled() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 590,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: true,
            isResolving: false
        ))
    }

    @Test
    func countdownDoesNotStartWithInvalidDuration() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 0,
            duration: 0,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
    }

    @Test
    func countdownRejectsNonFiniteTimingInputs() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: .nan,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 590,
            duration: .infinity,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))
    }

    @Test
    func countdownProgressIsClamped() {
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: 10) == 1)
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: 5) == 0.5)
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: -1) == 0)
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: 30) == 1)
    }

    @Test
    func countdownSchedulingRequiresNextEpisodeAndFreshPromptState() {
        #expect(PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: promptState()))
        #expect(!PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: promptState(hasNextEpisode: false)))
        #expect(!PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: promptState(didRequest: true)))
        #expect(!PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: promptState(didCancel: true)))
    }

    @Test
    func schedulingCountdownMarksPromptAsRequestedWithoutShowingItYet() {
        let state = PlayerAutoplayNextPolicy.stateAfterSchedulingCountdown(from: promptState())

        #expect(state.didRequestAutoplayNext)
        #expect(!state.didCancelAutoPlayNextPrompt)
        #expect(!state.isShowingAutoPlayNextPrompt)
        #expect(state.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
    }

    @Test
    func schedulingCountdownIsNoopWhenPromptWasAlreadyHandled() {
        let cancelled = promptState(didRequest: true, didCancel: true, showing: true, countdown: 4)

        #expect(PlayerAutoplayNextPolicy.stateAfterSchedulingCountdown(from: cancelled) == cancelled)
    }

    @Test
    func presentingAndUnavailableCountdownStatesUpdateOnlyThePromptSurface() {
        let presented = PlayerAutoplayNextPolicy.stateAfterPresentingCountdown(
            from: promptState(didRequest: true, countdown: 3)
        )

        #expect(presented.isShowingAutoPlayNextPrompt)
        #expect(presented.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)

        let unavailable = PlayerAutoplayNextPolicy.stateAfterCountdownUnavailable(from: presented)
        #expect(!unavailable.isShowingAutoPlayNextPrompt)
        #expect(unavailable.didRequestAutoplayNext)
        #expect(!unavailable.isResolvingAutoPlayNextEpisode)
        #expect(unavailable.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
    }

    @Test
    func unavailableCountdownWithoutQueuedEpisodeRearmsWhenEpisodeAppearsLater() {
        let unavailable = PlayerAutoplayNextPolicy.stateAfterCountdownUnavailable(
            from: promptState(hasNextEpisode: false, didRequest: true, showing: true, resolving: true, countdown: 3)
        )

        #expect(!unavailable.didRequestAutoplayNext)
        #expect(!unavailable.didCancelAutoPlayNextPrompt)
        #expect(!unavailable.isShowingAutoPlayNextPrompt)
        #expect(!unavailable.isResolvingAutoPlayNextEpisode)
        #expect(unavailable.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
        #expect(!PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: unavailable))

        var laterWithEpisode = unavailable
        laterWithEpisode.hasNextEpisode = true
        #expect(PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: laterWithEpisode))
    }

    @Test
    func playNowRequiresNextEpisodeAndNonResolvingState() {
        let playable = PlayerAutoplayNextPolicy.stateAfterPlayNow(from: promptState(showing: true, countdown: 7))
        #expect(playable.didRequestAutoplayNext)
        #expect(playable.countdownRemaining == 0)
        #expect(playable.isShowingAutoPlayNextPrompt)

        let missingEpisode = promptState(hasNextEpisode: false, countdown: 7)
        #expect(PlayerAutoplayNextPolicy.stateAfterPlayNow(from: missingEpisode) == missingEpisode)

        let resolving = promptState(resolving: true, countdown: 7)
        #expect(PlayerAutoplayNextPolicy.stateAfterPlayNow(from: resolving) == resolving)
    }

    @Test
    func cancellingCountdownSuppressesFuturePromptsUntilStreamTransition() {
        let cancelled = PlayerAutoplayNextPolicy.stateAfterCancellingCountdown(
            from: promptState(showing: true, countdown: 2)
        )

        #expect(cancelled.didCancelAutoPlayNextPrompt)
        #expect(cancelled.didRequestAutoplayNext)
        #expect(!cancelled.isShowingAutoPlayNextPrompt)
        #expect(cancelled.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
        #expect(!PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: cancelled))
    }

    @Test
    func startingResolutionRequiresQueuedEpisodeAndNonResolvingState() {
        let resolving = PlayerAutoplayNextPolicy.stateAfterStartingResolution(from: promptState(showing: false))
        #expect(resolving.isResolvingAutoPlayNextEpisode)
        #expect(resolving.isShowingAutoPlayNextPrompt)

        let missingEpisode = promptState(hasNextEpisode: false)
        #expect(PlayerAutoplayNextPolicy.stateAfterStartingResolution(from: missingEpisode) == missingEpisode)

        let alreadyResolving = promptState(resolving: true)
        #expect(PlayerAutoplayNextPolicy.stateAfterStartingResolution(from: alreadyResolving) == alreadyResolving)
    }

    @Test
    func finishingResolutionSuccessClearsPromptAndQueuedEpisodeState() {
        let resolved = PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
            from: promptState(didRequest: true, didCancel: true, showing: true, resolving: true, countdown: 0),
            outcome: .succeeded
        )

        #expect(!resolved.hasNextEpisode)
        #expect(!resolved.didRequestAutoplayNext)
        #expect(!resolved.didCancelAutoPlayNextPrompt)
        #expect(!resolved.isShowingAutoPlayNextPrompt)
        #expect(!resolved.isResolvingAutoPlayNextEpisode)
        #expect(resolved.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
    }

    @Test
    func finishingResolutionFailureKeepsEpisodeAvailableButHidesPrompt() {
        let failed = PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
            from: promptState(didRequest: true, showing: true, resolving: true, countdown: 0),
            outcome: .failed
        )

        #expect(failed.hasNextEpisode)
        #expect(failed.didRequestAutoplayNext)
        #expect(!failed.isShowingAutoPlayNextPrompt)
        #expect(!failed.isResolvingAutoPlayNextEpisode)
        #expect(failed.countdownRemaining == 0)
    }

    @Test
    func streamTransitionResetsPromptStateForTheNewEpisodeQueue() {
        #expect(
            PlayerAutoplayNextPolicy.stateAfterStreamTransition(hasNextEpisode: true) ==
            PlayerAutoplayNextPolicy.PromptState.idle(hasNextEpisode: true)
        )
        #expect(
            PlayerAutoplayNextPolicy.stateAfterStreamTransition(hasNextEpisode: false) ==
            PlayerAutoplayNextPolicy.PromptState.idle(hasNextEpisode: false)
        )
    }

    @Test
    func resolutionPlanSkipsWhenAutoplayIsDisabledOrEpisodeIsMissing() throws {
        let context = try #require(recoveryContext())

        #expect(
            PlayerAutoplayNextResolutionPolicy.resolutionPlan(
                autoPlayNextEnabled: false,
                nextEpisode: nextEpisode(),
                currentRecoveryContext: context
            ) == .disabled
        )

        #expect(
            PlayerAutoplayNextResolutionPolicy.resolutionPlan(
                autoPlayNextEnabled: true,
                nextEpisode: nil,
                currentRecoveryContext: context
            ) == .unavailable
        )
    }

    @Test
    func resolutionPlanFallsBackToSeriesPageWhenCurrentStreamCannotBeRecovered() {
        #expect(
            PlayerAutoplayNextResolutionPolicy.resolutionPlan(
                autoPlayNextEnabled: true,
                nextEpisode: nextEpisode(),
                currentRecoveryContext: nil
            ) == .readyFromSeriesPage(
                message: PlayerAutoplayNextResolutionPolicy.readyFromSeriesPageMessage
            )
        )
    }

    @Test
    func resolutionPlanFallsBackWhenDecodedRecoveryContextHasInvalidInfoHash() throws {
        let data = #"{"infoHash":""}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StreamRecoveryContext.self, from: data)

        #expect(
            PlayerAutoplayNextResolutionPolicy.resolutionPlan(
                autoPlayNextEnabled: true,
                nextEpisode: nextEpisode(),
                currentRecoveryContext: decoded
            ) == .readyFromSeriesPage(
                message: PlayerAutoplayNextResolutionPolicy.readyFromSeriesPageMessage
            )
        )
    }

    @Test
    func resolutionPlanBuildsNextEpisodeRecoveryContext() throws {
        let context = try #require(recoveryContext())
        let plan = PlayerAutoplayNextResolutionPolicy.resolutionPlan(
            autoPlayNextEnabled: true,
            nextEpisode: nextEpisode(season: 3, episode: 8),
            currentRecoveryContext: context
        )

        guard case .resolve(let nextContext) = plan else {
            Issue.record("Expected a re-resolution context")
            return
        }

        #expect(nextContext.infoHash == "abcdef123456")
        #expect(nextContext.preferredService == .realDebrid)
        #expect(nextContext.seasonNumber == 3)
        #expect(nextContext.episodeNumber == 8)
        #expect(nextContext.torrentId == nil)
        #expect(nextContext.resolvedFileName == nil)
    }

    private func promptState(
        hasNextEpisode: Bool = true,
        didRequest: Bool = false,
        didCancel: Bool = false,
        showing: Bool = false,
        resolving: Bool = false,
        countdown: Int = PlayerAutoplayNextPolicy.countdownDurationSeconds
    ) -> PlayerAutoplayNextPolicy.PromptState {
        PlayerAutoplayNextPolicy.PromptState(
            hasNextEpisode: hasNextEpisode,
            didRequestAutoplayNext: didRequest,
            didCancelAutoPlayNextPrompt: didCancel,
            isShowingAutoPlayNextPrompt: showing,
            isResolvingAutoPlayNextEpisode: resolving,
            countdownRemaining: countdown
        )
    }

    private func nextEpisode(
        season: Int = 2,
        episode: Int = 5
    ) -> PlayerSessionRequest.NextEpisodeCandidate {
        PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "s\(season)e\(episode)",
            seasonNumber: season,
            episodeNumber: episode,
            title: "Episode \(episode)"
        )
    }

    private func recoveryContext() -> StreamRecoveryContext? {
        StreamRecoveryContext(
            infoHash: "ABCDEF123456",
            preferredService: .realDebrid,
            seasonNumber: 2,
            episodeNumber: 4,
            torrentId: "torrent-1",
            resolvedDebridService: "realdebrid",
            resolvedFileName: "Show.S02E04.mkv",
            resolvedFileSizeBytes: 1024
        )
    }
}

@Suite("Player Stream Refresh Policy")
struct PlayerStreamRefreshPolicyTests {
    @Test
    func queueWithRefreshedPrimaryReplacesStalePrimaryAndPreservesFallbackOrder() {
        let stale = stream("stale", url: "https://cdn.example.com/stale.mkv")
        let refreshed = stream("stale-refreshed", url: "https://cdn.example.com/stale-refreshed.mkv")
        let fallbackA = stream("fallback-a", url: "https://cdn.example.com/fallback-a.mkv")
        let fallbackB = stream("fallback-b", url: "https://cdn.example.com/fallback-b.mkv")

        let queue = PlayerStreamRefreshPolicy.queueWithRefreshedPrimary(
            refreshedStream: refreshed,
            staleStream: stale,
            streamQueue: [stale, fallbackA, fallbackB]
        )

        #expect(queue.map(\.id) == [refreshed.id, fallbackA.id, fallbackB.id])
    }

    @Test
    func queueWithRefreshedPrimaryDeduplicatesRefreshedStreamFromFallbackPool() {
        let stale = stream("stale", url: "https://cdn.example.com/stale.mkv")
        let refreshed = stream("stale-refreshed", url: "https://cdn.example.com/stale-refreshed.mkv")
        let fallbackA = stream("fallback-a", url: "https://cdn.example.com/fallback-a.mkv")
        let fallbackB = stream("fallback-b", url: "https://cdn.example.com/fallback-b.mkv")

        let queue = PlayerStreamRefreshPolicy.queueWithRefreshedPrimary(
            refreshedStream: refreshed,
            staleStream: stale,
            streamQueue: [stale, fallbackA, refreshed, fallbackB, refreshed]
        )

        #expect(queue.map(\.id) == [refreshed.id, fallbackA.id, fallbackB.id])
    }

    @Test
    func queueWithRefreshedPrimaryStillRoutesPrimaryFirstWhenStaleStreamMissing() {
        let stale = stream("stale", url: "https://cdn.example.com/stale.mkv")
        let refreshed = stream("stale-refreshed", url: "https://cdn.example.com/stale-refreshed.mkv")
        let fallbackA = stream("fallback-a", url: "https://cdn.example.com/fallback-a.mkv")
        let fallbackB = stream("fallback-b", url: "https://cdn.example.com/fallback-b.mkv")

        let queue = PlayerStreamRefreshPolicy.queueWithRefreshedPrimary(
            refreshedStream: refreshed,
            staleStream: stale,
            streamQueue: [fallbackA, fallbackB]
        )

        #expect(queue.map(\.id) == [refreshed.id, fallbackA.id, fallbackB.id])
    }

    private func stream(_ name: String, url: String) -> StreamInfo {
        Fixtures.stream(url: url, fileName: "\(name).mkv")
    }
}

@Suite("Player View Policy — Progress Bar Presentation")
struct PlayerProgressBarPresentationPolicyTests {
    @Test
    func displayTimeUsesScrubTimeOnlyWhileScrubbing() {
        #expect(
            PlayerViewPolicy.progressBarDisplayTime(
                currentTime: 42,
                isScrubbing: false,
                scrubTime: 8
            ) == 42
        )
        #expect(
            PlayerViewPolicy.progressBarDisplayTime(
                currentTime: 42,
                isScrubbing: true,
                scrubTime: 8
            ) == 8
        )
    }

    @Test
    func displayPercentClampsToUnitRangeAndHandlesNonPositiveDuration() {
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: 25, duration: 100) == 0.25)
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: -20, duration: 100) == 0)
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: 250, duration: 100) == 1)
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: 5, duration: 0) == 1)
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: 0.25, duration: 0.5) == 0.5)
    }

    @Test
    func bufferedPercentAndDragPercentAreClamped() {
        #expect(PlayerViewPolicy.progressBarBufferedPercent(-0.5) == 0)
        #expect(PlayerViewPolicy.progressBarBufferedPercent(0.4) == 0.4)
        #expect(PlayerViewPolicy.progressBarBufferedPercent(2.0) == 1)

        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: -10, barWidth: 100) == 0)
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: 40, barWidth: 100) == 0.4)
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: 120, barWidth: 100) == 1)
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: 20, barWidth: .nan) == 0)
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: 0.5, barWidth: 1) == 0.5)
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: 0.5, barWidth: 0) == 0)
    }

    @Test
    func scrubPreviewLabelPositionAndChapterMarkerFollowBoundaries() {
        #expect(PlayerViewPolicy.scrubPreviewLabelX(progressX: 5, barWidth: 200) == 30)
        #expect(PlayerViewPolicy.scrubPreviewLabelX(progressX: 180, barWidth: 200) == 170)
        #expect(PlayerViewPolicy.scrubPreviewLabelX(progressX: 80, barWidth: 200) == 80)
        #expect(PlayerViewPolicy.scrubPreviewLabelX(progressX: 2, barWidth: 20) == 10)
        #expect(PlayerViewPolicy.scrubPreviewLabelX(progressX: .nan, barWidth: 200) == 0)
        #expect(PlayerViewPolicy.scrubPreviewLabelX(progressX: 100, barWidth: 0) == 0)

        #expect(!PlayerViewPolicy.shouldShowChapterMarker(chapterStartTime: 0))
        #expect(PlayerViewPolicy.shouldShowChapterMarker(chapterStartTime: 0.1))
    }

    @Test
    func progressBarHeightReflectsScrubMode() {
        #expect(
            PlayerViewPolicy.progressBarHeight(isScrubbing: true) ==
            PlayerCinematicChromePolicy.progressBarScrubbingHeight
        )
        #expect(
            PlayerViewPolicy.progressBarHeight(isScrubbing: false) ==
            PlayerCinematicChromePolicy.progressBarIdleHeight
        )
    }
}

@Suite("Player View Policy — Overlay and Picker Decisions")
struct PlayerOverlayAndPickerPolicyTests {
    @Test
    func warningsOverlayVisibilityRequiresWarningsOrFailedPlaybackError() {
        #expect(
            !PlayerViewPolicy.shouldShowWarningsOverlay(
                capabilityWarnings: [],
                playbackError: nil,
                playbackState: .playing
            )
        )
        #expect(
            PlayerViewPolicy.shouldShowWarningsOverlay(
                capabilityWarnings: ["warning"],
                playbackError: nil,
                playbackState: .playing
            )
        )
        #expect(
            PlayerViewPolicy.shouldShowWarningsOverlay(
                capabilityWarnings: [],
                playbackError: "failed",
                playbackState: .failed
            )
        )
    }

    @Test
    func warningOverlayPlaybackErrorOnlySurfacesInFailedState() {
        #expect(
            PlayerViewPolicy.warningOverlayPlaybackError(
                playbackError: "network",
                playbackState: .failed
            ) == "network"
        )
        #expect(
            PlayerViewPolicy.warningOverlayPlaybackError(
                playbackError: nil,
                playbackState: .failed
            ) == nil
        )
        #expect(
            PlayerViewPolicy.warningOverlayPlaybackError(
                playbackError: "network",
                playbackState: .playing
            ) == nil
        )
    }

    @Test
    func emptyAudioTrackMessageMatchesEngineSelection() {
        #expect(
            PlayerViewPolicy.emptyAudioTracksMessage(activeEngine: .avPlayer) ==
            "No alternate in-stream audio tracks detected. The stream may have only one audio track."
        )
        #expect(
            PlayerViewPolicy.emptyAudioTracksMessage(activeEngine: .ksPlayer) ==
            "No alternate audio tracks detected for this stream."
        )
        #expect(
            PlayerViewPolicy.emptyAudioTracksMessage(activeEngine: nil) ==
            "No alternate audio tracks detected for this stream."
        )
    }

    @Test
    func subtitleLanguageLabelRequiresNonEmptyLanguage() {
        #expect(PlayerViewPolicy.subtitleTrackLanguageLabel(nil) == nil)
        #expect(PlayerViewPolicy.subtitleTrackLanguageLabel("") == nil)
        #expect(PlayerViewPolicy.subtitleTrackLanguageLabel("en") == "EN")
    }

    @Test
    func controlModalPresentationAggregatesAllModalFlags() {
        #expect(
            !PlayerViewPolicy.isControlModalPresented(
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            PlayerViewPolicy.isControlModalPresented(
                isShowingSubtitlePicker: true,
                isShowingAudioPicker: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            PlayerViewPolicy.isControlModalPresented(
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isShowingEnvironmentPicker: true,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            PlayerViewPolicy.isControlModalPresented(
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: true
            )
        )
    }
}
