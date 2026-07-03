import Foundation
import Testing
@testable import VPStudio

struct ServicesMetadataProviderPolicyTests {

    // MARK: - DiscoverFilters

    @Test
    func test_discoverFilters_defaultValues() {
        let filters = DiscoverFilters()
        #expect(filters.genreId == nil)
        #expect(filters.year == nil)
        #expect(filters.minRating == nil)
        #expect(filters.sortBy == .popularityDesc)
        #expect(filters.page == 1)
        #expect(filters.language == nil)
        #expect(filters.releaseDateGte == nil)
        #expect(filters.releaseDateLte == nil)
        #expect(filters.originalLanguage == nil)
    }

    @Test
    func test_discoverFilters_customValues() {
        let filters = DiscoverFilters(
            genreId: 28,
            year: 2023,
            minRating: 7.5,
            sortBy: .ratingDesc,
            page: 2,
            language: "en-US",
            releaseDateGte: "2023-01-01",
            releaseDateLte: "2023-12-31",
            originalLanguage: "en"
        )
        #expect(filters.genreId == 28)
        #expect(filters.year == 2023)
        #expect(filters.minRating == 7.5)
        #expect(filters.sortBy == .ratingDesc)
        #expect(filters.page == 2)
        #expect(filters.language == "en-US")
    }

    // MARK: - SortOption Display Names

    @Test
    func test_sortOption_displayName() {
        #expect(DiscoverFilters.SortOption.popularityDesc.displayName == "Most Popular")
        #expect(DiscoverFilters.SortOption.popularityAsc.displayName == "Least Popular")
        #expect(DiscoverFilters.SortOption.ratingDesc.displayName == "Highest Rated")
        #expect(DiscoverFilters.SortOption.ratingAsc.displayName == "Lowest Rated")
        #expect(DiscoverFilters.SortOption.releaseDateDesc.displayName == "Newest")
        #expect(DiscoverFilters.SortOption.releaseDateAsc.displayName == "Oldest")
        #expect(DiscoverFilters.SortOption.titleAsc.displayName == "Title A-Z")
    }

    // MARK: - Date Helpers

    @Test
    func test_todayString_format() {
        let date = Date(timeIntervalSince1970: 0)
        let result = DiscoverFilters.todayString(now: date)
        #expect(result == "1970-01-01")
    }

    @Test
    func test_dateString_offset() {
        let baseDate = Date(timeIntervalSince1970: 0)
        let result = DiscoverFilters.dateString(daysFromNow: 365, now: baseDate)
        #expect(result == "1971-01-01")
    }

    // MARK: - ISO 639 Language Code

    @Test
    func test_iso639LanguageCode_twoPartLocale() {
        #expect(DiscoverFilters.iso639LanguageCode(from: "en-US") == "en")
        #expect(DiscoverFilters.iso639LanguageCode(from: "ja-JP") == "ja")
        #expect(DiscoverFilters.iso639LanguageCode(from: "zh-CN") == "zh")
    }

    @Test
    func test_iso639LanguageCode_singlePart() {
        #expect(DiscoverFilters.iso639LanguageCode(from: "en") == "en")
    }

    // MARK: - SortOption.tmdbValue

    @Test
    func test_tmdbValue_forMovie_releaseDateDesc() {
        #expect(DiscoverFilters.SortOption.releaseDateDesc.tmdbValue(for: .movie) == "primary_release_date.desc")
    }

    @Test
    func test_tmdbValue_forSeries_releaseDateDesc() {
        #expect(DiscoverFilters.SortOption.releaseDateDesc.tmdbValue(for: .series) == "first_air_date.desc")
    }

    @Test
    func test_tmdbValue_forSeries_releaseDateAsc() {
        #expect(DiscoverFilters.SortOption.releaseDateAsc.tmdbValue(for: .series) == "first_air_date.asc")
    }

    @Test
    func test_tmdbValue_forSeries_titleAsc() {
        #expect(DiscoverFilters.SortOption.titleAsc.tmdbValue(for: .series) == "name.asc")
    }

    // MARK: - MediaType.tmdbSearchYearParameterName

    @Test
    func test_tmdbSearchYearParameterName_movie() {
        #expect(MediaType.movie.tmdbSearchYearParameterName == "year")
    }

    @Test
    func test_tmdbSearchYearParameterName_series() {
        #expect(MediaType.series.tmdbSearchYearParameterName == "first_air_date_year")
    }

    // MARK: - TrendingWindow

    @Test
    func test_trendingWindow_rawValue() {
        #expect(TrendingWindow.day.rawValue == "day")
        #expect(TrendingWindow.week.rawValue == "week")
    }

    // MARK: - MediaCategory

    @Test
    func test_mediaCategory_displayName() {
        #expect(MediaCategory.popular.displayName == "Popular")
        #expect(MediaCategory.topRated.displayName == "Top Rated")
        #expect(MediaCategory.nowPlaying.displayName == "Now Playing")
        #expect(MediaCategory.upcoming.displayName == "Upcoming")
        #expect(MediaCategory.airingToday.displayName == "Airing Today")
        #expect(MediaCategory.onTheAir.displayName == "On The Air")
    }

    @Test
    func test_mediaCategory_categoriesForType_movie() {
        let categories = MediaCategory.categories(for: .movie)
        #expect(categories.contains(.popular))
        #expect(categories.contains(.topRated))
        #expect(categories.contains(.nowPlaying))
        #expect(categories.contains(.upcoming))
        #expect(!categories.contains(.airingToday))
    }

    @Test
    func test_mediaCategory_categoriesForType_series() {
        let categories = MediaCategory.categories(for: .series)
        #expect(categories.contains(.popular))
        #expect(categories.contains(.topRated))
        #expect(categories.contains(.airingToday))
        #expect(categories.contains(.onTheAir))
        #expect(!categories.contains(.nowPlaying))
    }
}
