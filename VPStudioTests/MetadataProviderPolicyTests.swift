import Foundation
import Testing
@testable import VPStudio

@Suite("MetadataProvider Policies")
struct MetadataProviderPolicyTests {
    @Test
    func discoverFilterDateHelpersUseUTCAndOffsets() {
        let now = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 00:00:00 UTC

        #expect(DiscoverFilters.todayString(now: now) == "2025-01-01")
        #expect(DiscoverFilters.dateString(daysFromNow: 7, now: now) == "2025-01-08")
        #expect(DiscoverFilters.dateString(daysFromNow: -1, now: now) == "2024-12-31")
    }

    @Test(arguments: [
        ("en-US", "en"),
        ("JA-jp", "ja"),
        ("pt", "pt"),
        ("", ""),
    ])
    func iso639LanguageCodeUsesFirstLocaleComponent(locale: String, expected: String) {
        #expect(DiscoverFilters.iso639LanguageCode(from: locale) == expected)
    }

    @Test
    func sortOptionsMapSeriesSpecificTMDBFields() {
        #expect(DiscoverFilters.SortOption.releaseDateDesc.tmdbValue(for: .movie) == "primary_release_date.desc")
        #expect(DiscoverFilters.SortOption.releaseDateDesc.tmdbValue(for: .series) == "first_air_date.desc")
        #expect(DiscoverFilters.SortOption.releaseDateAsc.tmdbValue(for: .series) == "first_air_date.asc")
        #expect(DiscoverFilters.SortOption.titleAsc.tmdbValue(for: .movie) == "title.asc")
        #expect(DiscoverFilters.SortOption.titleAsc.tmdbValue(for: .series) == "name.asc")
        #expect(DiscoverFilters.SortOption.ratingDesc.tmdbValue(for: .series) == "vote_average.desc")
    }

    @Test
    func mediaTypeSearchYearParameterMatchesTMDBAPI() {
        #expect(MediaType.movie.tmdbSearchYearParameterName == "year")
        #expect(MediaType.series.tmdbSearchYearParameterName == "first_air_date_year")
    }

    @Test
    func mediaCategoriesDifferForMovieAndSeries() {
        #expect(MediaCategory.categories(for: .movie) == [.popular, .topRated, .nowPlaying, .upcoming])
        #expect(MediaCategory.categories(for: .series) == [.popular, .topRated, .airingToday, .onTheAir])
        #expect(MediaCategory.nowPlaying.displayName == "Now Playing")
        #expect(MediaCategory.onTheAir.displayName == "On The Air")
    }

    @Test
    func defaultSearchOverloadIgnoresYearAndLanguage() async throws {
        let provider = DefaultSearchOnlyMetadataProvider()

        let result = try await provider.search(
            query: " dune ",
            type: .movie,
            page: 3,
            year: 2021,
            language: "en"
        )

        #expect(result.page == 3)
        #expect(result.totalResults == 1)
        #expect(await provider.recordedQueries == [" dune "])
        #expect(await provider.recordedTypes == [.movie])
        #expect(await provider.recordedPages == [3])
    }

