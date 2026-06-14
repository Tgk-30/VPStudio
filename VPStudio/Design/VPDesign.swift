import SwiftUI

// MARK: - Feature Flag

/// Gate for the "Obsidian Glass" design system. Migrated screens branch on this so the
/// revamp can roll out screen-by-screen with a safe fallback to the legacy UI.
///
/// Defaults to `true` (show the new design). Flip to `false` to fall back to the legacy
/// presentation on migrated screens.
///
/// For reactive use inside a `View`, read it via `@AppStorage(VPDesignFlags.useObsidianGlassKey)`
/// so SwiftUI re-evaluates when it changes — the static accessor below is for non-reactive checks.
enum VPDesignFlags {
    static let useObsidianGlassKey = "useObsidianGlass"

    static var useObsidianGlass: Bool {
        UserDefaults.standard.object(forKey: useObsidianGlassKey) as? Bool ?? true
    }
}

// MARK: - Color Tokens

/// The "Obsidian Glass" palette: glossy-black substrate, frosted glass tints layered ON system
/// materials (never replacing them), a single specular gloss, and a restrained red accent used
/// as a glow. On-glass text tokens are tuned for ≥4.5:1 contrast over the lifted content plane.
enum VPColor {
    // Glossy-black bases (the world behind glass)
    static let void         = Color(red: 0.020, green: 0.024, blue: 0.039)
    static let abyss        = Color(red: 0.035, green: 0.043, blue: 0.067)
    /// Slightly lifted region painted behind content so dark-on-glass text keeps contrast even
    /// when the visionOS passthrough behind the window is bright.
    static let contentPlane = Color(red: 0.060, green: 0.070, blue: 0.105)

    // Glass tints — layered as a fill ON a system material, never as the whole background.
    // NOTE (bright-room contrast): over a very bright visionOS passthrough, the `.rest` tier is
    // the thinnest material, so `textTertiary` on a bare `.rest` surface should be validated
    // on-device. The rest tint is kept a touch higher for a minimum opacity floor.
    static let glassTintRest   = Color.white.opacity(0.08)
    static let glassTintRaised = Color.white.opacity(0.11)
    static let glassTintHero   = Color.white.opacity(0.14)

    // The single specular gloss (top-leading bright → bottom-trailing dim, one light source).
    static let specularBright = Color.white.opacity(0.32)
    static let specularDim    = Color.white.opacity(0.06)

    // Accent (VP red — a glow, used sparingly: selection, primary CTA, live progress).
    static let accent      = Color(red: 1.00, green: 0.16, blue: 0.33)
    static let accentLight = Color(red: 1.00, green: 0.35, blue: 0.35)
    static let accentGlow  = Color(red: 1.00, green: 0.16, blue: 0.33).opacity(0.45)
    /// Canonical accent gradient (the single source of truth the legacy `LinearGradient.vpAccent`
    /// now aliases to).
    static let accentGradient = LinearGradient(
        colors: [accent, accentLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Ambient backdrop orbs (blurred, behind glass).
    static let orbBlue   = Color(red: 0.08, green: 0.42, blue: 0.94)
    static let orbPurple = Color(red: 0.72, green: 0.24, blue: 0.96)
    static let orbRed    = Color(red: 0.96, green: 0.18, blue: 0.36)

    // Semantic state colors (tuned for dark glass).
    static let success = Color(red: 0.30, green: 0.86, blue: 0.55)
    static let warning = Color(red: 1.00, green: 0.68, blue: 0.22)
    static let danger  = Color(red: 1.00, green: 0.40, blue: 0.42)
    static let info    = Color(red: 0.45, green: 0.72, blue: 1.00)
    static let live    = accent

    // On-glass text (contrast verified over `contentPlane` — see VPContrast + tests).
    static let textPrimary   = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.76)
    static let textTertiary  = Color.white.opacity(0.60)
    static let textDisabled  = Color.white.opacity(0.34)
    static let textOnAccent  = Color.white

    /// Raw white-opacity values for the on-glass text tokens, exposed for contrast tests.
    static let onGlassTextOpacities: (primary: Double, secondary: Double, tertiary: Double) =
        (0.96, 0.76, 0.60)
}

// MARK: - Typography Tokens

/// Semantic type scale. Built on SwiftUI text styles so it scales with Dynamic Type (visionOS
/// users adjust system text size); weights/designs are overridden per role. This fixes the
/// "hard-coded point sizes" accessibility gap.
enum VPFont {
    static let displayHero   = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title1        = Font.system(.title, design: .default).weight(.bold)
    static let title2        = Font.system(.title2, design: .default).weight(.semibold)
    static let sectionHeader = Font.system(.subheadline, design: .default).weight(.semibold)
    static let rowTitle      = Font.system(.headline, design: .default)
    static let body          = Font.system(.body, design: .default)
    static let bodyEmphasis  = Font.system(.body, design: .default).weight(.medium)
    static let label         = Font.system(.subheadline, design: .default).weight(.medium)
    static let caption       = Font.system(.footnote, design: .default)
    static let captionEmph   = Font.system(.footnote, design: .default).weight(.semibold)
    static let micro         = Font.system(.caption2, design: .default).weight(.medium)

