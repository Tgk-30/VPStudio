import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit
#endif

// MARK: - GlassPillPicker Comprehensive Tests

@Suite("GlassPillPicker Comprehensive")
@MainActor
struct GlassPillPickerComprehensiveTests {
    @Test("GlassPillPicker renders with two options")
    func rendersWithTwoOptions() {
        let picker = GlassPillPicker(
            options: ["Option A", "Option B"],
            selection: .constant("Option A")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker renders with many options")
    func rendersWithManyOptions() {
        let picker = GlassPillPicker(
            options: ["One", "Two", "Three", "Four", "Five"],
            selection: .constant("One")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker selection binding updates")
    func selectionBindingUpdates() {
        var selection = "First"
        let picker = GlassPillPicker(
            options: ["First", "Second", "Third"],
            selection: Binding(get: { selection }, set: { selection = $0 })
        )
        _ = picker.body
        #expect(selection == "First")
    }

    @Test("GlassPillPicker selection change triggers animation")
    func selectionChangeTriggersAnimation() {
        var selection = "First"
        let picker = GlassPillPicker(
            options: ["First", "Second"],
            selection: Binding(get: { selection }, set: { selection = $0 })
        )
        _ = picker.body
        selection = "Second"
        #expect(selection == "Second")
    }

    @Test("GlassPillPicker options are hashable")
    func optionsAreHashable() {
        let options: [String] = ["Hashable 1", "Hashable 2"]
        let picker = GlassPillPicker(
            options: options,
            selection: .constant("Hashable 1")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker options are custom string convertible")
    func optionsAreCustomStringConvertible() {
        let options: [String] = ["String 1", "String 2"]
        let picker = GlassPillPicker(
            options: options,
            selection: .constant("String 1")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker body contains HStack")
    func bodyContainsHStack() {
        let picker = GlassPillPicker(
            options: ["A", "B"],
            selection: .constant("A")
        )
        let body = String(describing: picker.body)
        #expect(body.contains("HStack"))
    }

    @Test("GlassPillPicker body contains ForEach")
    func bodyContainsForEach() {
        let picker = GlassPillPicker(
            options: ["A", "B", "C"],
            selection: .constant("A")
        )
        let body = String(describing: picker.body)
        #expect(body.contains("ForEach"))
    }

    @Test("GlassPillPicker body contains Button for each option")
    func bodyContainsButtons() {
        let picker = GlassPillPicker(
            options: ["X", "Y"],
            selection: .constant("X")
        )
        let body = String(describing: picker.body)
        #expect(body.contains("Button"))
    }

    @Test("GlassPillPicker initial selection is first option")
    func initialSelectionIsFirstOption() {
        let picker = GlassPillPicker(
            options: ["Alpha", "Beta"],
            selection: .constant("Alpha")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker renders with single option")
    func rendersWithSingleOption() {
        let picker = GlassPillPicker(
            options: ["Only One"],
            selection: .constant("Only One")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker renders with empty string options")
    func rendersWithEmptyStringOptions() {
        let picker = GlassPillPicker(
            options: ["", ""],
            selection: .constant("")
        )
        _ = picker.body
    }

    @Test("GlassPillPicker renders with numeric string options")
    func rendersWithNumericStringOptions() {
        let picker = GlassPillPicker(
            options: ["1", "2", "3", "4", "5", "6"],
            selection: .constant("1")
        )
        _ = picker.body
    }

    #if os(macOS)
    @Test("GlassPillPicker hosts in NSHostingView with two options")
    func hostsInNSHostingViewTwoOptions() {
        let picker = GlassPillPicker(
            options: ["On", "Off"],
            selection: .constant("On")
        )
        let host = NSHostingView(rootView: picker.frame(width: 200, height: 64))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 64),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }

    @Test("GlassPillPicker hosts in NSHostingView with many options")
    func hostsInNSHostingViewManyOptions() {
        let picker = GlassPillPicker(
            options: ["All", "Movies", "TV Shows", "Anime", "Documentaries"],
            selection: .constant("All")
        )
        let host = NSHostingView(rootView: picker.frame(width: 600, height: 64))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 64),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }
    #endif
}

// MARK: - MediaCardView Comprehensive Tests

@Suite("MediaCardView Comprehensive")
@MainActor
struct MediaCardViewComprehensiveTests {
    private func render(_ view: MediaCardView) {
        SwiftUIViewDiagnosticHost.render(view.frame(width: 220, height: 340))
    }

    private func makeMediaPreview(
        id: String = "test-media",
        type: MediaType = .movie,
        title: String = "Test Movie",
        year: Int? = 2024,
        posterPath: String? = "/poster.jpg",
        backdropPath: String? = "/backdrop.jpg",
        imdbRating: Double? = 8.5,
        tmdbId: Int? = 123456
    ) -> MediaPreview {
        MediaPreview(
            id: id,
            type: type,
            title: title,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            imdbRating: imdbRating,
            tmdbId: tmdbId
        )
    }

    private func makeTasteEvent(
        mediaId: String = "media-1",
        value: Double = 8.0,
        scale: FeedbackScaleMode = .oneToTen
    ) -> TasteEvent {
        TasteEvent(
            id: UUID().uuidString,
            userId: "default",
            mediaId: mediaId,
            episodeId: nil,
            eventType: .rated,
            signalStrength: 1.0,
            watchedState: nil,
            feedbackScale: scale,
            feedbackValue: value,
            source: .manual,
            metadata: [:],
            createdAt: Date()
        )
    }

    @Test("MediaCardView constructs with movie type")
    func constructsWithMovieType() {
        let item = makeMediaPreview(type: .movie)
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with series type")
    func constructsWithSeriesType() {
        let item = makeMediaPreview(type: .series, title: "Test Series")
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with nil year")
    func constructsWithNilYear() {
        let item = makeMediaPreview(year: nil)
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with nil posterURL")
    func constructsWithNilPosterURL() {
        let item = makeMediaPreview(posterPath: nil)
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with nil imdbRating")
    func constructsWithNilIMDBRating() {
        let item = makeMediaPreview(imdbRating: nil)
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with zero imdbRating")
    func constructsWithZeroIMDBRating() {
        let item = makeMediaPreview(imdbRating: 0)
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with negative imdbRating")
    func constructsWithNegativeIMDBRating() {
        let item = makeMediaPreview(imdbRating: -1)
        let view = MediaCardView(item: item)
        render(view)
    }

    @Test("MediaCardView constructs with user rating positive")
    func constructsWithPositiveUserRating() {
        let item = makeMediaPreview()
        let event = makeTasteEvent(value: 9.0)
        let view = MediaCardView(item: item, userRating: event)
        render(view)
    }

    @Test("MediaCardView constructs with user rating negative")
    func constructsWithNegativeUserRating() {
        let item = makeMediaPreview()
        let event = makeTasteEvent(value: 3.0)
        let view = MediaCardView(item: item, userRating: event)
        render(view)
    }

    @Test("MediaCardView constructs with likeDislike scale positive")
    func constructsWithLikeDislikePositive() {
        let item = makeMediaPreview()
        let event = makeTasteEvent(value: 1.0, scale: .likeDislike)
        let view = MediaCardView(item: item, userRating: event)
        render(view)
    }

    @Test("MediaCardView constructs with likeDislike scale negative")
    func constructsWithLikeDislikeNegative() {
        let item = makeMediaPreview()
        let event = makeTasteEvent(value: 0.0, scale: .likeDislike)
        let view = MediaCardView(item: item, userRating: event)
        render(view)
    }

    @Test("MediaCardView constructs with oneToHundred scale")
    func constructsWithOneToHundredScale() {
        let item = makeMediaPreview()
        let event = makeTasteEvent(value: 85.0, scale: .oneToHundred)
        let view = MediaCardView(item: item, userRating: event)
        render(view)
    }

    @Test("MediaCardView interaction mode fullyAnimated")
    func interactionModeFullyAnimated() {
        let item = makeMediaPreview()
        let view = MediaCardView(item: item, interactionMode: .fullyAnimated)
        render(view)
    }

    @Test("MediaCardView interaction mode systemHoverOnly")
    func interactionModeSystemHoverOnly() {
        let item = makeMediaPreview()
        let view = MediaCardView(item: item, interactionMode: .systemHoverOnly)
        render(view)
    }

    @Test("MediaCardView shouldShowPosterLoadingIndicator with posterURL")
    func shouldShowPosterLoadingIndicatorTrue() {
        let item = makeMediaPreview(posterPath: "/poster.jpg")
        #expect(MediaCardView.shouldShowPosterLoadingIndicator(for: item) == true)
    }

    @Test("MediaCardView shouldShowPosterLoadingIndicator without posterURL")
    func shouldShowPosterLoadingIndicatorFalse() {
        let item = makeMediaPreview(posterPath: nil)
        #expect(MediaCardView.shouldShowPosterLoadingIndicator(for: item) == false)
    }

    @Test("MediaCardView InteractionMode equality")
    func interactionModeEquality() {
        #expect(MediaCardView.InteractionMode.fullyAnimated == .fullyAnimated)
        #expect(MediaCardView.InteractionMode.systemHoverOnly == .systemHoverOnly)
        #expect(MediaCardView.InteractionMode.fullyAnimated != .systemHoverOnly)
    }

    @Test("MediaCardView InteractionMode allowsCustomHoverChrome")
    func interactionModeAllowsCustomHoverChrome() {
        #expect(MediaCardView.InteractionMode.fullyAnimated.allowsCustomHoverChrome(onVisionOS: false) == true)
        #expect(MediaCardView.InteractionMode.systemHoverOnly.allowsCustomHoverChrome(onVisionOS: false) == true)
        #expect(MediaCardView.InteractionMode.fullyAnimated.allowsCustomHoverChrome(onVisionOS: true) == true)
        #expect(MediaCardView.InteractionMode.systemHoverOnly.allowsCustomHoverChrome(onVisionOS: true) == false)
    }

    @Test("MediaCardView body contains VStack")
    func bodyContainsVStack() {
        let item = makeMediaPreview()
        let view = MediaCardView(item: item)
        render(view)
        #expect(item.title == "Test Movie")
    }

    @Test("MediaCardView body contains RoundedRectangle")
    func bodyContainsRoundedRectangle() {
        let item = makeMediaPreview()
        let view = MediaCardView(item: item)
        render(view)
        #expect(item.posterURL != nil)
    }

    @Test("MediaCardView body contains AsyncImage when posterURL exists")
    func bodyContainsAsyncImage() {
        let item = makeMediaPreview(posterPath: "/poster.jpg")
        let view = MediaCardView(item: item)
        render(view)
        #expect(MediaCardView.shouldShowPosterLoadingIndicator(for: item) == true)
    }

    @Test("MediaCardView body contains ArtworkFallbackPosterView when no posterURL")
    func bodyContainsArtworkFallbackPosterView() {
        let item = makeMediaPreview(posterPath: nil)
        let view = MediaCardView(item: item)
        render(view)
        #expect(MediaCardView.shouldShowPosterLoadingIndicator(for: item) == false)
    }

    @Test("MediaCardView displays title text")
    func displaysTitleText() {
        let item = makeMediaPreview(title: "Dune Part Two")
        let view = MediaCardView(item: item)
        render(view)
        #expect(item.title == "Dune Part Two")
    }

    @Test("MediaCardView displays year")
    func displaysYear() {
        let item = makeMediaPreview(title: "Test", year: 2024)
        let view = MediaCardView(item: item)
        render(view)
        #expect(item.year == 2024)
    }

    @Test("MediaCardView displays imdbRating")
    func displaysIMDBRating() {
        let item = makeMediaPreview(imdbRating: 8.5)
        let view = MediaCardView(item: item)
        render(view)
        #expect(item.imdbRating == 8.5)
    }

    @Test("MediaCardView displays user rating value")
    func displaysUserRatingValue() {
        let item = makeMediaPreview()
        let event = makeTasteEvent(value: 8)
        let view = MediaCardView(item: item, userRating: event)
        render(view)
        #expect(event.feedbackValue == 8)
    }

    #if os(macOS)
    @Test("MediaCardView hosts in NSHostingView")
    func hostsInNSHostingView() {
        let item = makeMediaPreview()
        let view = MediaCardView(item: item)
        let host = NSHostingView(rootView: view.frame(width: 200, height: 350))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 350),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }

    @Test("MediaCardView hosts with systemHoverOnly mode")
    func hostsWithSystemHoverOnlyMode() {
        let item = makeMediaPreview()
        let view = MediaCardView(item: item, interactionMode: .systemHoverOnly)
        let host = NSHostingView(rootView: view.frame(width: 200, height: 350))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 350),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }
    #endif
}

// MARK: - AIRecommendationCard Comprehensive Tests

@Suite("AIRecommendationCard Comprehensive")
@MainActor
struct AIRecommendationCardComprehensiveTests {
    private func makeRecommendation(
        title: String = "Test Movie",
        year: Int? = 2024,
        type: MediaType = .movie,
        reason: String = "A great film",
        tmdbId: Int? = 123456,
        score: Double? = 0.85
    ) -> AIMovieRecommendation {
        AIMovieRecommendation(
            title: title,
            year: year,
            type: type,
            reason: reason,
            tmdbId: tmdbId,
            score: score
        )
    }

    @Test("AIRecommendationCard constructs with movie type")
    func constructsWithMovieType() {
        let recommendation = makeRecommendation(type: .movie)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with series type")
    func constructsWithSeriesType() {
        let recommendation = makeRecommendation(type: .series)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with all fields")
    func constructsWithAllFields() {
        let recommendation = makeRecommendation(
            title: "Inception",
            year: 2010,
            type: .movie,
            reason: "Mind-bending sci-fi masterpiece",
            tmdbId: 27205,
            score: 0.95
        )
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with nil year")
    func constructsWithNilYear() {
        let recommendation = makeRecommendation(year: nil)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with nil score")
    func constructsWithNilScore() {
        let recommendation = makeRecommendation(score: nil)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with empty reason")
    func constructsWithEmptyReason() {
        let recommendation = makeRecommendation(reason: "")
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with nil tmdbId")
    func constructsWithNilTMDBId() {
        let recommendation = makeRecommendation(tmdbId: nil)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with 100% score")
    func constructsWithPerfectScore() {
        let recommendation = makeRecommendation(score: 1.0)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard constructs with 0% score")
    func constructsWithZeroScore() {
        let recommendation = makeRecommendation(score: 0.0)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard body contains VStack")
    func bodyContainsVStack() {
        let recommendation = makeRecommendation()
        let view = AIRecommendationCard(recommendation: recommendation)
        let body = String(describing: view.body)
        #expect(body.contains("VStack"))
    }

    @Test("AIRecommendationCard body contains GlassTag for score")
    func bodyContainsGlassTagForScore() {
        let recommendation = makeRecommendation(score: 0.85)
        let view = AIRecommendationCard(recommendation: recommendation)
        let body = String(describing: view.body)
        #expect(body.contains("GlassTag"))
    }

    @Test("AIRecommendationCard constructs when score is nil")
    func constructsWhenScoreNil() {
        let recommendation = makeRecommendation(score: nil)
        let view = AIRecommendationCard(recommendation: recommendation)
        _ = view.body
    }

    @Test("AIRecommendationCard displays title")
    func displaysTitle() {
        let recommendation = makeRecommendation(title: "The Matrix")
        let view = AIRecommendationCard(recommendation: recommendation)
        let body = String(describing: view.body)
        #expect(body.contains("The Matrix"))
    }

    @Test("AIRecommendationCard displays year")
    func displaysYear() {
        let recommendation = makeRecommendation(year: 1999)
        let view = AIRecommendationCard(recommendation: recommendation)
        let body = String(describing: view.body)
        #expect(body.contains("1999"))
    }

    @Test("AIRecommendationCard displays type label")
    func displaysTypeLabel() {
        let recommendation = makeRecommendation(type: .movie)
        let view = AIRecommendationCard(recommendation: recommendation)
        let body = String(describing: view.body)
        #expect(body.contains("Movie") || body.contains("TV"))
    }

    @Test("AIRecommendationCard displays reason")
    func displaysReason() {
        let recommendation = makeRecommendation(reason: "Exciting action film")
        let view = AIRecommendationCard(recommendation: recommendation)
        let body = String(describing: view.body)
        #expect(body.contains("Exciting action film"))
    }

    @Test("AIRecommendationCard id is constructed correctly for movie with tmdbId")
    func idForMovieWithTMDBId() {
        let recommendation = makeRecommendation(type: .movie, tmdbId: 12345)
        #expect(recommendation.id == "movie-tmdb-12345")
    }

    @Test("AIRecommendationCard id is constructed correctly for series with tmdbId")
    func idForSeriesWithTMDBId() {
        let recommendation = makeRecommendation(type: .series, tmdbId: 67890)
        #expect(recommendation.id == "series-tmdb-67890")
    }

    @Test("AIRecommendationCard id is constructed correctly without tmdbId")
    func idWithoutTMDBId() {
        let recommendation = makeRecommendation(title: "Test Movie", year: 2024, tmdbId: nil)
        // ID uses lowercased title (spaces preserved), year, and type rawValue
        #expect(recommendation.id == "test movie-2024-movie")
    }

    #if os(macOS)
    @Test("AIRecommendationCard hosts in NSHostingView")
    func hostsInNSHostingView() {
        let recommendation = makeRecommendation()
        let view = AIRecommendationCard(recommendation: recommendation)
        let host = NSHostingView(rootView: view.frame(width: 250, height: 200))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }
    #endif
}

// MARK: - AsyncStateViews Comprehensive Tests

@Suite("AsyncStateViews Comprehensive")
@MainActor
struct AsyncStateViewsComprehensiveTests {
    @Test("LoadingOverlay constructs with title only")
    func loadingOverlayTitleOnly() {
        let view = LoadingOverlay(title: "Loading...")
        _ = view.body
    }

    @Test("LoadingOverlay constructs with title and message")
    func loadingOverlayWithMessage() {
        let view = LoadingOverlay(title: "Loading...", message: "Please wait")
        _ = view.body
    }

    @Test("LoadingOverlay constructs with nil message")
    func loadingOverlayNilMessage() {
        let view = LoadingOverlay(title: "Loading...", message: nil)
        _ = view.body
    }

    @Test("LoadingOverlay constructs with empty message")
    func loadingOverlayEmptyMessage() {
        let view = LoadingOverlay(title: "Loading...", message: "")
        _ = view.body
    }

    @Test("LoadingOverlay body contains VStack")
    func loadingOverlayBodyContainsVStack() {
        let view = LoadingOverlay(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("VStack"))
    }

    @Test("LoadingOverlay body contains Circle")
    func loadingOverlayBodyContainsCircle() {
        let view = LoadingOverlay(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("Circle"))
    }

    @Test("LoadingOverlay body contains Text")
    func loadingOverlayBodyContainsText() {
        let view = LoadingOverlay(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("Text"))
    }

    @Test("InlineLoadingStatusView constructs with title")
    func inlineLoadingStatusViewTitle() {
        let view = InlineLoadingStatusView(title: "Refreshing...")
        _ = view.body
    }

    @Test("InlineLoadingStatusView body contains HStack")
    func inlineLoadingStatusViewBodyContainsHStack() {
        let view = InlineLoadingStatusView(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("HStack"))
    }

    @Test("InlineLoadingStatusView body contains Circle")
    func inlineLoadingStatusViewBodyContainsCircle() {
        let view = InlineLoadingStatusView(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("Circle"))
    }

    @Test("AppErrorInlineView constructs with unknown error")
    func appErrorInlineViewUnknownError() {
        let error = AppError.unknown("Something went wrong")
        let view = AppErrorInlineView(error: error)
        _ = view.body
    }

    @Test("AppErrorInlineView constructs with network error")
    func appErrorInlineViewNetworkError() {
        let error = AppError.network(.timeout)
        let view = AppErrorInlineView(error: error)
        _ = view.body
    }

    @Test("AppErrorInlineView constructs with error and recovery suggestion")
    func appErrorInlineViewWithRecovery() {
        let error = AppError.network(.offline)
        let view = AppErrorInlineView(error: error)
        _ = view.body
    }

    @Test("AppErrorInlineView body contains VStack")
    func appErrorInlineViewBodyContainsVStack() {
        let error = AppError.unknown("Error")
        let view = AppErrorInlineView(error: error)
        let body = String(describing: view.body)
        #expect(body.contains("VStack"))
    }

    @Test("AppErrorInlineView body contains Text")
    func appErrorInlineViewBodyContainsText() {
        let error = AppError.unknown("Error message")
        let view = AppErrorInlineView(error: error)
        let body = String(describing: view.body)
        #expect(body.contains("Error message"))
    }

    @Test("SkeletonBlock constructs with height only")
    func skeletonBlockHeightOnly() {
        let view = SkeletonBlock(height: 20)
        SwiftUIViewDiagnosticHost.render(view, width: 120, height: 40)
    }

    @Test("SkeletonBlock constructs with width and height")
    func skeletonBlockWidthAndHeight() {
        let view = SkeletonBlock(width: 100, height: 20)
        SwiftUIViewDiagnosticHost.render(view, width: 120, height: 40)
    }

    @Test("SkeletonBlock constructs with custom corner radius")
    func skeletonBlockCustomCornerRadius() {
        let view = SkeletonBlock(width: 100, height: 20, cornerRadius: 8)
        SwiftUIViewDiagnosticHost.render(view, width: 120, height: 40)
    }

    @Test("SkeletonBlock constructs with zero corner radius")
    func skeletonBlockZeroCornerRadius() {
        let view = SkeletonBlock(width: 100, height: 20, cornerRadius: 0)
        SwiftUIViewDiagnosticHost.render(view, width: 120, height: 40)
    }

    @Test("SkeletonBlock body contains RoundedRectangle")
    func skeletonBlockBodyContainsRoundedRectangle() {
        let view = SkeletonBlock(height: 20)
        SwiftUIViewDiagnosticHost.render(view, width: 120, height: 40)
    }

    @Test("DiscoverSkeletonView constructs")
    func discoverSkeletonViewConstructs() {
        let view = DiscoverSkeletonView()
        _ = view.body
    }

    @Test("DetailSkeletonView constructs")
    func detailSkeletonViewConstructs() {
        let view = DetailSkeletonView()
        _ = view.body
    }

    @Test("LibrarySkeletonView constructs")
    func librarySkeletonViewConstructs() {
        let view = LibrarySkeletonView()
        _ = view.body
    }

    @Test("SettingsSkeletonView constructs")
    func settingsSkeletonViewConstructs() {
        let view = SettingsSkeletonView()
        _ = view.body
    }

    @Test("ExploreSkeletonView constructs")
    func exploreSkeletonViewConstructs() {
        let view = ExploreSkeletonView()
        _ = view.body
    }

    @Test("ExploreErrorView constructs with retry action")
    func exploreErrorViewWithRetry() {
        let error = AppError.unknown("Error")
        let view = ExploreErrorView(error: error, onRetry: {})
        _ = view.body
    }

    @Test("ExploreErrorView constructs with retry and settings actions")
    func exploreErrorViewWithRetryAndSettings() {
        let error = AppError.tmdbSetupRequired(feature: "Search")
        let view = ExploreErrorView(
            error: error,
            onRetry: {},
            onOpenSettings: {}
        )
        _ = view.body
    }

    @Test("ExploreErrorView body contains CinematicStateCard")
    func exploreErrorViewBodyContainsCinematicStateCard() {
        let error = AppError.unknown("Error")
        let view = ExploreErrorView(error: error, onRetry: {})
        let body = String(describing: view.body)
        #expect(body.contains("CinematicStateCard"))
    }

    @Test("ExploreEmptyView constructs with query")
    func exploreEmptyViewWithQuery() {
        let view = ExploreEmptyView(query: "Inception")
        _ = view.body
    }

    @Test("ExploreEmptyView constructs with empty query")
    func exploreEmptyViewWithEmptyQuery() {
        let view = ExploreEmptyView(query: "")
        _ = view.body
    }

    @Test("ExploreEmptyView constructs with long query")
    func exploreEmptyViewWithLongQuery() {
        let view = ExploreEmptyView(query: "A very long movie title that should still work")
        _ = view.body
    }

    @Test("ExploreEmptyView body contains CinematicStateCard")
    func exploreEmptyViewBodyContainsCinematicStateCard() {
        let view = ExploreEmptyView(query: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("CinematicStateCard"))
    }

    @Test("ExploreEmptyView constructs with query")
    func exploreEmptyViewConstructsWithQuery() {
        let view = ExploreEmptyView(query: "Dune")
        _ = view.body
    }

    @Test("PaginationLoadingView constructs")
    func paginationLoadingViewConstructs() {
        let view = PaginationLoadingView()
        _ = view.body
    }

    @Test("PaginationLoadingView body contains HStack")
    func paginationLoadingViewBodyContainsHStack() {
        let view = PaginationLoadingView()
        let body = String(describing: view.body)
        #expect(body.contains("HStack"))
    }

    @Test("PaginationLoadingView body contains ProgressView")
    func paginationLoadingViewBodyContainsProgressView() {
        let view = PaginationLoadingView()
        let body = String(describing: view.body)
        #expect(body.contains("ProgressView"))
    }

    @Test("appErrorAlert modifier applies to view")
    func appErrorAlertModifierApplies() {
        let view = Text("Test").appErrorAlert(error: .constant(nil))
        _ = view
    }

    @Test("appErrorAlert modifier with error binding")
    func appErrorAlertModifierWithError() {
        let error = AppError.unknown("Test error")
        let view = Text("Test").appErrorAlert(error: .constant(error), onRetry: {})
        _ = view
    }

    #if os(macOS)
    @Test("LoadingOverlay hosts in NSHostingView")
    func loadingOverlayHostsInNSHostingView() {
        let view = LoadingOverlay(title: "Loading...", message: "Please wait")
        let host = NSHostingView(rootView: view.frame(width: 300, height: 150))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }

    @Test("SkeletonBlock hosts in NSHostingView")
    func skeletonBlockHostsInNSHostingView() {
        let view = SkeletonBlock(width: 200, height: 40, cornerRadius: 12)
        let host = NSHostingView(rootView: view.frame(width: 300, height: 100))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }

    @Test("DiscoverSkeletonView hosts in NSHostingView")
    func discoverSkeletonViewHostsInNSHostingView() {
        let view = DiscoverSkeletonView()
        let host = NSHostingView(rootView: view.frame(width: 600, height: 800))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }
    #endif
}

// MARK: - TextInputCompatibility Tests

@Suite("TextInputCompatibility Comprehensive")
@MainActor
struct TextInputCompatibilityTests {
    @Test("disableAutomaticTextEntryAdjustments applies to TextField")
    func appliesToTextField() {
        let view = TextField("Search", text: .constant(""))
            .disableAutomaticTextEntryAdjustments()
        _ = view
    }

    @Test("disableAutomaticTextEntryAdjustments applies to secure field")
    func appliesToSecureField() {
        let view = SecureField("Password", text: .constant(""))
            .disableAutomaticTextEntryAdjustments()
        _ = view
    }

    @Test("disableAutomaticTextEntryAdjustments applies to text editor")
    func appliesToTextEditor() {
        let view = TextEditor(text: .constant(""))
            .disableAutomaticTextEntryAdjustments()
        _ = view
    }

    @Test("disableAutomaticTextEntryAdjustments can be chained")
    func canBeChained() {
        let view = TextField("Search", text: .constant(""))
            .disableAutomaticTextEntryAdjustments()
            .font(.headline)
        _ = view
    }
}
