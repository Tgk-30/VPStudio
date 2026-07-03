import Foundation
import SwiftUI
import Testing
@testable import VPStudio

// MARK: - Accessibility and Internationalization Tests

@Suite("Accessibility and Internationalization Test Suite")
struct AccessibilityInternationalizationTests {

    // MARK: - TabBarAccessibilityPolicy Tests

    @Suite("TabBarAccessibilityPolicy Comprehensive Tests")
    struct TabBarAccessibilityPolicyComprehensiveTests {
        @Test("accessibilityLabel for all tabs with selected state includes Selected suffix")
        func accessibilityLabelSelectedAllTabs() {
            let tabs: [SidebarTab] = [.discover, .search, .library, .downloads, .environments, .settings]
            for tab in tabs {
                let label = TabBarAccessibilityPolicy.accessibilityLabel(for: tab, isSelected: true)
                #expect(label.hasSuffix("Selected"))
                #expect(label.contains(tab.rawValue))
            }
        }

        @Test("accessibilityLabel for all tabs without selected state returns raw value")
        func accessibilityLabelNotSelectedAllTabs() {
            let tabs: [SidebarTab] = [.discover, .search, .library, .downloads, .environments, .settings]
            for tab in tabs {
                let label = TabBarAccessibilityPolicy.accessibilityLabel(for: tab, isSelected: false)
                #expect(label == tab.rawValue)
            }
        }

        @Test("accessibilityHint for all tabs returns non-empty descriptive strings")
        func accessibilityHintAllTabsNonEmpty() {
            let tabs: [SidebarTab] = [.discover, .search, .library, .downloads, .environments, .settings]
            for tab in tabs {
                let hint = TabBarAccessibilityPolicy.accessibilityHint(for: tab)
                #expect(!hint.isEmpty)
                #expect(hint.count >= 10)
            }
        }

        @Test("accessibilityHint for discover mentions browsing content")
        func accessibilityHintDiscoverMentionsBrowsing() {
            let hint = TabBarAccessibilityPolicy.accessibilityHint(for: .discover)
            #expect(hint.contains("Browse") || hint.contains("content"))
        }

        @Test("accessibilityHint for search mentions movies and TV")
        func accessibilityHintSearchMentionsMoviesAndTV() {
            let hint = TabBarAccessibilityPolicy.accessibilityHint(for: .search)
            #expect(hint.contains("movies") || hint.contains("TV"))
        }

        @Test("accessibilityHint for library mentions saved media")
        func accessibilityHintLibraryMentionsSavedMedia() {
            let hint = TabBarAccessibilityPolicy.accessibilityHint(for: .library)
            #expect(hint.contains("library") || hint.contains("saved"))
        }

        @Test("accessibilityHint for downloads mentions active downloads")
        func accessibilityHintDownloadsMentionsActive() {
            let hint = TabBarAccessibilityPolicy.accessibilityHint(for: .downloads)
            #expect(hint.contains("download") || hint.contains("manage"))
        }

        @Test("accessibilityHint for environments mentions immersive")
        func accessibilityHintEnvironmentsMentionsImmersive() {
            let hint = TabBarAccessibilityPolicy.accessibilityHint(for: .environments)
            #expect(hint.contains("immersive") || hint.contains("environment"))
        }

        @Test("accessibilityHint for settings mentions preferences")
        func accessibilityHintSettingsMentionsPreferences() {
            let hint = TabBarAccessibilityPolicy.accessibilityHint(for: .settings)
            #expect(hint.contains("preferences") || hint.contains("accounts") || hint.contains("settings"))
        }
    }

    // MARK: - SettingsAccessibilityPolicy Tests

    @Suite("SettingsAccessibilityPolicy Comprehensive Tests")
    struct SettingsAccessibilityPolicyComprehensiveTests {
        @Test("rowLabel returns title when status is nil")
        func rowLabelWithNilStatus() {
            let result = SettingsAccessibilityPolicy.rowLabel(title: "API Key", status: nil)
            #expect(result == "API Key")
        }

        @Test("rowLabel returns title when status is empty")
        func rowLabelWithEmptyStatus() {
            let result = SettingsAccessibilityPolicy.rowLabel(title: "API Key", status: "")
            #expect(result == "API Key")
        }

