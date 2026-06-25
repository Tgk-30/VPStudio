import Foundation
import Testing
@testable import VPStudio

private struct FixedTorrentIndexer: TorrentIndexer {
    let name: String
    var imdbResults: [TorrentResult] = []
    var queryResults: [TorrentResult] = []
    var searchError: Error?
    var queryError: Error?

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        if let searchError { throw searchError }
        return imdbResults
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        if let queryError { throw queryError }
        return queryResults
    }
}

private struct SlowTorrentIndexer: TorrentIndexer {
    let name: String

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        try await waitPastTimeout()
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        try await waitPastTimeout()
    }

    private func waitPastTimeout() async throws -> [TorrentResult] {
        try await Task.sleep(for: .seconds(5))
        return []
    }
}

private final class CapturedIndexerSearchState: @unchecked Sendable {
    var imdbId: String?
}

private struct CapturingTorrentIndexer: TorrentIndexer {
    let name = "Capturing"
    let state: CapturedIndexerSearchState

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        state.imdbId = imdbId
        return []
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        []
    }
}

@Suite("Indexer Manager Dedup And Sort")
struct IndexerManagerDedupAndSortTests {
    struct CaseData: Sendable {
        let lhs: TorrentResult
        let rhs: TorrentResult
        let expectedFirstHash: String
        let expectedFirstSeeders: Int
    }

    private static func preferredTorrent(lhs: TorrentResult, rhs: TorrentResult) -> TorrentResult {
        if lhs.isCached != rhs.isCached {
            return lhs.isCached ? lhs : rhs
        }
        if lhs.quality != rhs.quality {
            return lhs.quality > rhs.quality ? lhs : rhs
        }
        if lhs.seeders != rhs.seeders {
            return lhs.seeders > rhs.seeders ? lhs : rhs
        }
        return lhs.infoHash <= rhs.infoHash ? lhs : rhs
    }

    private static let cases: [CaseData] = {
        var values: [CaseData] = []
        for idx in 0..<72 {
            let hash = "hash-\(idx / 3)"
            let first = Fixtures.torrent(
                hash: hash,
                title: "Title A \(idx)",
                quality: idx % 2 == 0 ? .uhd4k : .hd1080p,
                seeders: 5 + idx,
                cached: idx % 4 == 0
            )
            let second = Fixtures.torrent(
                hash: idx % 3 == 0 ? hash : "hash-\(idx)-alt",
                title: "Title B \(idx)",
                quality: idx % 2 == 0 ? .hd1080p : .uhd4k,
                seeders: 10 + idx,
                cached: idx % 5 == 0
            )

            let expected = preferredTorrent(lhs: first, rhs: second)

            values.append(CaseData(
                lhs: first,
                rhs: second,
                expectedFirstHash: expected.infoHash,
                expectedFirstSeeders: expected.seeders
            ))
        }
        return values
    }()

    @Test(arguments: ExhaustiveMode.choose(fast: Array(cases.prefix(20)), full: cases))
    func deduplicateAndSortMatrix(data: CaseData) {
        let ranked = IndexerManager.deduplicateAndSort([data.lhs, data.rhs])
        #expect(!ranked.isEmpty)

        if data.lhs.infoHash == data.rhs.infoHash {
            #expect(ranked.count == 1)
            #expect(ranked[0].seeders == data.expectedFirstSeeders)
        } else {
            #expect(ranked.count == 2)
            for index in 1..<ranked.count {
                let previous = ranked[index - 1]
                let current = ranked[index]
                let ordered: Bool
                if previous.isCached != current.isCached {
                    ordered = previous.isCached
                } else if previous.quality != current.quality {
                    ordered = previous.quality > current.quality
                } else {
                    ordered = previous.seeders >= current.seeders
                }
                #expect(ordered)
            }
        }

        #expect(ranked.first?.infoHash == data.expectedFirstHash)
    }

    @Test
    func sortsBySeederCountWhenCacheAndQualityMatch() {
        let weaker = Fixtures.torrent(
            hash: "weaker",
            title: "Same Quality A",
            quality: .hd1080p,
            seeders: 12,
            cached: false
        )
        let stronger = Fixtures.torrent(
            hash: "stronger",
            title: "Same Quality B",
            quality: .hd1080p,
            seeders: 48,
            cached: false
        )

        let ranked = IndexerManager.deduplicateAndSort([weaker, stronger])

        #expect(ranked.map(\.infoHash) == ["stronger", "weaker"])
    }

