import Testing
@testable import VPStudio

@Suite("SourceFilterPolicy")
struct SourceFilterPolicyTests {
    @Test
    func instantPresetHidesOnlyConfirmedUncachedResults() {
        var unknown = Fixtures.torrent(hash: "unknown", title: "Movie.1080p")
        unknown.cacheAvailability = .unknown

        var notCached = Fixtures.torrent(hash: "download", title: "Movie.1080p")
        notCached.cacheAvailability = .notCached

        let cached = Fixtures.torrent(hash: "cached", title: "Movie.1080p", cached: true)

        let filtered = SourceFilterPolicy.filtered(
            [unknown, notCached, cached],
            options: SourceFilterPreset.instant.defaultOptions
        )

        #expect(filtered.map(\.infoHash) == ["unknown", "cached"])
    }

    @Test
    func cinemaPresetRequires1080pAndSeederFloor() {
        let hdWithSeeders = Fixtures.torrent(hash: "hd", title: "Movie.1080p", quality: .hd1080p, seeders: 5)
        let lowQuality = Fixtures.torrent(hash: "low", title: "Movie.720p", quality: .hd720p, seeders: 20)
        let weakSwarm = Fixtures.torrent(hash: "weak", title: "Movie.2160p", quality: .uhd4k, seeders: 4)

        let filtered = SourceFilterPolicy.filtered(
            [hdWithSeeders, lowQuality, weakSwarm],
            options: SourceFilterPreset.cinema.defaultOptions
        )

        #expect(filtered.map(\.infoHash) == ["hd"])
    }

    @Test
    func compactPresetHidesLargeCamAndSeedlessSources() {
        let fit = Fixtures.torrent(
            hash: "fit",
            title: "Movie.1080p.WEB-DL",
            source: .webDL,
            seeders: 1,
            sizeBytes: 8 * 1_073_741_824
        )
        let tooLarge = Fixtures.torrent(
            hash: "large",
            title: "Movie.1080p.WEB-DL",
            source: .webDL,
            seeders: 10,
            sizeBytes: 20 * 1_073_741_824
        )
        let cam = Fixtures.torrent(hash: "cam", title: "Movie.CAM", source: .cam, seeders: 10)
        let seedless = Fixtures.torrent(hash: "seedless", title: "Movie.1080p", seeders: 0)

        let filtered = SourceFilterPolicy.filtered(
            [fit, tooLarge, cam, seedless],
            options: SourceFilterPreset.compact.defaultOptions
        )

        #expect(filtered.map(\.infoHash) == ["fit"])
    }

    @Test
    func customStoredValuesClampOutOfRangeNumbers() {
        let options = SourceFilterOptions.fromStoredValues(
            presetRawValue: SourceFilterPreset.custom.rawValue,
            hideConfirmedDownloads: true,
            hideCamSources: false,
            minimumSeedersRawValue: "999",
            maximumSizeGBRawValue: "500",
            minimumQualityRawValue: VideoQuality.hd720p.rawValue
        )

        #expect(options.hideConfirmedDownloads)
        #expect(options.hideCamSources == false)
        #expect(options.minimumSeeders == 500)
        #expect(options.maximumSizeGB == 250)
        #expect(options.minimumQuality == .hd720p)
    }