    /// Tracking for uppercase section headers.
    static let sectionHeaderTracking: CGFloat = 0.6
}

// MARK: - Spacing & Radius Tokens

/// 8pt baseline grid.
enum VPSpace {
    static let micro: CGFloat   = 4
    static let tight: CGFloat   = 8
    static let snug: CGFloat    = 12
    static let normal: CGFloat  = 16
    static let roomy: CGFloat   = 24
    static let section: CGFloat = 32
    static let hero: CGFloat    = 48

    /// Apple's minimum comfortable interactive target on visionOS.
    static let minTapTarget: CGFloat = 60
}

enum VPRadius {
    static let chip: CGFloat    = 12
    static let control: CGFloat = 16
    static let card: CGFloat    = 22
    static let surface: CGFloat = 28
    static let modal: CGFloat   = 34
}

// MARK: - Elevation Tokens (3 perceptual tiers)

/// Three perceptual depth tiers (collapsed from an over-fit five). Nearer / more important =
/// thicker, more opaque material + brighter specular + deeper shadow. Premium feel comes from
/// the *contrast between* tiers, not their count.
enum VPElevation {
    case rest   // rows, chips, badges — on a surface
    case raised // cards, nav, sheets
    case hero   // hovered, modal, the most prominent surface

    /// System material providing blur/vibrancy. Nearer tier = MORE opaque (thicker).
    var material: Material {
        switch self {
        case .rest:   return .ultraThinMaterial
        case .raised: return .regularMaterial
        case .hero:   return .thickMaterial
        }
    }

    /// Dark/glass tint layered on top of the material for the glossy-black look.
    var tint: Color {
        switch self {
        case .rest:   return VPColor.glassTintRest
        case .raised: return VPColor.glassTintRaised
        case .hero:   return VPColor.glassTintHero
        }
    }

    var strokeBright: Color { VPColor.specularBright }
    var strokeDim: Color { VPColor.specularDim }

    var strokeWidth: CGFloat {
        switch self {
        case .rest:   return 0.75
        case .raised: return 1.0
        case .hero:   return 1.25
        }
    }

    /// (color opacity, radius, y-offset) for the drop shadow. Deeper tier = larger spread.
    var shadow: (opacity: Double, radius: CGFloat, y: CGFloat) {
        switch self {
        case .rest:   return (0.18, 8, 4)
        case .raised: return (0.28, 18, 10)
        case .hero:   return (0.40, 30, 16)
        }
    }
}

// MARK: - Motion Tokens

/// One spring family. Things settle; they don't bounce.
enum VPMotion {
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.82)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let calm   = Animation.spring(response: 0.60, dampingFraction: 0.90)

    /// How far an interactive surface lifts toward the viewer on hover.
    static let hoverLift: CGFloat = 1.04
}

// MARK: - Contrast Utility (for tokens + tests)

/// WCAG relative-luminance contrast, used to validate on-glass text tokens against the lifted
/// content plane (the dark-theme baseline). Pure, testable.
enum VPContrast {
    /// sRGB relative luminance of an (r,g,b) in 0...1.
    static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    static func ratio(_ l1: Double, _ l2: Double) -> Double {
        let hi = max(l1, l2), lo = min(l1, l2)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// Contrast of white text at the given opacity composited over an opaque background color.
    /// (White over dark → the higher the opacity, the brighter the composite.)
    static func whiteTextRatio(opacity: Double, overR: Double, overG: Double, overB: Double) -> Double {
        let fr = opacity * 1.0 + (1 - opacity) * overR
        let fg = opacity * 1.0 + (1 - opacity) * overG
        let fb = opacity * 1.0 + (1 - opacity) * overB
        let fgLum = relativeLuminance(r: fr, g: fg, b: fb)
        let bgLum = relativeLuminance(r: overR, g: overG, b: overB)
        return ratio(fgLum, bgLum)
    }

    /// The content-plane baseline used as the worst-case dark background for on-glass text.
    static let contentPlaneRGB: (r: Double, g: Double, b: Double) = (0.060, 0.070, 0.105)
}