    @Test
    func choosesLowerIDWhenDedupedResultFieldsAreEquivalent() {
        let first = Fixtures.torrent(
            hash: "shared-hash",
            title: "Duplicate One",
            quality: .hd1080p,
            seeders: 24,
            cached: true,
            indexerName: "ZedIndexer"
        )
        let second = Fixtures.torrent(
            hash: "shared-hash",
            title: "Duplicate Two",
            quality: .hd1080p,
            seeders: 24,
            cached: true,
            indexerName: "AlphaIndexer"
        )

        let ranked = IndexerManager.deduplicateAndSort([first, second])

        #expect(ranked.count == 1)
        #expect(ranked[0].indexerName == "AlphaIndexer")
        #expect(ranked[0].infoHash == "shared-hash")
    }

    @Test
    func sortsByResultIDWhenCacheQualityAndSeederCountsTie() {
        let lower = Fixtures.torrent(
            hash: "hash-zeta",
            title: "Lower-ID Item",
            quality: .hd1080p,
            seeders: 10,
            cached: true,
            indexerName: "zzz"
        )
        let higher = Fixtures.torrent(
            hash: "hash-alpha",
            title: "Higher-ID Item",
            quality: .hd1080p,
            seeders: 10,
            cached: true,
            indexerName: "aaa"
        )

        let ranked = IndexerManager.deduplicateAndSort([lower, higher])

        #expect(ranked.map(\.id) == [higher.id, lower.id])
    }

    @Test
    func deduplicatesSameInfoHashAcrossCaseDifferences() {
        let uppercase = Fixtures.torrent(
            hash: "ABCDEF1234567890",
            title: "Same Hash Upper",
            seeders: 4,
            cached: false
        )
        let lowercase = Fixtures.torrent(
            hash: "abcdef1234567890",
            title: "Same Hash Lower",
            seeders: 8
        )

        let ranked = IndexerManager.deduplicateAndSort([uppercase, lowercase])

        #expect(ranked.count == 1)
        #expect(ranked[0].seeders == 8)
        #expect(ranked[0].title == "Same Hash Lower")
    }

    @Test
    func deduplicatesCaseVariantHashWithCachedResultPreference() {
        let cached = Fixtures.torrent(
            hash: "ABCDEF1234567890",
            title: "Cached Upper",
            seeders: 1,
            cached: true
        )
        let nonCached = Fixtures.torrent(
            hash: "abcdef1234567890",
            title: "Uncached Lower",
            seeders: 99
        )

        let ranked = IndexerManager.deduplicateAndSort([cached, nonCached])

        #expect(ranked.count == 1)
        #expect(ranked[0].isCached)
        #expect(ranked[0].title == "Cached Upper")
    }
}