    @Test
    func presetMetadataAndDefaultsStayUserFacing() {
        #expect(SourceFilterPreset.allCases.map(\.displayName) == [
            "Balanced",
            "Instant",
            "Cinema",
            "Compact",
            "Custom"
        ])
        #expect(SourceFilterPreset.allCases.map(\.id) == [
            "balanced",
            "instant",
            "cinema",
            "compact",
            "custom"
        ])
        #expect(SourceFilterPreset.allCases.allSatisfy { !$0.summary.isEmpty })

        #expect(SourceFilterPreset.balanced.defaultOptions.activeDescriptions == ["No CAM"])
        #expect(SourceFilterPreset.instant.defaultOptions.activeDescriptions == ["Instant only", "No CAM"])
        #expect(SourceFilterPreset.cinema.defaultOptions.activeDescriptions == ["No CAM", "5+ seeders", "1080p+"])
        #expect(SourceFilterPreset.compact.defaultOptions.activeDescriptions == ["No CAM", "1+ seeders", "12 GB max"])
        #expect(SourceFilterPreset.custom.defaultOptions.activeDescriptions == ["No CAM"])
    }

    @Test
    func nonCustomStoredValuesIgnoreManualOverridesAndInvalidPresetFallsBackToBalanced() {
        let instant = SourceFilterOptions.fromStoredValues(
            presetRawValue: SourceFilterPreset.instant.rawValue,
            hideConfirmedDownloads: false,
            hideCamSources: false,
            minimumSeedersRawValue: "500",
            maximumSizeGBRawValue: "1",
            minimumQualityRawValue: VideoQuality.uhd4k.rawValue
        )
        let invalidPreset = SourceFilterOptions.fromStoredValues(
            presetRawValue: "unknown-preset",
            hideConfirmedDownloads: true,
            hideCamSources: false,
            minimumSeedersRawValue: "500",
            maximumSizeGBRawValue: "1",
            minimumQualityRawValue: VideoQuality.uhd4k.rawValue
        )

        #expect(instant == SourceFilterPreset.instant.defaultOptions)
        #expect(invalidPreset == SourceFilterPreset.balanced.defaultOptions)
    }

    @Test
    func customStoredValuesClampAndNormalizeInvalidInputs() {
        let options = SourceFilterOptions.fromStoredValues(
            presetRawValue: SourceFilterPreset.custom.rawValue,
            hideConfirmedDownloads: nil,
            hideCamSources: nil,
            minimumSeedersRawValue: " -4 ",
            maximumSizeGBRawValue: " 0 ",
            minimumQualityRawValue: VideoQuality.unknown.rawValue
        )
        let emptyQuality = SourceFilterOptions.fromStoredValues(
            presetRawValue: SourceFilterPreset.custom.rawValue,
            hideConfirmedDownloads: nil,
            hideCamSources: nil,
            minimumSeedersRawValue: "not-a-number",
            maximumSizeGBRawValue: "1.5",
            minimumQualityRawValue: "   "
        )
        let invalidQuality = SourceFilterOptions.fromStoredValues(
            presetRawValue: SourceFilterPreset.custom.rawValue,
            hideConfirmedDownloads: nil,
            hideCamSources: nil,
            minimumSeedersRawValue: nil,
            maximumSizeGBRawValue: nil,
            minimumQualityRawValue: "dvd-rip"
        )

        #expect(options.hideConfirmedDownloads == false)
        #expect(options.hideCamSources)
        #expect(options.minimumSeeders == 0)
        #expect(options.maximumSizeGB == nil)
        #expect(options.maximumSizeBytes == nil)
        #expect(options.minimumQuality == nil)
        #expect(emptyQuality.maximumSizeGB == 1.5)
        #expect(emptyQuality.maximumSizeBytes == 1_610_612_736)
        #expect(emptyQuality.activeDescriptions == ["No CAM", "1.5 GB max"])
        #expect(invalidQuality.minimumQuality == nil)
    }

    @Test
    func shouldKeepAllowsUnknownQualityButRejectsKnownLowerQuality() {
        let unknownQuality = Fixtures.torrent(hash: "unknown-quality", title: "Movie", quality: .unknown, seeders: 10)
        let lowerQuality = Fixtures.torrent(hash: "lower-quality", title: "Movie.720p", quality: .hd720p, seeders: 10)
        let options = SourceFilterOptions(
            preset: .custom,
            hideConfirmedDownloads: false,
            hideCamSources: false,
            minimumSeeders: 0,
            maximumSizeGB: nil,
            minimumQuality: .hd1080p
        )

        #expect(SourceFilterPolicy.shouldKeep(unknownQuality, options: options))
        #expect(SourceFilterPolicy.shouldKeep(lowerQuality, options: options) == false)
    }
}
