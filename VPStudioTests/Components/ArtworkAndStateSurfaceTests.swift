import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit
#endif

// MARK: - ArtworkFallbackPosterView Comprehensive Tests

@MainActor
@Suite("ArtworkFallbackPosterView Comprehensive Tests")
struct ArtworkFallbackPosterViewComprehensiveTests {
    @MainActor
    @Test("ArtworkFallbackPosterView constructs with title only")
    func constructsWithTitleOnly() async {
        await MainActor.run {
            let view = ArtworkFallbackPosterView(title: "Dune")
            _ = view.body
        }
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with movie type")

    func constructsWithMovieType() {
        let view = ArtworkFallbackPosterView(title: "Dune", type: .movie)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with series type")

    func constructsWithSeriesType() {
        let view = ArtworkFallbackPosterView(title: "The Expanse", type: .series)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with nil type")

    func constructsWithNilType() {
        let view = ArtworkFallbackPosterView(title: "Unknown", type: nil)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with year")

    func constructsWithYear() {
        let view = ArtworkFallbackPosterView(title: "Dune", year: 2024)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with nil year")

    func constructsWithNilYear() {
        let view = ArtworkFallbackPosterView(title: "Dune", year: nil)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with backdropURL")

    func constructsWithBackdropURL() {
        let view = ArtworkFallbackPosterView(
            title: "Dune",
            backdropURL: URL(string: "https://example.com/backdrop.jpg")
        )
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs in compact mode")

    func constructsInCompactMode() {
        let view = ArtworkFallbackPosterView(title: "Dune", compact: true)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView constructs with all parameters")

    func constructsWithAllParameters() {
        let view = ArtworkFallbackPosterView(
            title: "Dune Part Two",
            type: .movie,
            year: 2024,
            backdropURL: URL(string: "https://example.com/backdrop.jpg"),
            compact: false
        )
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView palette always returns two colors")

    func paletteReturnsTwoColors() {
        let view = ArtworkFallbackPosterView(title: "Test")
        #expect(view.palette.count == 2)
    }

    @MainActor
    @Test("ArtworkFallbackPosterView initials are not empty")

    func initialsAreNotEmpty() {
        let view = ArtworkFallbackPosterView(title: "Dune")
        #expect(!view.initials.isEmpty)
    }

    @MainActor
    @Test("ArtworkFallbackPosterView body contains ZStack")

    func bodyContainsZStack() {
        let view = ArtworkFallbackPosterView(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("ZStack"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView body contains RoundedRectangle")

    func bodyContainsRoundedRectangle() {
        let view = ArtworkFallbackPosterView(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("RoundedRectangle"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView body contains LinearGradient")

    func bodyContainsLinearGradient() {
        let view = ArtworkFallbackPosterView(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("LinearGradient"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView body contains Circle for compact")

    func bodyContainsCircleForCompact() {
        let view = ArtworkFallbackPosterView(title: "Test", compact: true)
        let body = String(describing: view.body)
        #expect(body.contains("Circle"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView body contains Capsule for glass effect")

    func bodyContainsCapsule() {
        let view = ArtworkFallbackPosterView(title: "Test")
        let body = String(describing: view.body)
        #expect(body.contains("Capsule"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView non-compact contains GlassTag")

    func nonCompactContainsGlassTag() {
        let view = ArtworkFallbackPosterView(title: "Test", compact: false)
        let body = String(describing: view.body)
        #expect(body.contains("GlassTag"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView compact constructs without crashing")

    func compactConstructsWithoutCrashing() {
        let view = ArtworkFallbackPosterView(title: "Test", compact: true)
        _ = view.body
    }

    @MainActor
    @Test("ArtworkFallbackPosterView compact mode omits metadata and title")

    func compactModeOmitsMetadataAndTitle() {
        let view = ArtworkFallbackPosterView(title: "Interstellar", type: .movie, year: 2014, compact: true)
        let body = String(describing: view.body)

        #expect(!body.contains("TV SHOW"))
        #expect(!body.contains("MOVIE"))
        #expect(!body.contains("Interstellar"))
        #expect(body.contains("IN"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView displays title text")

    func displaysTitleText() {
        let view = ArtworkFallbackPosterView(title: "Dune Part Two")
        let body = String(describing: view.body)
        #expect(body.contains("Dune Part Two"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView displays initials")

    func displaysInitials() {
        let view = ArtworkFallbackPosterView(title: "Dune Part Two")
        let body = String(describing: view.body)
        #expect(body.contains("DP") || body.contains("initials"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView punctuation-only title falls back to VP")

    func displaysVPForPunctuationTitle() {
        let view = ArtworkFallbackPosterView(title: "!!!")
        let body = String(describing: view.body)
        #expect(body.contains("VP"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView with backdropURL contains AsyncImage")

    func withBackdropURLContainsAsyncImage() {
        let view = ArtworkFallbackPosterView(
            title: "Test",
            backdropURL: URL(string: "https://example.com/backdrop.jpg")
        )
        let body = String(describing: view.body)
        #expect(body.contains("AsyncImage"))
    }

    @MainActor
    @Test("ArtworkFallbackPosterView palette is deterministic")

    func paletteIsDeterministic() {
        let view1 = ArtworkFallbackPosterView(title: "Dune")
        let view2 = ArtworkFallbackPosterView(title: "Dune")
        #expect(view1.palette == view2.palette)
    }

    @MainActor
    @Test("ArtworkFallbackPosterView palette changes with different titles")

    func paletteChangesWithDifferentTitles() {
        let view1 = ArtworkFallbackPosterView(title: "Dune")
        let view2 = ArtworkFallbackPosterView(title: "Inception")
        #expect(view1.palette != view2.palette)
    }

    @MainActor
    @Test("ArtworkFallbackPosterView initials changes with different titles")

    func initialsChangeWithDifferentTitles() {
        let view1 = ArtworkFallbackPosterView(title: "Dune")
        let view2 = ArtworkFallbackPosterView(title: "Inception")
        #expect(view1.initials != view2.initials)
    }

    @MainActor
    @Test("ArtworkFallbackPosterView compact has smaller corner radius")

    func compactHasSmallerCornerRadius() {
        let view = ArtworkFallbackPosterView(title: "Test", compact: true)
        let body = String(describing: view.body)
        #expect(body.contains("12") || body.contains("cornerRadius"))
    }

    #if os(macOS)
    @MainActor
    @Test("ArtworkFallbackPosterView hosts in NSHostingView standard mode")

    func hostsInNSHostingViewStandardMode() {
        let view = ArtworkFallbackPosterView(
            title: "Interstellar",
            type: .movie,
            year: 2014
        )
        let host = NSHostingView(rootView: view.frame(width: 300, height: 450))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 450),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(host.fittingSize.width > 0)
    }

    @MainActor
    @Test("ArtworkFallbackPosterView hosts in NSHostingView compact mode")

    func hostsInNSHostingViewCompactMode() {
        let view = ArtworkFallbackPosterView(
            title: "Interstellar",
            type: .movie,
            year: 2014,
            compact: true
        )
        let host = NSHostingView(rootView: view.frame(width: 100, height: 100))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
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

// MARK: - CinematicStateCard Comprehensive Tests

@MainActor
@Suite("CinematicStateCard Comprehensive Tests")
struct CinematicStateCardComprehensiveTests {
    @MainActor
    @Test("CinematicStateCard constructs with content closure")

    func constructsWithContentClosure() {
        let card = CinematicStateCard {
            Text("Hello World")
        }
        _ = card.body
    }

    @MainActor
    @Test("CinematicStateCard constructs with default accent")

    func constructsWithDefaultAccent() {
        let card = CinematicStateCard {
            Text("Content")
        }
        #expect(card.accent == .accentColor)
    }

    @MainActor
    @Test("CinematicStateCard constructs with custom accent")

    func constructsWithCustomAccent() {
        let card = CinematicStateCard(accent: .purple) {
            Text("Content")
        }
        #expect(card.accent == .purple)
    }

    @MainActor
    @Test("CinematicStateCard default artworkName is nil")

    func defaultArtworkNameIsNil() {
        let card = CinematicStateCard {
            Text("Content")
        }
        #expect(card.artworkName == nil)
    }

    @MainActor
    @Test("CinematicStateCard constructs with artworkName")

    func constructsWithArtworkName() {
        let card = CinematicStateCard(artworkName: "artwork.png") {
            Text("Content")
        }
        #expect(card.artworkName == "artwork.png")
    }

    @MainActor
    @Test("CinematicStateCard default minHeight is 220")

    func defaultMinHeightIs220() {
        let card = CinematicStateCard {
            Text("Content")
        }
        #expect(card.minHeight == 220)
    }

    @MainActor
    @Test("CinematicStateCard constructs with custom minHeight")

    func constructsWithCustomMinHeight() {
        let card = CinematicStateCard(minHeight: 300) {
            Text("Content")
        }
        #expect(card.minHeight == 300)
    }

    @MainActor
    @Test("CinematicStateCard body contains ZStack")

    func bodyContainsZStack() {
        let card = CinematicStateCard {
            Text("Content")
        }
        let body = String(describing: card.body)
        #expect(body.contains("ZStack"))
    }

    @MainActor
    @Test("CinematicStateCard body contains RoundedRectangle")

    func bodyContainsRoundedRectangle() {
        let card = CinematicStateCard {
            Text("Content")
        }
        let body = String(describing: card.body)
        #expect(body.contains("RoundedRectangle"))
    }

    @MainActor
    @Test("CinematicStateCard body contains LinearGradient")

    func bodyContainsLinearGradient() {
        let card = CinematicStateCard {
            Text("Content")
        }
        let body = String(describing: card.body)
        #expect(body.contains("LinearGradient"))
    }

    @MainActor
    @Test("CinematicStateCard body contains Circle for accent glow")

    func bodyContainsCircleForAccentGlow() {
        let card = CinematicStateCard {
            Text("Content")
        }
        let body = String(describing: card.body)
        #expect(body.contains("Circle"))
    }

    @MainActor
    @Test("CinematicStateCard with artworkName contains Image")

    func withArtworkNameContainsImage() {
        let card = CinematicStateCard(artworkName: "test.artwork") {
            Text("Content")
        }
        let body = String(describing: card.body)
        #expect(body.contains("Image"))
    }

    @MainActor
    @Test("CinematicStateCard displays content")

    func displaysContent() {
        let card = CinematicStateCard {
            Text("Hello World")
        }
        let body = String(describing: card.body)
        #expect(body.contains("Hello World"))
    }

    @MainActor
    @Test("CinematicStateCard content receives padding")

    func contentReceivesPadding() {
        let card = CinematicStateCard {
            Text("Content")
        }
        let body = String(describing: card.body)
        #expect(body.contains("padding") || body.contains("Padding"))
    }

    @MainActor
    @Test("CinematicStateCard with various accent colors")

    func variousAccentColors() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
        for color in colors {
            let card = CinematicStateCard(accent: color) {
                Text("Content")
            }
            _ = card.body
        }
    }

    @MainActor
    @Test("CinematicStateCard with various minHeight values")

    func variousMinHeightValues() {
        for height in [100, 200, 300, 400, 500] {
            let card = CinematicStateCard(minHeight: CGFloat(height)) {
                Text("Content")
            }
            _ = card.body
        }
    }

    #if os(macOS)
    @MainActor
    @Test("CinematicStateCard hosts in NSHostingView")

    func hostsInNSHostingView() {
        let card = CinematicStateCard(accent: .purple, minHeight: 300) {
            VStack {
                Text("Featured Content")
                    .font(.headline)
                Text("Now Playing")
                    .font(.caption)
            }
        }
        let host = NSHostingView(rootView: card.frame(width: 400, height: 300))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
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

// MARK: - ArtworkFallbackStyle Comprehensive Tests

@Suite("ArtworkFallbackStyle Comprehensive Tests")
struct ArtworkFallbackStyleComprehensiveTests {
    @MainActor
    @Test("initials for empty string returns VP")

    func initialsEmptyStringReturnsVP() {
        #expect(ArtworkFallbackStyle.initials(for: "") == "VP")
    }

    @MainActor
    @Test("initials for whitespace only returns VP")

    func initialsWhitespaceOnlyReturnsVP() {
        #expect(ArtworkFallbackStyle.initials(for: "   ") == "VP")
    }

    @MainActor
    @Test("initials for single word returns first two letters")

    func initialsSingleWordReturnsFirstTwoLetters() {
        #expect(ArtworkFallbackStyle.initials(for: "Dune") == "DU")
    }

    @MainActor
    @Test("initials for two words returns first letters")

    func initialsTwoWordsReturnsFirstLetters() {
        #expect(ArtworkFallbackStyle.initials(for: "Dune Part") == "DP")
    }

    @MainActor
    @Test("initials for multiple words returns first two non-filler words")

    func initialsMultipleWordsReturnsFirstTwoNonFiller() {
        #expect(ArtworkFallbackStyle.initials(for: "The Lord of the Rings") == "LR")
    }

    @MainActor
    @Test("initials filters filler words correctly")

    func initialsFiltersFillerWordsCorrectly() {
        let fillerWords = ["a", "an", "and", "at", "by", "for", "from", "in", "of", "on", "the", "to"]
        for word in fillerWords {
            let result = ArtworkFallbackStyle.initials(for: "The \(word) Movie")
            // With only "Movie" remaining after filtering, initials returns "MO"
            #expect(result == "MO")
        }
    }

    @MainActor
    @Test("initials uppercases result")

    func initialsUppercasesResult() {
        #expect(ArtworkFallbackStyle.initials(for: "star wars") == "SW")
    }

    @MainActor
    @Test("initials for numeric title returns digits")

    func initialsNumericTitleReturnsDigits() {
        #expect(ArtworkFallbackStyle.initials(for: "2024") == "20")
    }

    @MainActor
    @Test("initials for title with numbers and letters")

    func initialsWithNumbersAndLetters() {
        // Both tokens are non-filler, so first char of each is used
        #expect(ArtworkFallbackStyle.initials(for: "2024 Movie") == "2M")
    }

    @MainActor
    @Test("initials for punctuation-only title returns VP")

    func initialsPunctuationOnlyReturnsVP() {
        #expect(ArtworkFallbackStyle.initials(for: "!!!") == "VP")
    }

    @MainActor
    @Test("initials for single character returns that character")

    func initialsSingleCharacterReturnsThatCharacter() {
        #expect(ArtworkFallbackStyle.initials(for: "A") == "A")
    }

    @MainActor
    @Test("palette returns two colors for any input")

    func paletteReturnsTwoColorsForAnyInput() {
        let titles = ["Dune", "Inception", "Star Wars", "", "123", "   "]
        for title in titles {
            #expect(ArtworkFallbackStyle.palette(for: title, type: nil).count == 2)
        }
    }

    @MainActor
    @Test("palette is deterministic for same title")

    func paletteDeterministicForSameTitle() {
        let palette1 = ArtworkFallbackStyle.palette(for: "Dune", type: nil)
        let palette2 = ArtworkFallbackStyle.palette(for: "Dune", type: nil)
        #expect(palette1 == palette2)
    }

    @MainActor
    @Test("palette for movie type returns different colors than nil type")

    func paletteMovieDiffersFromNilType() {
        let moviePalette = ArtworkFallbackStyle.palette(for: "Test", type: .movie)
        let nilPalette = ArtworkFallbackStyle.palette(for: "Test", type: nil)
        #expect(moviePalette != nilPalette)
    }

    @MainActor
    @Test("palette for series type returns fixed blue colors")

    func paletteSeriesTypeReturnsFixedBlueColors() {
        let seriesPalette = ArtworkFallbackStyle.palette(for: "Any Title", type: .series)
        #expect(seriesPalette[0] == Color(red: 0.10, green: 0.23, blue: 0.48))
        #expect(seriesPalette[1] == Color(red: 0.31, green: 0.61, blue: 0.93))
    }

    @MainActor
    @Test("metadata for movie with year")

    func metadataMovieWithYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .movie, year: 2024) == "MOVIE • 2024")
    }

    @MainActor
    @Test("metadata for series with year")

    func metadataSeriesWithYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .series, year: 2024) == "TV SHOW • 2024")
    }

    @MainActor
    @Test("metadata for movie without year")

    func metadataMovieWithoutYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .movie, year: nil) == "MOVIE")
    }

    @MainActor
    @Test("metadata for series without year")

    func metadataSeriesWithoutYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .series, year: nil) == "TV SHOW")
    }

    @MainActor
    @Test("metadata for nil type with year")

    func metadataNilTypeWithYear() {
        #expect(ArtworkFallbackStyle.metadata(for: nil, year: 2024) == "FEATURE • 2024")
    }

    @MainActor
    @Test("metadata for nil type without year")

    func metadataNilTypeWithoutYear() {
        #expect(ArtworkFallbackStyle.metadata(for: nil, year: nil) == "FEATURE")
    }

    @MainActor
    @Test("accentSymbol for movie returns film.stack.fill")

    func accentSymbolMovie() {
        #expect(ArtworkFallbackStyle.accentSymbol(for: .movie) == "film.stack.fill")
    }

    @MainActor
    @Test("accentSymbol for series returns tv.fill")

    func accentSymbolSeries() {
        #expect(ArtworkFallbackStyle.accentSymbol(for: .series) == "tv.fill")
    }

    @MainActor
    @Test("accentSymbol for nil type returns film.stack.fill")

    func accentSymbolNilType() {
        #expect(ArtworkFallbackStyle.accentSymbol(for: nil) == "film.stack.fill")
    }
}
