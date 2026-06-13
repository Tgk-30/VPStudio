import Testing
@testable import VPStudio

@Suite("QuickStartPromptPolicy")
struct QuickStartPromptPolicyTests {
    @Test
    func skipSetupCopyAndDestinationStayStable() {
        #expect(QuickStartPromptPolicy.skipSetupDestination == .library)
        #expect(QuickStartPromptPolicy.skipSetupTitle == "Browse Library")
        #expect(QuickStartPromptPolicy.bodyCopy == "Skip setup for now and browse Library, or run setup to unlock Discover, Search, and streaming features.")
    }

    @Test(arguments: SidebarTab.allCases)
    func restoredTabAcceptsCurrentRawValues(tab: SidebarTab) {
        #expect(QuickStartPromptPolicy.restoredTab(from: tab.rawValue) == tab)
    }

    @Test
    func restoredTabAcceptsLegacySearchRawValue() {
        #expect(QuickStartPromptPolicy.restoredTab(from: "Search") == .search)
    }

    @Test
    func restoredTabRejectsUnknownRawValue() {
        #expect(QuickStartPromptPolicy.restoredTab(from: "Unknown") == nil)
    }

    @Test
    func shouldShowPromptOnlyWhenRecommendationIsUndismissedAndDiscoverSelected() {
        #expect(
            QuickStartPromptPolicy.shouldShowPrompt(
                setupRecommendationNeeded: true,
                promptDismissed: false,
                selectedTab: .discover
            )
        )
        #expect(
            QuickStartPromptPolicy.shouldShowPrompt(
                setupRecommendationNeeded: false,
                promptDismissed: false,
                selectedTab: .discover
            ) == false
        )
        #expect(
            QuickStartPromptPolicy.shouldShowPrompt(
                setupRecommendationNeeded: true,
                promptDismissed: true,
                selectedTab: .discover
            ) == false
        )
        #expect(
            QuickStartPromptPolicy.shouldShowPrompt(
                setupRecommendationNeeded: true,
                promptDismissed: false,
                selectedTab: .library
            ) == false
        )
        #expect(
            QuickStartPromptPolicy.shouldShowPrompt(
                setupRecommendationNeeded: true,
                promptDismissed: false,
                selectedTab: .discover,
                promptSuppressed: true
            ) == false
        )
    }
}

@Suite("RootLaunchOverlayPolicy")
struct RootLaunchOverlayPolicyTests {
    @Test
    func hidesLaunchOverlayForValidQATestScreens() {
        #expect(
            RootLaunchOverlayPolicy.shouldShowLaunchOverlay(
                isBootstrapping: true,
                qaTestScreenRawValue: "settings"
            ) == false
        )
        #expect(
            RootLaunchOverlayPolicy.shouldShowLaunchOverlay(
                isBootstrapping: true,
                qaTestScreenRawValue: "Search + Results"
            ) == false
        )
    }

    @Test
    func keepsLaunchOverlayForNormalAndInvalidLaunches() {
        #expect(
            RootLaunchOverlayPolicy.shouldShowLaunchOverlay(
                isBootstrapping: true,
                qaTestScreenRawValue: nil
            )
        )
        #expect(
            RootLaunchOverlayPolicy.shouldShowLaunchOverlay(
                isBootstrapping: true,
                qaTestScreenRawValue: "not-a-screen"
            )
        )
        #expect(
            RootLaunchOverlayPolicy.shouldShowLaunchOverlay(
                isBootstrapping: false,
                qaTestScreenRawValue: nil
            ) == false
        )
    }
}
