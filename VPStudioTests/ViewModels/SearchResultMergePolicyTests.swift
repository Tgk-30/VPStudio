import Testing
@testable import VPStudio

@Suite("SearchResultMergePolicy")
struct SearchResultMergePolicyTests {
    @Test
    func mergeReturnsPrimaryWhenSecondaryHasNoItems() {
        let primary = MetadataSearchResult(
            items: [
                Fixtures.mediaPreview(id: "movie-1", title: "Primary"),
            ],
            page: 2,
            totalPages: 5,
            totalResults: 50
        )
        let secondary = MetadataSearchResult(
            items: [],
            page: 1,
            totalPages: 10,
            totalResults: 100
        )

        let merged = SearchResultMergePolicy.merge(primary: primary, secondary: secondary)

        #expect(merged.items.map(\.id) == ["movie-1"])
        #expect(merged.page == primary.page)
        #expect(merged.totalPages == primary.totalPages)
        #expect(merged.totalResults == primary.totalResults)
    }

    @Test
    func mergeAppendsPersonCreditResultsAfterPrimaryResults() {
        let primary = MetadataSearchResult(
            items: [
                Fixtures.mediaPreview(id: "movie-1", title: "Primary"),
            ],
            page: 1,
            totalPages: 3,
            totalResults: 20
        )
        let secondary = MetadataSearchResult(
            items: [
                Fixtures.mediaPreview(id: "movie-2", title: "Credit"),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )

        let merged = SearchResultMergePolicy.merge(primary: primary, secondary: secondary)

        #expect(merged.items.map(\.id) == ["movie-1", "movie-2"])
        #expect(merged.page == 1)
        #expect(merged.totalPages == 3)
        #expect(merged.totalResults == 20)
    }

    @Test
    func mergeDeduplicatesByStableMediaID() {
        let primary = MetadataSearchResult(
            items: [Fixtures.mediaPreview(id: "movie-1", title: "Primary")],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let secondary = MetadataSearchResult(
            items: [
                Fixtures.mediaPreview(id: "movie-1", title: "Duplicate"),
                Fixtures.mediaPreview(id: "movie-2", title: "Credit"),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 2
        )

        let merged = SearchResultMergePolicy.merge(primary: primary, secondary: secondary)

        #expect(merged.items.map(\.id) == ["movie-1", "movie-2"])
        #expect(merged.totalResults == 2)
    }

    @Test
    func mergeUsesSecondaryPagingMetadataWhenPrimaryIsEmpty() {
        let primary = MetadataSearchResult(
            items: [],
            page: 1,
            totalPages: 1,
            totalResults: 0
        )
        let secondary = MetadataSearchResult(
            items: [
                Fixtures.mediaPreview(id: "movie-1", title: "Credit 1"),
                Fixtures.mediaPreview(id: "movie-2", title: "Credit 2"),
            ],
            page: 1,
            totalPages: 4,
            totalResults: 40
        )

        let merged = SearchResultMergePolicy.merge(primary: primary, secondary: secondary)

        #expect(merged.items.map(\.id) == ["movie-1", "movie-2"])
        #expect(merged.page == 1)
        #expect(merged.totalPages == 4)
        #expect(merged.totalResults == 40)
    }
}
