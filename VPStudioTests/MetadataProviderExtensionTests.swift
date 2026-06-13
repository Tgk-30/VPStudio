import Testing
import Foundation
@testable import VPStudio

@Suite("MetadataProvider Extension")
struct MetadataProviderExtensionTests {

    @Test("search with year and language delegates to basic search")
    func searchDelegatesToBasicSearch() async throws {
        final class MockProvider: MetadataProvider, @unchecked Sendable {
            var searchCallCount = 0
            var lastQuery = ""
            var lastType: MediaType?
            var lastPage = 0

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCallCount += 1
                lastQuery = query
                lastType = type
                lastPage = page
                return MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem {
                throw CancellationError()
            }

            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
                throw CancellationError()
            }

            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
                throw CancellationError()
            }

            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                throw CancellationError()
            }

            func getGenres(type: MediaType) async throws -> [Genre] {
                throw CancellationError()
            }

            func getSeasons(tmdbId: Int) async throws -> [Season] {
                throw CancellationError()
            }

            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
                throw CancellationError()
            }

            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
                throw CancellationError()
            }
        }

        let provider = MockProvider()
        _ = try await provider.search(query: "Test Movie", type: .movie, page: 1, year: 2024, language: "en")

        #expect(provider.searchCallCount == 1)
        #expect(provider.lastQuery == "Test Movie")
        #expect(provider.lastType == .movie)
        #expect(provider.lastPage == 1)
    }
}

@Suite("DiscoverFilters Helpers")
struct DiscoverFiltersHelpersTests {
    @Test("init stores every filter field")
    func initStoresEveryFilterField() {
        let filters = DiscoverFilters(
            genreId: 878,
            year: 2026,
            minRating: 7.5,
            sortBy: .ratingDesc,
            page: 3,
            language: "en-US",
            releaseDateGte: "2026-01-01",
            releaseDateLte: "2026-12-31",
            originalLanguage: "ja"
        )

        #expect(filters.genreId == 878)
        #expect(filters.year == 2026)
        #expect(filters.minRating == 7.5)
        #expect(filters.sortBy == .ratingDesc)
        #expect(filters.page == 3)
        #expect(filters.language == "en-US")
        #expect(filters.releaseDateGte == "2026-01-01")
        #expect(filters.releaseDateLte == "2026-12-31")
        #expect(filters.originalLanguage == "ja")
    }

    @Test("date helpers format UTC calendar dates")
    func dateHelpersFormatUTCDateStrings() {
        let epoch = Date(timeIntervalSince1970: 0)

        #expect(DiscoverFilters.todayString(now: epoch) == "1970-01-01")
        #expect(DiscoverFilters.dateString(daysFromNow: 1, now: epoch) == "1970-01-02")
        #expect(DiscoverFilters.dateString(daysFromNow: -1, now: epoch) == "1969-12-31")
    }

    @Test("iso639LanguageCode handles region and bare language codes")
    func iso639LanguageCodeExtractsLowercasedPrefix() {
        #expect(DiscoverFilters.iso639LanguageCode(from: "EN-US") == "en")
        #expect(DiscoverFilters.iso639LanguageCode(from: "ja-JP") == "ja")
        #expect(DiscoverFilters.iso639LanguageCode(from: "pt") == "pt")
    }
}

@Suite("DiscoverFilters.SortOption Extension")
struct DiscoverFiltersSortOptionExtensionTests {

    @Test("tmdbValue for releaseDateDesc with movie")
    func tmdbValueReleaseDateDescMovie() {
        let result = DiscoverFilters.SortOption.releaseDateDesc.tmdbValue(for: .movie)
        #expect(result == "primary_release_date.desc")
    }

    @Test("tmdbValue for releaseDateDesc with series")
    func tmdbValueReleaseDateDescSeries() {
        let result = DiscoverFilters.SortOption.releaseDateDesc.tmdbValue(for: .series)
        #expect(result == "first_air_date.desc")
    }

    @Test("tmdbValue for releaseDateAsc with series")
    func tmdbValueReleaseDateAscSeries() {
        let result = DiscoverFilters.SortOption.releaseDateAsc.tmdbValue(for: .series)
        #expect(result == "first_air_date.asc")
    }

    @Test("tmdbValue for titleAsc with series")
    func tmdbValueTitleAscSeries() {
        let result = DiscoverFilters.SortOption.titleAsc.tmdbValue(for: .series)
        #expect(result == "name.asc")
    }

    @Test("tmdbValue for titleAsc with movie")
    func tmdbValueTitleAscMovie() {
        let result = DiscoverFilters.SortOption.titleAsc.tmdbValue(for: .movie)
        #expect(result == "title.asc")
    }

    @Test("tmdbValue for popularityDesc returns raw value")
    func tmdbValuePopularityDesc() {
        let result = DiscoverFilters.SortOption.popularityDesc.tmdbValue(for: .movie)
        #expect(result == "popularity.desc")
    }

    @Test("tmdbValue for ratingDesc returns raw value")
    func tmdbValueRatingDesc() {
        let result = DiscoverFilters.SortOption.ratingDesc.tmdbValue(for: .movie)
        #expect(result == "vote_average.desc")
    }

    @Test("display names cover every sort option")
    func displayNamesCoverEverySortOption() {
        let expected: [(DiscoverFilters.SortOption, String)] = [
            (.popularityDesc, "Most Popular"),
            (.popularityAsc, "Least Popular"),
            (.ratingDesc, "Highest Rated"),
            (.ratingAsc, "Lowest Rated"),
            (.releaseDateDesc, "Newest"),
            (.releaseDateAsc, "Oldest"),
            (.titleAsc, "Title A-Z")
        ]

        #expect(DiscoverFilters.SortOption.allCases.count == expected.count)
        for (option, displayName) in expected {
            #expect(option.displayName == displayName)
        }
    }
}

@Suite("MediaType Extension")
struct MediaTypeExtensionTests {

    @Test("tmdbSearchYearParameterName for movie")
    func tmdbSearchYearParameterNameMovie() {
        #expect(MediaType.movie.tmdbSearchYearParameterName == "year")
    }

    @Test("tmdbSearchYearParameterName for series")
    func tmdbSearchYearParameterNameSeries() {
        #expect(MediaType.series.tmdbSearchYearParameterName == "first_air_date_year")
    }
}

@Suite("MediaCategory")
struct MediaCategoryPolicyTests {
    @Test("displayName covers every category")
    func displayNamesCoverEveryCategory() {
        let expected: [(MediaCategory, String)] = [
            (.popular, "Popular"),
            (.topRated, "Top Rated"),
            (.nowPlaying, "Now Playing"),
            (.upcoming, "Upcoming"),
            (.airingToday, "Airing Today"),
            (.onTheAir, "On The Air")
        ]

        #expect(MediaCategory.allCases.count == expected.count)
        for (category, displayName) in expected {
            #expect(category.displayName == displayName)
        }
    }

    @Test("categories differ by media type")
    func categoriesDifferByMediaType() {
        #expect(MediaCategory.categories(for: .movie) == [.popular, .topRated, .nowPlaying, .upcoming])
        #expect(MediaCategory.categories(for: .series) == [.popular, .topRated, .airingToday, .onTheAir])
    }
}
