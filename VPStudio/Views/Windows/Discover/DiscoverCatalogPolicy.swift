import CoreGraphics
import Foundation

enum DiscoverCatalogKind: String, CaseIterable, Identifiable, Sendable {
    case trendingMovies
    case trendingShows
    case popularMovies
    case topRatedMovies
    case nowPlayingMovies

    var id: String { rawValue }

    var rowID: String {
        switch self {
        case .trendingMovies: return "trending-movies"
        case .trendingShows: return "trending-shows"
        case .popularMovies: return "popular-movies"
        case .topRatedMovies: return "top-rated-movies"
        case .nowPlayingMovies: return "now-playing-movies"
        }
    }

    var title: String {
        switch self {
        case .trendingMovies: return "Trending Now"
        case .trendingShows: return "Trending TV Shows"
        case .popularMovies: return "Popular"
        case .topRatedMovies: return "Top Rated"
        case .nowPlayingMovies: return "Now Playing"
        }
    }

    var symbol: String {
        switch self {
        case .trendingMovies: return "flame"
        case .trendingShows: return "tv"
        case .popularMovies: return "star"
        case .topRatedMovies: return "trophy"
        case .nowPlayingMovies: return "film"
        }
    }
}

enum DiscoverCatalogPreferencesPolicy {
    static let storageKey = "discover.catalog.enabled_ids"
    static let defaultKinds = Set(DiscoverCatalogKind.allCases)

    static var defaultStorageValue: String {
        encoded(defaultKinds)
    }

    static func enabledKinds(from rawValue: String) -> Set<DiscoverCatalogKind> {
        let ids = rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let kinds = Set(ids.compactMap(DiscoverCatalogKind.init(rawValue:)))
        return kinds.isEmpty ? defaultKinds : kinds
    }

    static func encoded(_ kinds: Set<DiscoverCatalogKind>) -> String {
        DiscoverCatalogKind.allCases
            .filter { kinds.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    static func selection(afterToggling kind: DiscoverCatalogKind, in current: Set<DiscoverCatalogKind>) -> Set<DiscoverCatalogKind> {
        var next = current
        if next.contains(kind) {
            next.remove(kind)
        } else {
            next.insert(kind)
        }
        return next.isEmpty ? current : next
    }
}

enum DiscoverErrorActionPolicy {
    enum RetryBehavior: Equatable {
        case dismissOnly
        case refreshAndDismiss
    }

    static func retryBehavior(isSetupError: Bool) -> RetryBehavior {
        isSetupError ? .dismissOnly : .refreshAndDismiss
    }
}

enum DiscoverLayoutPolicy {
    static let standardBottomContentPadding: CGFloat = 104
    static let bottomTabBarContentPadding: CGFloat = 240

    static func bottomContentPadding(for layout: NavigationLayout) -> CGFloat {
        switch layout {
        case .bottomTabBar:
            bottomTabBarContentPadding
        case .leftSidebar:
            standardBottomContentPadding
        }
    }
}

enum DiscoverSetupSurfacePolicy {
    static let lockedPreviewRowCount = 1

    static func showsSuppressedSetupBackdrop(
        suppressSetupSurface: Bool,
        isSetupError: Bool
    ) -> Bool {
        suppressSetupSurface && isSetupError
    }

    static func showsCatalogControls(
        hasHeroItems: Bool,
        hasContinueWatching: Bool,
        hasCatalogRows: Bool,
        hasAISection: Bool,
        isShowingSuppressedSetupBackdrop: Bool
    ) -> Bool {
        guard !isShowingSuppressedSetupBackdrop else { return false }
        return hasHeroItems || hasContinueWatching || hasCatalogRows || hasAISection
    }
}
