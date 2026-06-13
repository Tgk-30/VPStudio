import Testing
@testable import VPStudio

struct NavigationTabBarAccessibilityPolicyTests {

    @Test
    func test_accessibilityLabel_selected() {
        #expect(TabBarAccessibilityPolicy.accessibilityLabel(for: .discover, isSelected: true) == "Discover, Selected")
        #expect(TabBarAccessibilityPolicy.accessibilityLabel(for: .search, isSelected: true) == "Explore, Selected")
        #expect(TabBarAccessibilityPolicy.accessibilityLabel(for: .library, isSelected: true) == "Library, Selected")
    }

    @Test
    func test_accessibilityLabel_notSelected() {
        #expect(TabBarAccessibilityPolicy.accessibilityLabel(for: .discover, isSelected: false) == "Discover")
        #expect(TabBarAccessibilityPolicy.accessibilityLabel(for: .search, isSelected: false) == "Explore")
        #expect(TabBarAccessibilityPolicy.accessibilityLabel(for: .settings, isSelected: false) == "Settings")
    }

    @Test
    func test_accessibilityHint() {
        #expect(TabBarAccessibilityPolicy.accessibilityHint(for: .discover) == "Browse featured and trending content")
        #expect(TabBarAccessibilityPolicy.accessibilityHint(for: .search) == "Search for movies and TV shows")
        #expect(TabBarAccessibilityPolicy.accessibilityHint(for: .library) == "View your saved media library")
        #expect(TabBarAccessibilityPolicy.accessibilityHint(for: .downloads) == "View and manage active downloads")
        #expect(TabBarAccessibilityPolicy.accessibilityHint(for: .environments) == "Choose an immersive environment")
        #expect(TabBarAccessibilityPolicy.accessibilityHint(for: .settings) == "Configure app preferences and accounts")
    }
}
