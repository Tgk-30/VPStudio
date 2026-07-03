import Foundation
import Testing
@testable import VPStudio

@Suite("FeedbackScaleMode FromStoredValue Tests")
struct FeedbackScaleModeFromStoredValueTests {

    @Test("fromStoredValue returns likeDislike for nil")
    func fromStoredValueNil() {
        #expect(FeedbackScaleMode.fromStoredValue(nil) == .likeDislike)
    }

    @Test("fromStoredValue returns likeDislike for empty string")
    func fromStoredValueEmpty() {
        #expect(FeedbackScaleMode.fromStoredValue("") == .likeDislike)
    }

    @Test("fromStoredValue returns canonical mode for valid values")
    func fromStoredValueValid() {
        #expect(FeedbackScaleMode.fromStoredValue("like_dislike") == .likeDislike)
        #expect(FeedbackScaleMode.fromStoredValue("one_to_ten") == .oneToTen)
        #expect(FeedbackScaleMode.fromStoredValue("one_to_hundred") == .oneToHundred)
    }

    @Test("fromStoredValue converts legacy fiveStar to oneToTen")
    func fromStoredValueLegacyFiveStar() {
        #expect(FeedbackScaleMode.fromStoredValue("five_star") == .oneToTen)
    }

    @Test("fromStoredValue converts legacy tenPoint to oneToTen")
    func fromStoredValueLegacyTenPoint() {
        #expect(FeedbackScaleMode.fromStoredValue("ten_point") == .oneToTen)
    }
}

@Suite("FeedbackScaleMode Canonical Mode Tests")
struct FeedbackScaleModeCanonicalTests {

    @Test("canonicalMode returns self for current modes")
    func canonicalModeSelf() {
        #expect(FeedbackScaleMode.likeDislike.canonicalMode == .likeDislike)
        #expect(FeedbackScaleMode.oneToTen.canonicalMode == .oneToTen)
        #expect(FeedbackScaleMode.oneToHundred.canonicalMode == .oneToHundred)
    }

    @Test("canonicalMode converts fiveStar to oneToTen")
    func canonicalModeFiveStar() {
        #expect(FeedbackScaleMode.fiveStar.canonicalMode == .oneToTen)
    }

    @Test("canonicalMode converts tenPoint to oneToTen")
    func canonicalModeTenPoint() {
        #expect(FeedbackScaleMode.tenPoint.canonicalMode == .oneToTen)
    }
}

@Suite("FeedbackScaleMode Display Name Tests")
struct FeedbackScaleModeDisplayNameTests {

    @Test("displayName for current modes")
    func displayNameCurrentModes() {
        #expect(FeedbackScaleMode.likeDislike.displayName == "Like / Dislike")
        #expect(FeedbackScaleMode.oneToTen.displayName == "1-10")
        #expect(FeedbackScaleMode.oneToHundred.displayName == "1-100")
    }

    @Test("displayName for legacy modes uses canonical")
    func displayNameLegacyModes() {
        #expect(FeedbackScaleMode.fiveStar.displayName == "1-10")
        #expect(FeedbackScaleMode.tenPoint.displayName == "1-10")
    }
}

@Suite("FeedbackScaleMode Minimum Value Tests")
struct FeedbackScaleModeMinimumValueTests {

    @Test("minimumValue for current modes")
    func minimumValueCurrentModes() {
        #expect(FeedbackScaleMode.likeDislike.minimumValue == 0)
        #expect(FeedbackScaleMode.oneToTen.minimumValue == 1)
        #expect(FeedbackScaleMode.oneToHundred.minimumValue == 1)
    }

    @Test("minimumValue for legacy modes")
    func minimumValueLegacyModes() {
        #expect(FeedbackScaleMode.fiveStar.minimumValue == 1)
        #expect(FeedbackScaleMode.tenPoint.minimumValue == 1)
    }
}

@Suite("FeedbackScaleMode Maximum Value Tests")
struct FeedbackScaleModeMaximumValueTests {

    @Test("maximumValue for current modes")
    func maximumValueCurrentModes() {
        #expect(FeedbackScaleMode.likeDislike.maximumValue == 1)
        #expect(FeedbackScaleMode.oneToTen.maximumValue == 10)
        #expect(FeedbackScaleMode.oneToHundred.maximumValue == 100)
    }

    @Test("maximumValue for legacy modes")
    func maximumValueLegacyModes() {
        #expect(FeedbackScaleMode.fiveStar.maximumValue == 10)
        #expect(FeedbackScaleMode.tenPoint.maximumValue == 10)
    }
}

@Suite("FeedbackScaleMode Clamp Tests")
struct FeedbackScaleModeClampTests {

    @Test("clamp within range returns same value")
    func clampWithinRange() {
        #expect(FeedbackScaleMode.oneToTen.clamp(5.0) == 5.0)
        #expect(FeedbackScaleMode.likeDislike.clamp(0.5) == 0.5)
    }

    @Test("clamp below minimum returns minimum")
    func clampBelowMinimum() {
        #expect(FeedbackScaleMode.oneToTen.clamp(0.0) == 1.0)
        #expect(FeedbackScaleMode.oneToHundred.clamp(0) == 1)
    }

    @Test("clamp above maximum returns maximum")
    func clampAboveMaximum() {
        #expect(FeedbackScaleMode.oneToTen.clamp(15.0) == 10.0)
        #expect(FeedbackScaleMode.oneToHundred.clamp(150) == 100)
    }

    @Test("clamp for likeDislike preserves values in range")
    func clampLikeDislike() {
        #expect(FeedbackScaleMode.likeDislike.clamp(0.0) == 0.0)
        #expect(FeedbackScaleMode.likeDislike.clamp(0.4) == 0.4)
        #expect(FeedbackScaleMode.likeDislike.clamp(0.5) == 0.5)
        #expect(FeedbackScaleMode.likeDislike.clamp(1.0) == 1.0)
    }
}

@Suite("FeedbackScaleMode Normalized Value Tests")
struct FeedbackScaleModeNormalizedValueTests {

    @Test("normalizedValue for likeDislike")
    func normalizedValueLikeDislike() {
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(0.0) == 0.0)
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(0.4) == 0.0)
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(0.5) == 1.0)
        #expect(FeedbackScaleMode.likeDislike.normalizedValue(1.0) == 1.0)
    }

    @Test("selectableCases excludes legacy cases")
    func selectableCasesExcludesLegacy() {
        let selectable = FeedbackScaleMode.selectableCases
        #expect(selectable.count == 3)
        #expect(selectable.contains(.likeDislike))
        #expect(selectable.contains(.oneToTen))
        #expect(selectable.contains(.oneToHundred))
        #expect(!selectable.contains(.fiveStar))
        #expect(!selectable.contains(.tenPoint))
    }
}