@Suite("Indexer Manager Search")
struct IndexerManagerSearchTests {
    @Test
    func imdbSeriesSearchFiltersEpisodeTokensAndKeepsUntokenizedResults() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-search.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let matching = Fixtures.torrent(hash: "hash-match", title: "Show S01E02 1080p", seeders: 30)
        let seasonPack = Fixtures.torrent(hash: "hash-pack", title: "Show Season 1 Pack", seeders: 20)
        let wrongEpisode = Fixtures.torrent(hash: "hash-wrong", title: "Show S01E03 1080p", seeders: 40)
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", imdbResults: [wrongEpisode, seasonPack, matching])
            ],
            hasInitialized: true
        )

        let results = try await manager.search(imdbId: "tt1234567", type: .series, season: 1, episode: 2)

        #expect(results.map(\.infoHash) == ["hash-match", "hash-pack"])
        #expect(await manager.lastSearchErrors.isEmpty)
    }

    @Test
    func imdbSearchNormalizesEmbeddedIDsBeforeProviderDispatch() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-normalization.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let state = CapturedIndexerSearchState()
        let manager = IndexerManager(
            database: database,
            indexers: [CapturingTorrentIndexer(state: state)],
            hasInitialized: true
        )

        _ = try await manager.search(
            imdbId: "https://www.imdb.com/title/TT1160419/",
            type: .movie,
            season: nil,
            episode: nil
        )

        #expect(state.imdbId == "tt1160419")
    }

    @Test
    func imdbSeriesSearchFiltersEpisodeMatchesBeforeDeduplication() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-dedup-filtering.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let matching = Fixtures.torrent(
            hash: "hash-shared",
            title: "Show S01E02 1080p",
            seeders: 40,
            cached: false
        )
        let nonMatchingHigherPriority = Fixtures.torrent(
            hash: "hash-shared",
            title: "Show S01E03 1080p",
            seeders: 500,
            cached: true
        )

        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", imdbResults: [nonMatchingHigherPriority, matching])
            ],
            hasInitialized: true
        )

        let results = try await manager.search(imdbId: "tt1234567", type: .series, season: 1, episode: 2)

        #expect(results.map(\.infoHash) == ["hash-shared"])
        #expect(results.first?.title == "Show S01E02 1080p")
    }

    @Test
    func querySearchReturnsResultsWhenOneIndexerFailsAndRecordsSanitizedError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-partial.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        struct TokenError: LocalizedError {
            var errorDescription: String? {
                "failed https://indexer.example/api?apikey=abcdef1234567890abcdef"
            }
        }
        let result = Fixtures.torrent(hash: "hash-result", title: "Movie 1080p", seeders: 5)
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Broken", queryError: TokenError()),
                FixedTorrentIndexer(name: "Working", queryResults: [result]),
            ],
            hasInitialized: true
        )

        let results = try await manager.searchByQuery(query: "Movie", type: .movie)
        let errors = await manager.lastSearchErrors

        #expect(results.map(\.infoHash) == ["hash-result"])
        #expect(errors.count == 1)
        #expect(errors.first?.indexer == "Broken")
        #expect(errors.first?.error.contains("abcdef1234567890abcdef") == false)
        #expect(errors.first?.error.contains("apikey=REDACTED") == true)
    }

    @Test
    func searchByQueryReturnsPartialResultsAndRecordsOnlyFailedIndexers() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-partial-success.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        struct SensitiveError: LocalizedError {
            var errorDescription: String? { "failed with api=token-abcdefghijklmnop" }
        }

        let result = Fixtures.torrent(hash: "hash-result", title: "Movie 1080p", seeders: 5)
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Broken", queryError: SensitiveError()),
                FixedTorrentIndexer(name: "Working", queryResults: [result]),
            ],
            hasInitialized: true
        )

        let results = try await manager.searchByQuery(query: "Movie", type: .movie)
        let errors = await manager.lastSearchErrors

        #expect(results.map(\.infoHash) == ["hash-result"])
        #expect(errors.count == 1)
        #expect(errors.first?.indexer == "Broken")
    }

    @Test
    func querySeriesSearchFiltersByEpisodeContext() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-series.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let matching = Fixtures.torrent(hash: "hash-match", title: "Show S02E04 1080p", seeders: 4)
        let untokenized = Fixtures.torrent(hash: "hash-pack", title: "Show Season Pack", seeders: 20)
        let wrong = Fixtures.torrent(hash: "hash-wrong", title: "Show S02E05 1080p", seeders: 50)
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", queryResults: [wrong, untokenized, matching])
            ],
            hasInitialized: true
        )

        let results = try await manager.searchByQuery(query: "Show S02E04", type: .series)

        #expect(results.map(\.infoHash) == ["hash-match"])
    }

    @Test
    func querySeriesSearchFiltersEpisodeMatchesBeforeDeduplication() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-dedup-filtering.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let matching = Fixtures.torrent(
            hash: "hash-shared",
            title: "Show S02E04 1080p",
            seeders: 4,
            cached: false
        )
        let nonMatchingHigherPriority = Fixtures.torrent(
            hash: "hash-shared",
            title: "Show S02E05 1080p",
            seeders: 500,
            cached: true
        )

        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", queryResults: [nonMatchingHigherPriority, matching])
            ],
            hasInitialized: true
        )

        let results = try await manager.searchByQuery(query: "Show S02E04", type: .series)

        #expect(results.map(\.infoHash) == ["hash-shared"])
        #expect(results.first?.title == "Show S02E04 1080p")
    }

    @Test
    func querySeriesSearchWithoutEpisodeContextKeepsAllResults() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-series-no-context.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let matching = Fixtures.torrent(hash: "hash-episode", title: "Show S01E02 1080p", seeders: 10)
        let untokenized = Fixtures.torrent(hash: "hash-pack", title: "Show Season Pack", seeders: 20)
        let otherEpisode = Fixtures.torrent(hash: "hash-other", title: "Show S01E03 720p", seeders: 15)

        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", queryResults: [matching, untokenized, otherEpisode])
            ],
            hasInitialized: true
        )

        let results = try await manager.searchByQuery(query: "Show", type: .series)

        #expect(Set(results.map(\.infoHash)) == Set(["hash-pack", "hash-episode", "hash-other"]))
    }

    @Test
    func searchByQueryCapturesAllFailuresWhenAllIndexersFail() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-all-failed.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        struct SensitiveError: LocalizedError {
            let token: String
            var errorDescription: String? {
                "failed with key \(token)"
            }
        }
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "First", queryError: SensitiveError(token: "apikey-abcdefghijklmnop")),
                FixedTorrentIndexer(name: "Second", queryError: SensitiveError(token: "token-abcdefghijklmnop")),
            ],
            hasInitialized: true
        )

        do {
            _ = try await manager.searchByQuery(query: "Movie", type: .movie)
            Issue.record("Expected IndexerManagerError.allIndexersFailed")
        } catch let error as IndexerManagerError {
            if case .allIndexersFailed(let details) = error {
                #expect(details.contains("REDACTED"))
            } else {
                Issue.record("Unexpected IndexerError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let errors = await manager.lastSearchErrors
        #expect(errors.count == 2)
        let names = Set(errors.map(\.indexer))
        #expect(names == Set(["First", "Second"]))
        #expect(errors.allSatisfy { $0.error.contains("abcdefghijklmnop") == false })
    }

    @Test
    func querySeriesSearchWithMalformedContextFallsBackToNoFilter() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-series-malformed-context.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let matching = Fixtures.torrent(hash: "hash-match", title: "Show 1920x1080 REMUX", seeders: 8)
        let wrong = Fixtures.torrent(hash: "hash-wrong", title: "Show Pack", seeders: 12)

        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", queryResults: [matching, wrong])
            ],
            hasInitialized: true
        )

        let results = try await manager.searchByQuery(query: "Show 1920x1080 REMUX", type: .series)

        #expect(Set(results.map(\.infoHash)) == Set(["hash-match", "hash-wrong"]))
    }

    @Test
    func imdbSearchSeriesSeasonOnlyDoesNotFilterEpisode() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-season-only.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let match = Fixtures.torrent(hash: "hash-match", title: "Show S01E02 1080p", seeders: 10)
        let wrongEpisode = Fixtures.torrent(hash: "hash-wrong", title: "Show S01E03 720p", seeders: 4)

        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Fixed", imdbResults: [match, wrongEpisode])
            ],
            hasInitialized: true
        )

        let results = try await manager.search(imdbId: "tt1234567", type: .series, season: 1, episode: nil)

        #expect(results.map(\.infoHash) == ["hash-match", "hash-wrong"])
    }

    @Test
    func searchByQueryWithNoIndexersReturnsEmptyAndNoErrors() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-no-indexers-query.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        let manager = IndexerManager(database: database, indexers: [], hasInitialized: true)

        let queryResults = try await manager.searchByQuery(query: "Movie", type: .movie)
        let imdbResults = try await manager.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        let errors = await manager.lastSearchErrors

        #expect(queryResults.isEmpty)
        #expect(imdbResults.isEmpty)
        #expect(errors.isEmpty)
    }

    @Test
    func searchByImdbReturnsPartialResultsAndRecordsOnlyFailedIndexers() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-partial.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        struct TimeoutError: LocalizedError {
            var errorDescription: String? { "connection timeout" }
        }

        let result = Fixtures.torrent(hash: "hash-result", title: "Show 1080p", seeders: 12)
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Broken", searchError: TimeoutError()),
                FixedTorrentIndexer(name: "Working", imdbResults: [result]),
            ],
            hasInitialized: true
        )

        let results = try await manager.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        let errors = await manager.lastSearchErrors

        #expect(results.map(\.infoHash) == ["hash-result"])
        #expect(errors.count == 1)
        #expect(errors.first?.indexer == "Broken")
    }

    @Test
    func searchByQueryReturnsPartialResultsWhenOneIndexerTimesOut() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-timeout-partial.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let result = Fixtures.torrent(hash: "hash-result", title: "Movie 1080p", seeders: 8)
        let manager = IndexerManager(
            database: database,
            indexers: [
                SlowTorrentIndexer(name: "Slow"),
                FixedTorrentIndexer(name: "Working", queryResults: [result]),
            ],
            hasInitialized: true,
            perIndexerSearchTimeout: .milliseconds(25)
        )

        let results = try await manager.searchByQuery(query: "Movie", type: .movie)
        let errors = await manager.lastSearchErrors

        #expect(results.map(\.infoHash) == ["hash-result"])
        #expect(errors.count == 1)
        #expect(errors.first?.indexer == "Slow")
        #expect(errors.first?.error == "Timed out waiting for indexer response.")
    }

    @Test
    func searchByImdbResetsLastSearchErrorsAfterTransientFailure() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-refresh-errors.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        struct SampleError: LocalizedError {
            var errorDescription: String? { "temporary failure: token-abcdefghijklmnop" }
        }

        let result = Fixtures.torrent(hash: "hash-result", title: "Show 1080p", seeders: 12)
        let indexer = RetryCapableTorrentIndexer(
            name: "Flaky",
            firstError: SampleError(),
            subsequentResults: [result]
        )
        let manager = IndexerManager(database: database, indexers: [indexer], hasInitialized: true)

        do {
            _ = try await manager.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
            Issue.record("Expected IndexerManagerError.allIndexersFailed")
        } catch {
            // Expected on first run.
        }

        #expect((await manager.lastSearchErrors).count == 1)
        #expect((await manager.lastSearchErrors).first?.indexer == "Flaky")

        let secondResults = try await manager.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        #expect(secondResults.map(\.infoHash) == ["hash-result"])
        #expect((await manager.lastSearchErrors).isEmpty)
    }

    @Test
    func searchByQueryResetsLastSearchErrorsAfterTransientFailure() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-refresh-errors.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        struct SampleError: LocalizedError {
            var errorDescription: String? { "temporary failure: apikey-abcdefghijklmnop" }
        }

        let result = Fixtures.torrent(hash: "hash-result", title: "Movie 1080p", seeders: 5)
        let indexer = RetryCapableTorrentIndexer(
            name: "Flaky",
            firstError: SampleError(),
            subsequentResults: [result]
        )
        let manager = IndexerManager(database: database, indexers: [indexer], hasInitialized: true)

        do {
            _ = try await manager.searchByQuery(query: "Movie", type: .movie)
            Issue.record("Expected IndexerManagerError.allIndexersFailed")
        } catch {
            // Expected on first run.
        }

        #expect((await manager.lastSearchErrors).count == 1)
        #expect((await manager.lastSearchErrors).first?.indexer == "Flaky")

        let secondResults = try await manager.searchByQuery(query: "Movie", type: .movie)
        #expect(secondResults.map(\.infoHash) == ["hash-result"])
        #expect(await manager.lastSearchErrors.isEmpty)
    }

    @Test
    func searchByQueryResetsErrorsWhenAllIndexersRecover() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-query-recovery.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        struct SampleError: LocalizedError {
            var errorDescription: String? { "temporary failure: apikey-abcdefghijklmnop" }
        }

        let firstResults = [Fixtures.torrent(hash: "hash-first", title: "Movie One 1080p", seeders: 11)]
        let secondResults = [Fixtures.torrent(hash: "hash-second", title: "Movie Two 1080p", seeders: 12)]
        let manager = IndexerManager(
            database: database,
            indexers: [
                RetryCapableTorrentIndexer(name: "FlakyA", firstError: SampleError(), subsequentResults: firstResults),
                RetryCapableTorrentIndexer(name: "FlakyB", firstError: SampleError(), subsequentResults: secondResults)
            ],
            hasInitialized: true
        )

        do {
            _ = try await manager.searchByQuery(query: "Movie", type: .movie)
            Issue.record("Expected IndexerManagerError.allIndexersFailed")
        } catch {
            // Expected on first run.
        }
        #expect((await manager.lastSearchErrors).count == 2)

        let secondRunResults = try await manager.searchByQuery(query: "Movie", type: .movie)
        #expect(Set(secondRunResults.map(\.infoHash)) == Set(["hash-first", "hash-second"]))
        #expect((await manager.lastSearchErrors).isEmpty)
    }

    @Test
    func searchImdbReturnsAllIndexersFailedWhenAllIndexersError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-imdb-all-failed.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }
        struct TimeoutError: LocalizedError {
            var errorDescription: String? { "timed out after too long" }
        }
        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(name: "Timeout", searchError: TimeoutError()),
                FixedTorrentIndexer(name: "Also Timeout", searchError: TimeoutError()),
            ],
            hasInitialized: true
        )

        do {
            _ = try await manager.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
            Issue.record("Expected IndexerManagerError.allIndexersFailed")
        } catch let error as IndexerManagerError {
            guard case .allIndexersFailed = error else {
                Issue.record("Unexpected IndexerError: \(error)")
                return
            }
            #expect(await manager.lastSearchErrors.count == 2)
            #expect(await manager.lastSearchErrors.contains(where: { $0.indexer == "Timeout" }))
            #expect(await manager.lastSearchErrors.contains(where: { $0.indexer == "Also Timeout" }))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func searchByQueryPreservesIndexerNameThatContainsColon() async throws {
        let (database, rootDir) = try await makeDatabase(named: "indexer-manager-colon-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "transport failure: connection timed out"
            }
        }

        let manager = IndexerManager(
            database: database,
            indexers: [
                FixedTorrentIndexer(
                    name: "Index:With:Colon",
                    queryError: SampleError()
                )
            ],
            hasInitialized: true
        )

        do {
            _ = try await manager.searchByQuery(query: "Movie", type: .movie)
            Issue.record("Expected IndexerManagerError.allIndexersFailed")
        } catch {
            let errors = await manager.lastSearchErrors
            #expect(errors.count == 1)
            #expect(errors.first?.indexer == "Index:With:Colon")
            #expect(errors.first?.error == "transport failure: connection timed out")
        }
    }

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    private actor RetryCapableTorrentIndexer: TorrentIndexer {
        nonisolated let name: String
        let firstError: Error
        let subsequentResults: [TorrentResult]
        private var hasFailedOnce = false

        init(name: String, firstError: Error, subsequentResults: [TorrentResult]) {
            self.name = name
            self.firstError = firstError
            self.subsequentResults = subsequentResults
        }

        func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
            try await run()
        }

        func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
            try await run()
        }

        private func run() async throws -> [TorrentResult] {
            if hasFailedOnce {
                return subsequentResults
            }
            hasFailedOnce = true
            throw firstError
        }
    }
}