        @Test("rowLabel combines title and status with comma")
        func rowLabelCombinesTitleAndStatus() {
            let result = SettingsAccessibilityPolicy.rowLabel(title: "Real-Debrid", status: "Connected")
            #expect(result == "Real-Debrid, Connected")
        }

        @Test("rowLabel handles various status values")
        func rowLabelHandlesVariousStatuses() {
            #expect(SettingsAccessibilityPolicy.rowLabel(title: "Service", status: "Active") == "Service, Active")
            #expect(SettingsAccessibilityPolicy.rowLabel(title: "Service", status: "Inactive") == "Service, Inactive")
            #expect(SettingsAccessibilityPolicy.rowLabel(title: "Service", status: "Error") == "Service, Error")
        }

        @Test("rowHint returns Needs attention when hasWarning is true")
        func rowHintWithWarning() {
            let result = SettingsAccessibilityPolicy.rowHint(hasWarning: true)
            #expect(result == "Needs attention")
        }

        @Test("rowHint returns default message when hasWarning is false")
        func rowHintWithoutWarning() {
            let result = SettingsAccessibilityPolicy.rowHint(hasWarning: false)
            #expect(result == "Opens details for this setting")
        }

        @Test("sectionLabel formats with configured count")
        func sectionLabelWithCounts() {
            let result = SettingsAccessibilityPolicy.sectionLabel(title: "Indexers", configuredCount: 3, totalCount: 5)
            #expect(result == "Indexers, 3 of 5 configured")
        }

        @Test("sectionLabel handles edge cases")
        func sectionLabelEdgeCases() {
            #expect(SettingsAccessibilityPolicy.sectionLabel(title: "Accounts", configuredCount: 0, totalCount: 0) == "Accounts, 0 of 0 configured")
            #expect(SettingsAccessibilityPolicy.sectionLabel(title: "Accounts", configuredCount: 5, totalCount: 5) == "Accounts, 5 of 5 configured")
        }
    }

    // MARK: - SeriesPrimaryPlayPolicy Accessibility Tests

    @Suite("SeriesPrimaryPlayPolicy Accessibility Tests")
    struct SeriesPrimaryPlayPolicyAccessibilityTests {
        @Test("accessibilityHint for movie returns stream search message")
        func accessibilityHintMovie() {
            let hint = SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .movie, hasSelectedEpisode: false)
            #expect(hint.contains("streams") || hint.contains("Searches"))
        }

