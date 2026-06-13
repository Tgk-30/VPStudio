import Testing
@testable import VPStudio

@Suite("Library Empty State CTA Policy")
struct LibraryEmptyStateCTAPolicyTestsLibraryemptystatectapolicytests {
    @Test
    func eachListTypeHasNonEmptyTitle() {
        let types: [LibraryEmptyStateCTAPolicy.ListType] = [.favorites, .watchlist, .history, .downloads]
        for type in types {
            #expect(!LibraryEmptyStateCTAPolicy.title(for: type).isEmpty, "Title for \(type) should not be empty")
        }
    }

    @Test
    func eachListTypeHasNonEmptyDescription() {
        let types: [LibraryEmptyStateCTAPolicy.ListType] = [.favorites, .watchlist, .history, .downloads]
        for type in types {
            #expect(!LibraryEmptyStateCTAPolicy.description(for: type).isEmpty, "Description for \(type) should not be empty")
        }
    }

    @Test
    func eachListTypeHasNonEmptyIcon() {
        let types: [LibraryEmptyStateCTAPolicy.ListType] = [.favorites, .watchlist, .history, .downloads]
        for type in types {
            #expect(!LibraryEmptyStateCTAPolicy.icon(for: type).isEmpty, "Icon for \(type) should not be empty")
        }
    }

    @Test
    func favoritesActionIsSwitchToDiscover() {
        #expect(LibraryEmptyStateCTAPolicy.ctaAction(for: .favorites) == .switchToDiscover)
    }

    @Test
    func watchlistActionIsSwitchToDiscover() {
        #expect(LibraryEmptyStateCTAPolicy.ctaAction(for: .watchlist) == .switchToDiscover)
    }

    @Test
    func downloadsActionIsOpenSettings() {
        #expect(LibraryEmptyStateCTAPolicy.ctaAction(for: .downloads) == .openSettings)
    }

    @Test
    func eachListTypeUsesExpectedCopyIconLabelAndAction() {
        let cases: [(
            LibraryEmptyStateCTAPolicy.ListType,
            title: String,
            description: String,
            ctaLabel: String,
            icon: String,
            action: LibraryEmptyStateCTAPolicy.CTAAction
        )] = [
            (
                .favorites,
                title: "No Favorites Yet",
                description: "Mark movies and shows as favorites to keep them here for quick replay. AI picks can help you find new keepers.",
                ctaLabel: "Browse Discover",
                icon: "heart",
                action: .switchToDiscover
            ),
            (
                .watchlist,
                title: "Your Watchlist Is Empty",
                description: "Add titles you want to watch later. Use Explore + AI picks to fill this list faster.",
                ctaLabel: "Browse Discover",
                icon: "bookmark",
                action: .switchToDiscover
            ),
            (
                .history,
                title: "No Watch History",
                description: "Movies and shows you watch will automatically appear here as you play content.",
                ctaLabel: "Start Watching",
                icon: "clock",
                action: .switchToDiscover
            ),
            (
                .downloads,
                title: "No Downloads",
                description: "Downloaded content for offline viewing will appear here.",
                ctaLabel: "Go to Settings",
                icon: "arrow.down.circle",
                action: .openSettings
            )
        ]

        for testCase in cases {
            #expect(LibraryEmptyStateCTAPolicy.title(for: testCase.0) == testCase.title)
            #expect(LibraryEmptyStateCTAPolicy.description(for: testCase.0) == testCase.description)
            #expect(LibraryEmptyStateCTAPolicy.ctaLabel(for: testCase.0) == testCase.ctaLabel)
            #expect(LibraryEmptyStateCTAPolicy.icon(for: testCase.0) == testCase.icon)
            #expect(LibraryEmptyStateCTAPolicy.ctaAction(for: testCase.0) == testCase.action)
        }
    }
}
