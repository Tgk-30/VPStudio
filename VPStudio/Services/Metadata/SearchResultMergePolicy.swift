enum SearchResultMergePolicy {
    static func merge(
        primary: MetadataSearchResult,
        secondary: MetadataSearchResult
    ) -> MetadataSearchResult {
        guard !secondary.items.isEmpty else { return primary }

        var seenIDs = Set(primary.items.map(\.id))
        var mergedItems = primary.items
        for item in secondary.items where seenIDs.insert(item.id).inserted {
            mergedItems.append(item)
        }

        let totalResults = primary.items.isEmpty
            ? max(primary.totalResults, secondary.totalResults, mergedItems.count)
            : max(primary.totalResults, mergedItems.count)

        return MetadataSearchResult(
            items: mergedItems,
            page: primary.page,
            totalPages: max(primary.totalPages, primary.items.isEmpty ? secondary.totalPages : primary.totalPages),
            totalResults: totalResults
        )
    }
}