@Suite("Indexer Log Sanitizer")
struct IndexerLogSanitizerTestsIndexermanagerdedupandsorttests {
    @Test
    func redactsSensitiveQueryItemsUserInfoAndFragments() {
        let url = URL(string: "https://user:password@indexer.example/path/movie.mkv?apikey=secret-key&query=dune&token=abcdef1234567890abcdef#frag")!

        let redacted = IndexerLogSanitizer.redactedURL(url)

        #expect(redacted.contains("user") == false)
        #expect(redacted.contains("password") == false)
        #expect(redacted.contains("secret-key") == false)
        #expect(redacted.contains("abcdef1234567890abcdef") == false)
        #expect(redacted.contains("apikey=REDACTED"))
        #expect(redacted.contains("token=REDACTED"))
        #expect(redacted.contains("query=dune"))
        #expect(redacted.contains("#frag") == false)
    }

    @Test
    func redactsTokenLikePathSegmentsButKeepsNormalPathSegments() {
        let url = URL(string: "https://indexer.example/api/abcdef1234567890abcdef/results/movie.mkv")!

        let redacted = IndexerLogSanitizer.redactedURL(url)

        #expect(redacted.contains("abcdef1234567890abcdef") == false)
        #expect(redacted.contains("/api/REDACTED/results/movie.mkv"))
    }

