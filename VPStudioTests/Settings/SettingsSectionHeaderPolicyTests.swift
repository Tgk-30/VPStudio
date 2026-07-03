import Testing
@testable import VPStudio

@Suite("Settings Section Header Policy")
struct SettingsSectionHeaderPolicyTests {
    @Test
    func eachCategoryHasValidIcon() {
        for category in SettingsCategory.allCases {
            let icon = SettingsSectionHeaderPolicy.icon(for: category)
            #expect(!icon.isEmpty, "Icon for \(category) should not be empty")
        }
    }

    @Test
    func connectIconIsLink() {
        #expect(SettingsSectionHeaderPolicy.icon(for: .connect) == "link")
    }

    @Test
    func iconsUseExpectedSymbolForEveryCategory() {
        let expected: [SettingsCategory: String] = [
            .connect: "link",
            .watch: "play.circle",
            .discover: "sparkles",
            .library: "books.vertical",
            .about: "info.circle",
        ]

        for (category, icon) in expected {
            #expect(SettingsSectionHeaderPolicy.icon(for: category) == icon)
        }
    }

    @Test
    func summaryTextFormatting() {
        let text = SettingsSectionHeaderPolicy.summaryText(
            category: .connect,
            configuredCount: 2,
            totalCount: 3
        )
        #expect(text == "2/3 configured")
    }

    @Test
    func summaryTextZeroConfigured() {
        let text = SettingsSectionHeaderPolicy.summaryText(
            category: .watch,
            configuredCount: 0,
            totalCount: 4
        )
        #expect(text == "0/4 configured")
    }

    @Test
    func summaryTextZeroTotalReturnsNoItems() {
        let text = SettingsSectionHeaderPolicy.summaryText(
            category: .about,
            configuredCount: 0,
            totalCount: 0
        )
        #expect(text == "No items")
    }

    @Test
    func summaryTextNegativeTotalReturnsNoItems() {
        let text = SettingsSectionHeaderPolicy.summaryText(
            category: .about,
            configuredCount: 3,
            totalCount: -1
        )
        #expect(text == "No items")
    }

    @Test
    func summaryTextKeepsOutOfRangeConfiguredCounts() {
        let negative = SettingsSectionHeaderPolicy.summaryText(
            category: .library,
            configuredCount: -1,
            totalCount: 4
        )
        let overTotal = SettingsSectionHeaderPolicy.summaryText(
            category: .library,
            configuredCount: 6,
            totalCount: 4
        )

        #expect(negative == "-1/4 configured")
        #expect(overTotal == "6/4 configured")
    }
}