        @Test("accessibilityHint for series without selection returns episode selection message")
        func accessibilityHintSeriesNoSelection() {
            let hint = SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: false)
            #expect(hint.contains("episode") || hint.contains("Choose"))
        }

        @Test("accessibilityHint for series with selection returns stream search message")
        func accessibilityHintSeriesWithSelection() {
            let hint = SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: true)
            #expect(hint.contains("streams") || hint.contains("Searches"))
        }

        @Test("accessibilityHint strings are non-empty")
        func accessibilityHintNonEmpty() {
            #expect(!SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .movie, hasSelectedEpisode: false).isEmpty)
            #expect(!SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: false).isEmpty)
            #expect(!SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: true).isEmpty)
        }
    }

    // MARK: - SeriesDetailPresentationPolicy Accessibility Tests

    @Suite("SeriesDetailPresentationPolicy Accessibility Tests")
    struct SeriesDetailPresentationPolicyAccessibilityTests {
        @Test("episodeAccessibilityLabel formats correctly with title")
        func episodeAccessibilityLabelWithTitle() {
            let label = SeriesDetailPresentationPolicy.episodeAccessibilityLabel(
                episodeNumber: 5,
                title: "The Pilot"
            )
            #expect(label == "Episode 5, The Pilot")
        }

        @Test("episodeAccessibilityLabel handles nil title")
        func episodeAccessibilityLabelWithNilTitle() {
            let label = SeriesDetailPresentationPolicy.episodeAccessibilityLabel(
                episodeNumber: 1,
                title: nil
            )
            #expect(label == "Episode 1, Untitled")
        }

        @Test("episodeAccessibilityLabel handles empty title")
        func episodeAccessibilityLabelWithEmptyTitle() {
            let label = SeriesDetailPresentationPolicy.episodeAccessibilityLabel(
                episodeNumber: 1,
                title: ""
            )
            // Empty string is not replaced with "Untitled" — only nil is
            #expect(label == "Episode 1, ")
        }

        @Test("episodeAccessibilityLabel handles various episode numbers")
        func episodeAccessibilityLabelVariousEpisodes() {
            #expect(SeriesDetailPresentationPolicy.episodeAccessibilityLabel(episodeNumber: 1, title: "Pilot") == "Episode 1, Pilot")
            #expect(SeriesDetailPresentationPolicy.episodeAccessibilityLabel(episodeNumber: 10, title: "Episode 10") == "Episode 10, Episode 10")
            #expect(SeriesDetailPresentationPolicy.episodeAccessibilityLabel(episodeNumber: 100, title: nil) == "Episode 100, Untitled")
        }

        @Test("episodeAccessibilityValue for watched and selected")
        func episodeAccessibilityValueWatchedSelected() {
            let value = SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: true, isSelected: true)
            #expect(value == "Watched, selected")
        }

        @Test("episodeAccessibilityValue for watched but not selected")
        func episodeAccessibilityValueWatchedNotSelected() {
            let value = SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: true, isSelected: false)
            #expect(value == "Watched")
        }

        @Test("episodeAccessibilityValue for not watched but selected")
        func episodeAccessibilityValueNotWatchedSelected() {
            let value = SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: false, isSelected: true)
            #expect(value == "Selected")
        }

        @Test("episodeAccessibilityValue for not watched and not selected")
        func episodeAccessibilityValueNotWatchedNotSelected() {
            let value = SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: false, isSelected: false)
            #expect(value == "Not watched")
        }

        @Test("episodeWatchLabel for watched state")
        func episodeWatchLabelWatched() {
            #expect(SeriesDetailPresentationPolicy.episodeWatchLabel(isWatched: true) == "Watched")
        }

        @Test("episodeWatchLabel for not watched state")
        func episodeWatchLabelNotWatched() {
            #expect(SeriesDetailPresentationPolicy.episodeWatchLabel(isWatched: false) == "Not watched")
        }

        @Test("episodeWatchActionTitle for unwatched returns mark as watched")
        func episodeWatchActionTitleUnwatched() {
            #expect(SeriesDetailPresentationPolicy.episodeWatchActionTitle(isWatched: false) == "Mark Episode as Watched")
        }

        @Test("episodeWatchActionTitle for watched returns mark as unwatched")
        func episodeWatchActionTitleWatched() {
            #expect(SeriesDetailPresentationPolicy.episodeWatchActionTitle(isWatched: true) == "Mark Episode as Unwatched")
        }
    }

    // MARK: - PlayerViewPolicy Accessibility Tests

    @Suite("PlayerViewPolicy Accessibility Tests")
    struct PlayerViewPolicyAccessibilityTests {
        @Test("scrubberAccessibilityValue formats with duration")
        func scrubberAccessibilityValueWithDuration() {
            let result = PlayerViewPolicy.scrubberAccessibilityValue(
                currentTime: 120,
                duration: 3600,
                isScrubbing: false,
                scrubTime: 0
            )
            #expect(result.contains("2:00"))
            #expect(result.contains("1:00:00"))
        }

        @Test("scrubberAccessibilityValue uses scrub time when scrubbing")
        func scrubberAccessibilityValueScrubbing() {
            let result = PlayerViewPolicy.scrubberAccessibilityValue(
                currentTime: 120,
                duration: 3600,
                isScrubbing: true,
                scrubTime: 240
            )
            #expect(result.contains("4:00"))
            #expect(!result.contains("2:00"))
        }

        @Test("scrubberAccessibilityValue handles zero duration")
        func scrubberAccessibilityValueZeroDuration() {
            let result = PlayerViewPolicy.scrubberAccessibilityValue(
                currentTime: 120,
                duration: 0,
                isScrubbing: false,
                scrubTime: 0
            )
            #expect(result.contains("2:00"))
            #expect(!result.contains("of"))
        }

        @Test("scrubberAccessibilityValue handles zero scrub time while scrubbing")
        func scrubberAccessibilityValueNilScrubTime() {
            let result = PlayerViewPolicy.scrubberAccessibilityValue(
                currentTime: 60,
                duration: 120,
                isScrubbing: true,
                scrubTime: 0
            )
            // When scrubbing, scrubTime (0) is used, not currentTime
            #expect(result == "0:00 of 2:00")
        }

        @Test("playbackStateTitle for all states")
        func playbackStateTitleAllStates() {
            #expect(PlayerViewPolicy.playbackStateTitle(for: .preparing) == "Preparing Playback")
            #expect(PlayerViewPolicy.playbackStateTitle(for: .buffering) == "Buffering")
            #expect(PlayerViewPolicy.playbackStateTitle(for: .playing) == "Playing")
            #expect(PlayerViewPolicy.playbackStateTitle(for: .failed) == "Playback Failed")
        }
    }

    // MARK: - ExploreGenreTilePolicy Accessibility Tests

    @Suite("ExploreGenreTilePolicy Accessibility Tests")
    struct ExploreGenreTilePolicyAccessibilityTests {
        @Test("accessibilityLabel combines title and subtitle")
        func accessibilityLabelCombinesTitleAndSubtitle() {
            let card = ExploreMoodCard(
                id: "action",
                title: "Action",
                subtitle: "Action movies and thrillers",
                symbol: "bolt.fill",
                color: .orange,
                movieGenreId: 28,
                tvGenreId: 10759
            )
            let label = ExploreGenreTilePolicy.accessibilityLabel(for: card)
            #expect(label.contains("Action"))
            #expect(label.contains("Action movies"))
        }

        @Test("accessibilityLabel for various cards")
        func accessibilityLabelVariousCards() {
            let cards = ExploreGenreCatalog.cards
            for card in cards {
                let label = ExploreGenreTilePolicy.accessibilityLabel(for: card)
                #expect(!label.isEmpty)
                #expect(label.contains(card.title))
            }
        }

        @Test("accessibilityLabel for different subtitle patterns")
        func accessibilityLabelDifferentSubtitles() {
            let card1 = ExploreMoodCard(id: "1", title: "Comedy", subtitle: " comedies", symbol: "face.smiling", color: .yellow, movieGenreId: 35, tvGenreId: 35)
            let card2 = ExploreMoodCard(id: "2", title: "Drama", subtitle: "Dramas and character stories", symbol: "theatermasks.fill", color: .blue, movieGenreId: 18, tvGenreId: 18)

            let label1 = ExploreGenreTilePolicy.accessibilityLabel(for: card1)
            let label2 = ExploreGenreTilePolicy.accessibilityLabel(for: card2)

            #expect(label1.contains("Comedy"))
            #expect(label2.contains("Drama"))
        }
    }

    // MARK: - ResetDataPolicy Accessibility Tests

    @Suite("ResetDataPolicy Accessibility Tests")
    struct ResetDataPolicyAccessibilityTests {
        @Test("progressAccessibilityLabel is non-empty")
        func progressAccessibilityLabelNonEmpty() {
            #expect(!ResetDataPolicy.progressAccessibilityLabel.isEmpty)
        }

        @Test("progressAccessibilityLabel is descriptive")
        func progressAccessibilityLabelDescriptive() {
            #expect(ResetDataPolicy.progressAccessibilityLabel.contains("Reset") || ResetDataPolicy.progressAccessibilityLabel.contains("progress"))
        }
    }

    // MARK: - Localization String Validation Tests

    @Suite("Localization String Validation Tests")
    struct LocalizationStringValidationTests {
        @Test("SeriesPrimaryPlayPolicy noStreamsMessage is localized")
        func noStreamsMessageLocalized() {
            let message = SeriesPrimaryPlayPolicy.noStreamsMessage
            #expect(!message.isEmpty)
            #expect(message.count >= 10)
        }

        @Test("SeriesPrimaryPlayPolicy selectEpisodeLabel is localized")
        func selectEpisodeLabelLocalized() {
            let label = SeriesPrimaryPlayPolicy.selectEpisodeLabel
            #expect(!label.isEmpty)
        }

        @Test("SeriesSeasonLoadingPresentationPolicy loadingTitle contains Season")
        func loadingTitleContainsSeason() {
            let title = SeriesSeasonLoadingPresentationPolicy.loadingTitle(for: 1)
            #expect(title.contains("Season"))
            #expect(title.contains("1"))
        }

        @Test("SeriesSeasonLoadingPresentationPolicy loadingMessage contains Season")
        func loadingMessageContainsSeason() {
            let message = SeriesSeasonLoadingPresentationPolicy.loadingMessage(for: 2)
            #expect(message.contains("Season"))
            #expect(message.contains("2"))
        }

        @Test("SeriesDetailPresentationPolicy seasonCountText singular")
        func seasonCountTextSingular() {
            #expect(SeriesDetailPresentationPolicy.seasonCountText(1) == "1 Season")
        }

        @Test("SeriesDetailPresentationPolicy seasonCountText plural")
        func seasonCountTextPlural() {
            #expect(SeriesDetailPresentationPolicy.seasonCountText(3) == "3 Seasons")
        }

        @Test("SeriesDetailPresentationPolicy episodeContextText format")
        func episodeContextTextFormat() {
            #expect(SeriesDetailPresentationPolicy.episodeContextText(season: 1, episodeNumber: 1) == "S1:E1")
            #expect(SeriesDetailPresentationPolicy.episodeContextText(season: 10, episodeNumber: 5) == "S10:E5")
        }

        @Test("SeriesDetailPresentationPolicy episodeRuntimeText format")
        func episodeRuntimeTextFormat() {
            #expect(SeriesDetailPresentationPolicy.episodeRuntimeText(minutes: 30) == "• 30m")
            #expect(SeriesDetailPresentationPolicy.episodeRuntimeText(minutes: 120) == "• 120m")
        }

        @Test("SeriesDetailPresentationPolicy watchStatusIcon names")
        func watchStatusIconNames() {
            #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .watched) == "checkmark.circle.fill")
            #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .inProgress) == "play.circle.fill")
            #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .notWatched) == "circle")
            #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .selectionRequired) == "rectangle.and.hand.point.up.left.fill")
        }

        @Test("SeriesDetailPresentationPolicy seriesWatchProgressLabel format")
        func seriesWatchProgressLabelFormat() {
            #expect(SeriesDetailPresentationPolicy.seriesWatchProgressLabel(watchedCount: 5, seasonEpisodeCounts: [10, 10, 10]) == "5/30 watched")
        }

        @Test("SeriesDetailPresentationPolicy seriesWatchProgressLabel edge case")
        func seriesWatchProgressLabelEdgeCase() {
            #expect(SeriesDetailPresentationPolicy.seriesWatchProgressLabel(watchedCount: 0, seasonEpisodeCounts: []) == "Series Actions")
        }
    }

    // MARK: - Accessibility Trait Tests

    @Suite("Accessibility Trait Validation Tests")
    struct AccessibilityTraitValidationTests {
        @Test("PlayerControlPresentation has accessibilityValue")
        func playerControlPresentationHasAccessibilityValue() {
            let playing = PlayerControlPresentationMapper.playPause(for: .playing)
            let paused = PlayerControlPresentationMapper.playPause(for: .paused)
            let buffering = PlayerControlPresentationMapper.playPause(for: .buffering)

            #expect(!playing.accessibilityValue.isEmpty)
            #expect(!paused.accessibilityValue.isEmpty)
            #expect(!buffering.accessibilityValue.isEmpty)
        }

        @Test("PlayerControlPresentation accessibilityValues are distinct")
        func playerControlPresentationAccessibilityValuesDistinct() {
            let playing = PlayerControlPresentationMapper.playPause(for: .playing)
            let paused = PlayerControlPresentationMapper.playPause(for: .paused)
            let buffering = PlayerControlPresentationMapper.playPause(for: .buffering)
            let preparing = PlayerControlPresentationMapper.playPause(for: .preparing)
            let failed = PlayerControlPresentationMapper.playPause(for: .failed)

            #expect(playing.accessibilityValue == "Playing")
            #expect(paused.accessibilityValue == "Paused")
            #expect(buffering.accessibilityValue == "Buffering")
            #expect(preparing.accessibilityValue == "Preparing")
            #expect(failed.accessibilityValue == "Failed")
        }
    }

    // MARK: - Reduce Motion Accessibility Tests

    @Suite("Reduce Motion Accessibility Policy Tests")
    struct ReduceMotionAccessibilityTests {
        @Test("PlayerView shouldAnimateForAccessibility returns false when reduceMotion enabled")
        func shouldNotAnimateWhenReduceMotionEnabled() {
            #expect(PlayerView.shouldAnimateForAccessibility(reduceMotion: true) == false)
        }

        @Test("PlayerView shouldAnimateForAccessibility returns true when reduceMotion disabled")
        func shouldAnimateWhenReduceMotionDisabled() {
            #expect(PlayerView.shouldAnimateForAccessibility(reduceMotion: false) == true)
        }
    }

    // MARK: - Internationalized String Format Tests

    @Suite("Internationalized String Format Tests")
    struct InternationalizedStringFormatTests {
        @Test("runtimeText formats minutes correctly")
        func runtimeTextFormatsMinutes() {
            #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: 45) == "45 min")
            #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: 120) == "120 min")
        }

        @Test("runtimeText returns nil for invalid values")
        func runtimeTextNilForInvalid() {
            #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: nil) == nil)
            #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: 0) == nil)
            #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: -1) == nil)
        }

        @Test("imdbRatingText formats rating correctly")
        func imdbRatingTextFormatsRating() {
            #expect(SeriesDetailPresentationPolicy.imdbRatingText(8.5) == "8.5 IMDb")
            #expect(SeriesDetailPresentationPolicy.imdbRatingText(7.0) == "7.0 IMDb")
            #expect(SeriesDetailPresentationPolicy.imdbRatingText(10.0) == "10.0 IMDb")
        }

        @Test("imdbRatingText returns nil for invalid values")
        func imdbRatingTextNilForInvalid() {
            #expect(SeriesDetailPresentationPolicy.imdbRatingText(nil) == nil)
            #expect(SeriesDetailPresentationPolicy.imdbRatingText(0) == nil)
            #expect(SeriesDetailPresentationPolicy.imdbRatingText(-1) == nil)
        }

        @Test("episodeTitle handles various titles")
        func episodeTitleHandlesVariousTitles() {
            #expect(SeriesDetailPresentationPolicy.episodeTitle("Pilot", episodeNumber: 1) == "Pilot")
            #expect(SeriesDetailPresentationPolicy.episodeTitle("", episodeNumber: 2) == "Episode 2")
            #expect(SeriesDetailPresentationPolicy.episodeTitle(nil, episodeNumber: 3) == "Episode 3")
        }
    }

    // MARK: - VoiceOver Support String Validation Tests

    @Suite("VoiceOver Support String Validation Tests")
    struct VoiceOverSupportTests {
        @Test("All accessibility labels have meaningful length")
        func accessibilityLabelsHaveMeaningfulLength() {
            let discoverLabel = TabBarAccessibilityPolicy.accessibilityLabel(for: .discover, isSelected: false)
            #expect(discoverLabel.count >= 3)

            let searchLabel = TabBarAccessibilityPolicy.accessibilityLabel(for: .search, isSelected: false)
            #expect(searchLabel.count >= 3)
        }

        @Test("All accessibility hints have minimum length for clarity")
        func accessibilityHintsHaveMinimumLength() {
            for tab in SidebarTab.allCases {
                let hint = TabBarAccessibilityPolicy.accessibilityHint(for: tab)
                #expect(hint.count >= 5, "Hint for \(tab) is too short: \(hint)")
            }
        }

        @Test("Accessibility hints do not end with periods")
        func accessibilityHintsDoNotEndWithPeriods() {
            for tab in SidebarTab.allCases {
                let hint = TabBarAccessibilityPolicy.accessibilityHint(for: tab)
                #expect(!hint.hasSuffix("."), "Hint for \(tab) ends with period: \(hint)")
            }
        }

        @Test("Tab labels are capitalized properly")
        func tabLabelsAreCapitalized() {
            for tab in SidebarTab.allCases {
                let label = TabBarAccessibilityPolicy.accessibilityLabel(for: tab, isSelected: false)
                #expect(label.first?.isUppercase == true, "Label should start with uppercase: \(label)")
            }
        }
    }
}