    @Test
    func redactsPercentEncodedTokenLikePathSegments() {
        let url = URL(string: "https://indexer.example/api/%61bcdef1234567890abcdef/results")!

        let redacted = IndexerLogSanitizer.redactedURL(url)

        #expect(redacted.contains("%61bcdef1234567890abcdef") == false)
        #expect(redacted.contains("abcdef1234567890abcdef") == false)
        #expect(redacted.contains("/api/REDACTED/results"))
    }

    @Test
    func redactsTokenLikeQueryValuesEvenWhenNameIsNotSensitive() {
        let url = URL(string: "https://indexer.example/search?session=abcdef1234567890abcdef&query=dune")!

        let redacted = IndexerLogSanitizer.redactedURL(url)

        #expect(redacted.contains("session=REDACTED"))
        #expect(redacted.contains("abcdef1234567890abcdef") == false)
        #expect(redacted.contains("query=dune"))
    }

    @Test
    func redactedURLStringHandlesNilInvalidAndPlainSensitiveValues() {
        #expect(IndexerLogSanitizer.redactedURLString(nil) == "nil")
        #expect(IndexerLogSanitizer.redactedURLString("") == "nil")
        #expect(IndexerLogSanitizer.redactedURLString("not a url") == "REDACTED")
        #expect(IndexerLogSanitizer.redactedURLString("abcdef1234567890abcdef") == "REDACTED")
        #expect(IndexerLogSanitizer.redactedURLString("http://[::1") == "REDACTED")
        #expect(IndexerLogSanitizer.redactedURLString("abcdefghijklmnopqrstuvwxyz") == "REDACTED")
        #expect(IndexerLogSanitizer.redactedURLString("movie_title") == "movie_title")
    }