    @Test
    func defaultMetadataProviderRejectsTMDBOnlyHooksWhenProviderDoesNotSupportThem() async throws {
        let provider = DefaultSearchOnlyMetadataProvider()

        await #expect(throws: MetadataProviderError.unsupportedIdentifier("tmdb-438631")) {
            _ = try await provider.getSeasons(tmdbId: 438_631)
        }
        await #expect(throws: MetadataProviderError.unsupportedIdentifier("tmdb-438631")) {
            _ = try await provider.getEpisodes(tmdbId: 438_631, season: 1)
        }
        await #expect(throws: MetadataProviderError.unsupportedIdentifier("tmdb-438631")) {
            _ = try await provider.getExternalIds(tmdbId: 438_631, type: .movie)
        }
    }

    @Test
    func omdbServiceDoesNotCarryTMDBOnlyMetadataStubs() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("VPStudio/Services/Metadata/OMDbService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("func getSeasons(tmdbId:"))
        #expect(!source.contains("func getEpisodes(tmdbId:"))
        #expect(!source.contains("func getExternalIds(tmdbId:"))
        #expect(source.contains("func getSeasons(id: String, type: MediaType)"))
        #expect(source.contains("func getEpisodes(id: String, type: MediaType, season: Int)"))
    }

    @Test
    func metadataProviderConfigurationRequiresOMDbForPrimaryConfiguredState() {
        #expect(MetadataProviderConfiguration(omdbApiKey: " omdb ").isConfigured)
        #expect(!MetadataProviderConfiguration(tmdbApiKey: " tmdb ").isConfigured)
        #expect(MetadataProviderConfiguration(tmdbApiKey: " tmdb ").hasAnyProvider)
        #expect(MetadataProviderConfiguration(omdbApiKey: " omdb ", tmdbApiKey: " tmdb ").providerSummary == "OMDb + legacy TMDb fallback")
        #expect(!MetadataProviderConfiguration(omdbApiKey: "  ", tmdbApiKey: "\n").isConfigured)
        #expect(!MetadataProviderConfiguration(omdbApiKey: "  ", tmdbApiKey: "\n").hasAnyProvider)
        #expect(MetadataProviderConfiguration(omdbApiKey: "omdb").omdbPlan == .free)
        #expect(MetadataProviderPlan.fromStoredValue(" paid ") == .paid)
        #expect(MetadataProviderPlan.fromStoredValue("unknown") == .free)
    }

    @Test
    func metadataProviderFactoryModeCoversSingleProviderAndPaidArtworkRoutes() {
        #expect(MetadataProviderFactory.mode(for: MetadataProviderConfiguration()) == .unconfigured)
        #expect(MetadataProviderFactory.mode(for: MetadataProviderConfiguration(omdbApiKey: "omdb")) == .omdbOnly)
        #expect(MetadataProviderFactory.mode(for: MetadataProviderConfiguration(tmdbApiKey: "tmdb")) == .tmdbOnly)
        #expect(MetadataProviderFactory.mode(for: MetadataProviderConfiguration(
            omdbApiKey: "omdb",
            tmdbApiKey: "tmdb"
        )) == .dualProviderOMDbArtwork)
        #expect(MetadataProviderFactory.mode(for: MetadataProviderConfiguration(
            omdbApiKey: "omdb",
            tmdbApiKey: "tmdb",
            omdbPlan: .paid,
            tmdbPlan: .free
        )) == .dualProviderOMDbPaidArtwork)
        #expect(MetadataProviderFactory.mode(for: MetadataProviderConfiguration(
            omdbApiKey: "omdb",
            tmdbApiKey: "tmdb",
            omdbPlan: .paid,
            tmdbPlan: .paid
        )) == .dualProviderOMDbArtwork)
    }

    @Test
    func metadataProviderFactoryBuildsExpectedProviderForEachConfiguredKeySet() {
        let unconfigured = MetadataProviderFactory.make(configuration: MetadataProviderConfiguration())
        let omdbOnly = MetadataProviderFactory.make(configuration: MetadataProviderConfiguration(omdbApiKey: "omdb"))
        let tmdbOnly = MetadataProviderFactory.make(configuration: MetadataProviderConfiguration(tmdbApiKey: "tmdb"))
        let both = MetadataProviderFactory.make(configuration: MetadataProviderConfiguration(
            omdbApiKey: "omdb",
            tmdbApiKey: "tmdb"
        ))

        #expect(unconfigured is UnconfiguredMetadataProvider)
        #expect(!(unconfigured is OMDbService))
        #expect(omdbOnly is OMDbService)
        #expect(tmdbOnly is TMDBService)
        #expect(both is CompositeMetadataProvider)
    }

    @Test
    func unconfiguredMetadataProviderFailsWithoutStartingEmptyCredentialOMDbRequests() async {
        let provider = MetadataProviderFactory.make(configuration: MetadataProviderConfiguration())

        await #expect(throws: MetadataProviderError.unsupportedIdentifier("unconfigured")) {
            _ = try await provider.search(query: "Dune", type: .movie, page: 1)
        }
        await #expect(throws: MetadataProviderError.unsupportedIdentifier("unconfigured")) {
            _ = try await provider.getDetail(id: "tt1160419", type: .movie)
        }
        await #expect(throws: MetadataProviderError.unsupportedIdentifier("unconfigured")) {
            _ = try await provider.getEpisodes(id: "tt0944947", type: .series, season: 1)
        }
    }

    @Test
    func metadataProviderIdentifierPolicyNormalizesTMDBIDs() {
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "438631") == 438_631)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: " TMDB-438631 ") == 438_631)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "MOVIE-TMDB-438631") == 438_631)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "series-tmdb-1396") == 1_396)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "episode-tmdb-62086") == 62_086)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "tmdb-episode-62086") == 62_086)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "tmdb-0") == nil)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "movie-tmdb-438631-extra") == nil)
        #expect(MetadataProviderIdentifierPolicy.tmdbID(from: "polluted-tmdb-438631") == nil)
    }

    @Test
    func searchDiscoverAndDetailUsePlanAwareFactoriesForPaidArtworkRoutes() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let searchSource = try String(
            contentsOf: repoRoot.appendingPathComponent("VPStudio/ViewModels/Search/SearchViewModel.swift"),
            encoding: .utf8
        )
        let discoverSource = try String(
            contentsOf: repoRoot.appendingPathComponent("VPStudio/ViewModels/Discover/DiscoverViewModel.swift"),
            encoding: .utf8
        )
        let detailSource = try String(
            contentsOf: repoRoot.appendingPathComponent("VPStudio/ViewModels/Detail/DetailViewModel.swift"),
            encoding: .utf8
        )
        let planAwareCondition = "configuration.hasTMDb || configuration.omdbPlan.usesPaidResources"

        #expect(searchSource.contains(planAwareCondition))
        #expect(discoverSource.contains(planAwareCondition))
        #expect(detailSource.contains(planAwareCondition))
        #expect(searchSource.contains("MetadataProviderFactory.make(configuration: configuration)"))
        #expect(discoverSource.contains("MetadataProviderFactory.make(configuration: configuration)"))
        #expect(detailSource.contains("MetadataProviderFactory.make(configuration: configuration)"))
    }

    @Test
    func compositeProviderKeepsOMDbIdentityAndUsesTMDbAsFallbackArtwork() async throws {
        let tmdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tmdb-603",
                type: .movie,
                title: "The Matrix",
                year: 1999,
                posterPath: "/tmdb-poster.jpg",
                backdropPath: "/tmdb-backdrop.jpg",
                overview: "TMDb overview",
                genres: ["Action"],
                imdbRating: 8.2,
                runtime: 136,
                tmdbId: 603
            )
        )
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "TT0133093",
                type: .movie,
                title: "The Matrix",
                year: 1999,
                posterPath: "https://m.media-amazon.com/images/M/matrix.jpg",
                backdropPath: nil,
                overview: "OMDb overview",
                genres: ["Sci-Fi"],
                imdbRating: 8.7,
                runtime: 136,
                tmdbId: nil
            )
        )
        let provider = CompositeMetadataProvider(omdbProvider: omdb, tmdbProvider: tmdb)

        let detail = try await provider.getDetail(id: "tt0133093", type: .movie)

        #expect(detail.id == "movie-omdb-tt0133093")
        #expect(detail.posterPath == "https://m.media-amazon.com/images/M/matrix.jpg")
        #expect(detail.backdropPath == "/tmdb-backdrop.jpg")
        #expect(detail.imdbRating == 8.7)
        #expect(detail.tmdbId == 603)
        #expect(await omdb.detailIDs == ["tt0133093"])
    }

    @Test
    func compositeProviderUsesTitleLookupForOMDbWhenTMDBHasNoIMDbID() async throws {
        let tmdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tmdb-438631",
                type: .movie,
                title: "Dune: Part Two",
                year: 2024,
                posterPath: "/tmdb-poster.jpg",
                backdropPath: "/tmdb-backdrop.jpg",
                imdbRating: 8.4,
                tmdbId: 438_631
            )
        )
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tt15239678",
                type: .movie,
                title: "Dune: Part Two",
                year: 2024,
                posterPath: "https://m.media-amazon.com/images/M/dune-two.jpg",
                backdropPath: "https://img.omdbapi.com/?i=tt15239678&h=720",
                imdbRating: 8.5
            )
        )
        let provider = CompositeMetadataProvider(
            omdbProvider: omdb,
            tmdbProvider: tmdb,
            prefersOMDbArtwork: true
        )

        let detail = try await provider.getDetail(id: "tmdb-438631", type: .movie)

        #expect(await omdb.detailIDs == ["Dune: Part Two (2024)"])
        #expect(detail.id == "movie-omdb-tt15239678")
        #expect(detail.posterPath == "https://m.media-amazon.com/images/M/dune-two.jpg")
        #expect(detail.backdropPath == "https://img.omdbapi.com/?i=tt15239678&h=720")
        #expect(detail.imdbRating == 8.5)
        #expect(detail.tmdbId == 438_631)
    }

    @Test
    func compositeProviderRoutesTitleLookupsToOMDbBeforeTMDB() async throws {
        let tmdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tmdb-438631",
                type: .movie,
                title: "Dune: Part Two",
                year: 2024,
                posterPath: "/tmdb-poster.jpg",
                backdropPath: "/tmdb-backdrop.jpg",
                imdbRating: 8.4,
                tmdbId: 438_631
            ),
            acceptedDetailIDs: ["tt15239678"]
        )
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tt15239678",
                type: .movie,
                title: "Dune: Part Two",
                year: 2024,
                posterPath: "https://m.media-amazon.com/images/M/dune-two.jpg",
                backdropPath: "https://img.omdbapi.com/?i=tt15239678&h=720",
                imdbRating: 8.5
            ),
            acceptedDetailIDs: ["Dune: Part Two (2024)"]
        )
        let provider = CompositeMetadataProvider(
            omdbProvider: omdb,
            tmdbProvider: tmdb,
            prefersOMDbArtwork: true
        )

        let detail = try await provider.getDetail(id: "Dune: Part Two (2024)", type: .movie)

        #expect(await omdb.detailIDs == ["Dune: Part Two (2024)"])
        #expect(await tmdb.detailIDs == ["tt15239678"])
        #expect(detail.id == "movie-omdb-tt15239678")
        #expect(detail.posterPath == "https://m.media-amazon.com/images/M/dune-two.jpg")
        #expect(detail.backdropPath == "https://img.omdbapi.com/?i=tt15239678&h=720")
        #expect(detail.imdbRating == 8.5)
        #expect(detail.tmdbId == 438_631)
    }

    @Test
    func compositeProviderCanPreferPaidOMDbArtworkWhenTMDBIsStandard() async throws {
        let tmdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tmdb-603",
                type: .movie,
                title: "The Matrix",
                year: 1999,
                posterPath: "/tmdb-poster.jpg",
                backdropPath: "/tmdb-backdrop.jpg",
                imdbRating: 8.2,
                tmdbId: 603
            )
        )
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tt0133093",
                type: .movie,
                title: "The Matrix",
                year: 1999,
                posterPath: "https://m.media-amazon.com/images/M/matrix.jpg",
                backdropPath: "https://img.omdbapi.com/?i=tt0133093&h=720",
                imdbRating: 8.7
            )
        )
        let provider = CompositeMetadataProvider(
            omdbProvider: omdb,
            tmdbProvider: tmdb,
            prefersOMDbArtwork: true
        )

        let detail = try await provider.getDetail(id: "tt0133093", type: .movie)

        #expect(detail.posterPath == "https://m.media-amazon.com/images/M/matrix.jpg")
        #expect(detail.backdropPath == "https://img.omdbapi.com/?i=tt0133093&h=720")
        #expect(detail.imdbRating == 8.7)
        #expect(detail.tmdbId == 603)
    }

    @Test
    func compositeProviderDoesNotMergeOMDbAndTMDbDetailsAcrossMediaTypes() async throws {
        let tmdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tmdb-100",
                type: .movie,
                title: "Twin Title",
                year: 2024,
                posterPath: "/movie-poster.jpg",
                imdbRating: 6.2,
                tmdbId: 100
            )
        )
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tt1234567",
                type: .series,
                title: "Twin Title",
                year: 2024,
                posterPath: "https://m.media-amazon.com/images/M/show.jpg",
                imdbRating: 8.9
            )
        )
        let provider = CompositeMetadataProvider(omdbProvider: omdb, tmdbProvider: tmdb)

        let detail = try await provider.getDetail(id: "tmdb-100", type: .movie)

        #expect(detail.id == "tmdb-100")
        #expect(detail.posterPath == "/movie-poster.jpg")
        #expect(detail.imdbRating == 6.2)
        #expect(detail.tmdbId == 100)
    }

    @Test
    func compositeProviderSearchUsesOMDbBeforeTMDbWhenConfigured() async throws {
        let tmdbResult = MetadataSearchResult(
            items: [
                MediaPreview(
                    id: "movie-tmdb-603",
                    type: .movie,
                    title: "The Matrix",
                    year: 1999,
                    posterPath: "/tmdb-poster.jpg",
                    backdropPath: "/tmdb-backdrop.jpg",
                    imdbRating: 8.2,
                    tmdbId: 603
                ),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let omdbResult = MetadataSearchResult(
            items: [
                MediaPreview(
                    id: "tt0133093",
                    type: .movie,
                    title: "The Matrix",
                    year: 1999,
                    posterPath: "https://m.media-amazon.com/images/M/matrix.jpg",
                    backdropPath: nil,
                    imdbRating: 8.7,
                    tmdbId: nil
                ),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let tmdb = CompositeTestMetadataProvider(searchResult: tmdbResult)
        let omdb = CompositeTestMetadataProvider(searchResult: omdbResult)
        let provider = CompositeMetadataProvider(omdbProvider: omdb, tmdbProvider: tmdb)

        let result = try await provider.search(query: "matrix", type: .movie, page: 1)
        let preview = try #require(result.items.first)

        #expect(preview.id == "tt0133093")
        #expect(preview.posterPath == "https://m.media-amazon.com/images/M/matrix.jpg")
        #expect(preview.backdropPath == nil)
        #expect(preview.imdbRating == 8.7)
        #expect(preview.tmdbId == nil)
        #expect(await omdb.searchQueries == ["matrix"])
        #expect(await tmdb.searchQueries == [])
    }

    @Test
    func compositeProviderFallsBackToTMDbSearchWhenOMDbSearchFails() async throws {
        let tmdbResult = MetadataSearchResult(
            items: [
                MediaPreview(
                    id: "movie-tmdb-603",
                    type: .movie,
                    title: "The Matrix",
                    year: 1999,
                    posterPath: "/tmdb-poster.jpg",
                    backdropPath: "/tmdb-backdrop.jpg",
                    imdbRating: 8.2,
                    tmdbId: 603
                ),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let tmdb = CompositeTestMetadataProvider(searchResult: tmdbResult)
        let omdb = CompositeTestMetadataProvider(shouldFailSearch: true)
        let provider = CompositeMetadataProvider(
            omdbProvider: omdb,
            tmdbProvider: tmdb
        )

        let result = try await provider.search(query: "matrix", type: .movie, page: 1)
        let preview = try #require(result.items.first)

        #expect(preview.id == "movie-tmdb-603")
        #expect(preview.posterPath == "/tmdb-poster.jpg")
        #expect(preview.backdropPath == "/tmdb-backdrop.jpg")
        #expect(preview.imdbRating == 8.2)
        #expect(preview.tmdbId == 603)
        #expect(await omdb.searchQueries == ["matrix"])
        #expect(await tmdb.searchQueries == ["matrix"])
    }

    @Test
    func compositeProviderDoesNotAdoptMismatchedOMDbIdentity() async throws {
        let tmdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tmdb-603",
                type: .movie,
                title: "The Matrix",
                year: 1999,
                posterPath: "/tmdb-poster.jpg",
                backdropPath: "/tmdb-backdrop.jpg",
                imdbRating: 8.2,
                tmdbId: 603
            )
        )
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tt9999999",
                type: .movie,
                title: "The Matrix Reloaded",
                year: 2003,
                posterPath: "https://m.media-amazon.com/images/M/reloaded.jpg",
                imdbRating: 7.2,
                tmdbId: nil
            )
        )
        let provider = CompositeMetadataProvider(omdbProvider: omdb, tmdbProvider: tmdb)

        let detail = try await provider.getDetail(id: "tmdb-603", type: .movie)

        #expect(detail.id == "tmdb-603")
        #expect(detail.title == "The Matrix")
        #expect(detail.year == 1999)
        #expect(detail.posterPath == "/tmdb-poster.jpg")
        #expect(detail.imdbRating == 8.2)
        #expect(detail.tmdbId == 603)
    }

    @Test
    func compositeProviderDoesNotReenrichTMDbFallbackSearchFromMismatchedOMDbIdentity() async throws {
        let tmdbResult = MetadataSearchResult(
            items: [
                MediaPreview(
                    id: "movie-tmdb-603",
                    type: .movie,
                    title: "The Matrix",
                    year: 1999,
                    posterPath: "/tmdb-poster.jpg",
                    imdbRating: 8.2,
                    tmdbId: 603
                ),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let tmdb = CompositeTestMetadataProvider(searchResult: tmdbResult)
        let omdb = CompositeTestMetadataProvider(
            detail: MediaItem(
                id: "tt9999999",
                type: .movie,
                title: "The Matrix Reloaded",
                year: 2003,
                posterPath: "https://m.media-amazon.com/images/M/reloaded.jpg",
                imdbRating: 7.2
            ),
            shouldFailSearch: true
        )
        let provider = CompositeMetadataProvider(omdbProvider: omdb, tmdbProvider: tmdb)

        let result = try await provider.search(query: "matrix", type: .movie, page: 1)
        let preview = try #require(result.items.first)

        #expect(preview.id == "movie-tmdb-603")
        #expect(preview.posterPath == "/tmdb-poster.jpg")
        #expect(preview.imdbRating == 8.2)
        #expect(preview.tmdbId == 603)
        #expect(await omdb.detailIDs == [])
    }

    @Test
    func compositeProviderDoesNotCallTMDbWhenOMDbSearchSucceeds() async throws {
        let omdbResult = MetadataSearchResult(
            items: [MediaPreview(id: "tt0111161", type: .movie, title: "The Shawshank Redemption", year: 1994)],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let tmdb = CompositeTestMetadataProvider(searchResult: MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0))
        let omdb = CompositeTestMetadataProvider(searchResult: omdbResult)
        let provider = CompositeMetadataProvider(omdbProvider: omdb, tmdbProvider: tmdb)

        let result = try await provider.search(query: "shawshank", type: .movie, page: 1)

        #expect(result.items.map(\.id) == ["tt0111161"])
        #expect(await omdb.searchQueries == ["shawshank"])
        #expect(await tmdb.searchQueries == [])
    }
}

private actor DefaultSearchOnlyMetadataProvider: MetadataProvider {
    private(set) var recordedQueries: [String] = []
    private(set) var recordedTypes: [MediaType?] = []
    private(set) var recordedPages: [Int] = []

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        recordedQueries.append(query)
        recordedTypes.append(type)
        recordedPages.append(page)
        return MetadataSearchResult(
            items: [],
            page: page,
            totalPages: 1,
            totalResults: 1
        )
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        MediaItem(id: id, type: type, title: "Detail")
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: filters.page, totalPages: 1, totalResults: 0)
    }

    func getGenres(type: MediaType) async throws -> [Genre] { [] }
}

private actor CompositeTestMetadataProvider: MetadataProvider {
    enum Failure: Error {
        case forced
    }

    let detail: MediaItem?
    let searchResult: MetadataSearchResult?
    let shouldFailSearch: Bool
    let acceptedDetailIDs: Set<String>?
    private(set) var detailIDs: [String] = []
    private(set) var searchQueries: [String] = []

    init(
        detail: MediaItem? = nil,
        searchResult: MetadataSearchResult? = nil,
        shouldFailSearch: Bool = false,
        acceptedDetailIDs: Set<String>? = nil
    ) {
        self.detail = detail
        self.searchResult = searchResult
        self.shouldFailSearch = shouldFailSearch
        self.acceptedDetailIDs = acceptedDetailIDs
    }

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        searchQueries.append(query)
        if shouldFailSearch {
            throw Failure.forced
        }
        return searchResult ?? MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        detailIDs.append(id)
        if let acceptedDetailIDs, !acceptedDetailIDs.contains(id) {
            throw Failure.forced
        }
        guard let detail else { throw Failure.forced }
        return detail
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        try await search(query: "trending", type: type, page: page)
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        try await search(query: category.rawValue, type: type, page: page)
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        try await search(query: "discover", type: type, page: filters.page)
    }

    func getGenres(type: MediaType) async throws -> [Genre] { [] }
}