    @Test
    func redactsSensitiveQueryParamsWithUppercaseKeys() {
        let url = URL(string: "https://indexer.example/search?ApiKey=ABCD1234-SECRET-5678EFGH&signature=AbCdEfGh1234567890")!

        let redacted = IndexerLogSanitizer.redactedURL(url)

        #expect(redacted.contains("ABCD1234-SECRET-5678EFGH") == false)
        #expect(redacted.contains("AbCdEfGh1234567890") == false)
        #expect(redacted.contains("ApiKey=REDACTED"))
        #expect(redacted.contains("signature=REDACTED"))
    }

    @Test
    func redactsErrorMessagesWithPlainSensitiveText() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "failed with API_KEY=ABCDEFGHIJKLMNOP and bearer=qrstuvwxyz12345678"
            }
        }

        let redacted = IndexerLogSanitizer.redactedErrorMessage(SampleError())

        #expect(redacted.contains("ABCDEFGHIJKLMNOP") == false)
        #expect(redacted.contains("qrstuvwxyz12345678") == false)
    }

    @Test
    func redactsEmbeddedHTTPAndMagnetURLsFromErrorMessages() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "failed https://indexer.example/api?apikey=abcdef1234567890abcdef and magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&token=abcdef1234567890abcdef&dn=Movie"
            }
        }

        let redacted = IndexerLogSanitizer.redactedErrorMessage(SampleError())

        #expect(redacted.contains("abcdef1234567890abcdef") == false)
        #expect(redacted.contains("0123456789abcdef0123456789abcdef01234567"))
        #expect(redacted.contains("apikey=REDACTED"))
        #expect(redacted.contains("token=REDACTED"))
    }

    @Test
    func managerErrorDescriptionIncludesSanitizedFailureDetails() {
        let error = IndexerManagerError.allIndexersFailed("Indexer: Network error")

        #expect(error.errorDescription == "All indexers failed: Indexer: Network error")
    }

    @Test
    func parseErrorDescriptionNamesIndexerAndReason() {
        let error = IndexerParseError.invalidPayload(indexer: "Sample", reason: "missing torrents")

        #expect(error.errorDescription == "Sample returned an invalid response: missing torrents")
    }
}
