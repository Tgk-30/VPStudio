# VPStudio UI/UX Revamp — Decisions & Reconciliation (read first)

This document is the output of: a 14-agent code-grounded planning workflow ("Obsidian Glass" design language + per-screen specs + roadmap) followed by an **adversarial review by MiniMax-M3 (vision-capable)** on the plan + a live screenshot.

The adversarial review was high-value but must be read with two corrections, because a vision model over-interpreted the screenshot.

## What MiniMax got RIGHT (fold these into the plan — they are real gaps)

1. **Accessibility is foundational, not a feature (C3, C4, H9).** The token set hard-codes point sizes with no Dynamic Type / `@ScaledMetric`, and the component specs never mention VoiceOver labels, traits, focus order, or live regions. → **Add accessibility + Dynamic Type to the design-system foundation (Phase 0), baked into every component's API**, not retrofit at call sites.
2. **The elevation/material mapping is inverted (H1).** The spec assigns `.thinMaterial` (most transparent) to the *nearest/most-important* tier — backwards. → Fix the material→tier mapping so nearer = more opaque/weighty.
3. **Contrast must be verified against composited passthrough, not raw color pairs (H2).** White-on-glass over a *bright* room is the real worst case. → Add a passthrough-luminance test matrix; the `contentPlane` lift behind text must be validated (or made more opaque) against a sunlit-room background.
4. **Don't stack system `.hoverEffect(.lift)` with a custom scale/z/spring (H3).** Pick one hover model. → Use the system hover effect OR fully custom, not both.
5. **Five elevation tiers is over-fit (H6).** → Collapse to **3 perceptual tiers** (rest / raised / hero). The premium feel comes from contrast between tiers, not their count.
6. **Onboarding is a real, visible bug and the plan ignored it (C2).** The screenshot shows a "Quick Start" modal AND a "Finish setup to unlock Discover" banner competing in one window, with 4 overflowing actions. → Add an onboarding/first-run phase: one entry point, ≤2 actions.
7. **The Player is ~95% of usage and was deliberately excluded (H5, H8, M4).** Shipping a gorgeous Settings/Library while the Player chrome stays old is a misallocation. → Add a dedicated **Player chrome** phase and split "visual revamp" from "monolith refactor" into two tracks so a refactor bug can't block a visual ship.
8. **Declare the scene/window model up front (H7, H10).** Which `WindowGroup`s exist, where ornaments live, SwiftUI-vs-RealityView split, scenePhase/resume behavior. → Lock this before drawing glass tiers.
9. Worth doing: state restoration (`SceneStorage`), Reduce Transparency/Motion branches (the plan mentioned these — make them mandatory + tested), and a real on-device test pass.

## What to DISCOUNT (MiniMax over-reached here)

1. **The "celestial / starfield / Star Map / constellation / tonight's-sky" brand is a HALLUCINATION.** VPStudio is a **media app** (movies/TV via debrid), not an astronomy app. What MiniMax read as "stars and mountain silhouettes" is the **visionOS simulator's default room environment** (framed wall art + passthrough), and the colored shapes are the app's abstract background orbs — not a celestial theme. So findings M1/M3/M5/M7 and the "you're killing the celestial brand" framing (H4) are based on a misread and can be ignored. (There is no celestial brand to preserve or retire.)
2. **The headline "abandon dark glass, go light/airy" verdict is the reviewer's opinion, and it contradicts the explicit product brief.** You asked specifically for a **glossy-black, premium glass** feel referencing Codex Mac, T3 Code, and Apple dark mode — all dark. visionOS *does* support custom darker glass, and many premium spatial apps use it; the "fights the platform" argument is a purist stance, not a hard rule. The *valid kernel* inside C1/H2 is **"dark glass over bright passthrough demands disciplined contrast"** — which the plan already started with `contentPlane`. → **Keep the dark glossy-black direction; execute it correctly** (contrast-tested content plane behind text; let the window's own system material do work; reserve fully-opaque dark only for the Player/immersive focus mode).

## Net recommendation

**Execute "Obsidian Glass" as planned, with these amendments:** keep the dark premium aesthetic you asked for; fold MiniMax's accessibility/Dynamic-Type, material-inversion, contrast-vs-passthrough, hover-stacking, 3-tier, onboarding, scene-model, and Player-first fixes into the foundation and roadmap; ignore the celestial-brand thread; treat "light vs dark" as your call (recommendation: dark, done rigorously).

**Amended phase order:**
- **Phase 0 — Foundation:** tokens **+ Dynamic Type + accessibility baked in**, **3 tiers** (not 5), correct material→tier mapping, scene/window model decided, contrast matrix defined.
- **Phase 1 — Components** (11 → with a11y + one hover model).
- **Phase 2 — Settings** (first; smallest blast radius).
- **Phase 3 — Onboarding/first-run fix** (promoted up: it's a visible bug).
- **Phase 4 — Player chrome** (promoted: 95% of use).
- **Phase 5 — Downloads → 6 — Library → 7 — Explore (incl. the 60pt close-button fix) → 8 — Discover polish + teardown.**
- **Parallel track:** monolith extractions (SearchView 1527, Library 1482, Downloads 687, PlayerView 5251, AISettingsView 2033), sequenced separately so refactor risk never blocks a visual ship.
- Everything behind an `@AppStorage("useObsidianGlass")` flag, screen-by-screen.

---

# Part A — Design Language ("Obsidian Glass")

I'll produce the design language spec directly. This is a synthesis task — the audit JSON gives me everything I need about the current state, duplication patterns, and violations. Let me write the concrete, implementable spec.

The audit reveals the core problems clearly: 29 scattered opacity values, 6 corner radii, no token file, the specular stroke gradient `[white.opacity(0.28), white.opacity(0.06)]` duplicated 41 times, the dual-layer shadow duplicated 15+ times, sub-60pt tap targets everywhere (44pt sidebar icons, 14pt close buttons, 28pt folder buttons), and flat material-only glass with no depth grading.

Here is the complete spec.

---

# VPStudio Design Language — "Obsidian Glass"

A single cohesive premium glassmorphism system for visionOS. Glossy black, frosted glass, restrained accents, real depth. References: Codex Mac, Apple Dark Mode, T3 Code.

---

## 1. VISUAL PRINCIPLES

1. **Glossy black is the substrate, not gray.** The world is near-black with a cold blue undertone. Glass floats *on* darkness; it never becomes the background. Today's `VPMenuBackground` (0.02–0.09 RGB) is correct in spirit but too muddy for text — we lift the *content plane* (a vignetted, slightly brighter region behind cards), not the whole field.
2. **Depth is earned through layering, not decoration.** Every surface declares a z-tier (Base → Surface → Raised → Modal → Overlay). Material thickness, stroke brightness, and shadow spread all scale *together* with the tier. The audit's #1 premium-feel gap is uniform shadow/stroke across all surfaces — we fix this with semantic elevation tokens.
3. **Specular gloss implies a single light, top-left.** One light source. Strokes brighten at top-leading, fade at bottom-trailing; shadows fall down-right. This is already the convention in code (`topLeading→bottomTrailing`) — we formalize it and forbid contradicting it.
4. **Restraint with the accent.** VP red (`1.0, 0.16, 0.33`) is a *glow*, used sparingly — selection, primary CTA, live progress. Never as a fill behind body text. Selected states stay *glass* with a red glow, never an opaque red slab (fixes the Library folder-chip and bottom-tab regressions).
5. **Vibrancy over opacity.** Text and icons on glass use vibrancy (`.foregroundStyle` hierarchy + material) so the blurred backdrop shifts through them. We replace ad-hoc `white.opacity(0.4)` text with semantic on-glass tokens that guarantee ≥4.5:1.
6. **Generous, rhythmic spacing.** 8pt baseline grid. Breathing room (24–36pt section gaps) signals premium; cramped rows signal cheap. Tap comfort (60pt) is non-negotiable in spatial space.
7. **Motion is calm and physical.** One spring family. Things settle, they don't bounce. Hover lifts toward the user; nothing jitters.

---

## 2. DESIGN TOKENS

Build as one file: `Design/VPDesign.swift` (namespaced `enum VPDesign`). This replaces the 29 scattered opacity values, 6 radii, 15+ spacing values, and the inline color RGB triples called out across `foundations` and `codestructure`.

### 2.1 Color System

```swift
import SwiftUI

enum VPColor {
    // ── Glossy-black bases (the world) ──
    static let void        = Color(red: 0.020, green: 0.024, blue: 0.039) // deepest bg
    static let abyss       = Color(red: 0.035, green: 0.043, blue: 0.067) // gradient mid
    static let contentPlane = Color(red: 0.060, green: 0.070, blue: 0.105) // lifted region behind cards (fixes dark-text contrast)

    // ── Glass tints (overlay ON material, never replace it) ──
    // Used as the fill *color* layered with .ultraThin/.regularMaterial.
    static let glassFill        = Color.white.opacity(0.06)  // neutral surface tint
    static let glassFillRaised  = Color.white.opacity(0.10)  // raised surface tint
    static let glassFillHover   = Color.white.opacity(0.14)  // hover state

    // ── Specular stroke endpoints (the ONE gloss gradient) ──
    static let specularBright = Color.white.opacity(0.32) // top-leading (raised tier)
    static let specularDim    = Color.white.opacity(0.06) // bottom-trailing

    // ── Accent (VP red — a glow, used sparingly) ──
    static let accent      = Color(red: 1.00, green: 0.16, blue: 0.33) // vpRed
    static let accentLight = Color(red: 1.00, green: 0.35, blue: 0.35) // vpRedLight (gradient top)
    static let accentGlow  = Color(red: 1.00, green: 0.16, blue: 0.33).opacity(0.45)

    // ── Ambient backdrop orbs (behind glass, blurred) ──
    static let orbBlue   = Color(red: 0.08, green: 0.42, blue: 0.94)
    static let orbPurple = Color(red: 0.72, green: 0.24, blue: 0.96)
    static let orbGreen  = Color(red: 0.14, green: 0.90, blue: 0.56)

    // ── Semantic state colors (tuned for dark glass, warm shadows) ──
    static let success = Color(red: 0.30, green: 0.86, blue: 0.55)
    static let warning = Color(red: 1.00, green: 0.68, blue: 0.22)
    static let danger  = Color(red: 1.00, green: 0.35, blue: 0.38)
    static let info    = Color(red: 0.40, green: 0.70, blue: 1.00)
    static let live    = accent // active downloads / progress

    // ── On-glass text (guaranteed contrast; replaces white.opacity(0.4) etc.) ──
    static let textPrimary   = Color.white.opacity(0.96) // titles, ≥7:1
    static let textSecondary = Color.white.opacity(0.74) // body/metadata, ≥4.5:1 (was 0.4–0.5, failing)
    static let textTertiary  = Color.white.opacity(0.58) // captions/hints, ≥3:1 — hints ONLY
    static let textDisabled  = Color.white.opacity(0.34)
    static let textOnAccent  = Color.white            // on red CTA
}
```

**Rules enforced (from audit):**
- The `info` filter chips, `secondary` description text, and genre subtitles flagged at `0.32`/`0.4` opacity move to `textSecondary` (0.74) minimum. `textTertiary` (0.58) is the floor and only for non-essential hints.
- Selected states never use opaque accent fill. Use `glassFillHover` + `accent` stroke + `accentGlow` shadow (see ButtonStyle below).

### 2.2 Typography Scale

visionOS readability favors larger type at distance. One scale, semantic names. Replaces ad-hoc `.caption/.subheadline/.headline` + raw `.system(size:)`.

```swift
enum VPFont {
    static let displayHero  = Font.system(size: 40, weight: .bold)             // hero title
    static let title1       = Font.system(size: 30, weight: .bold)             // screen titles
    static let title2       = Font.system(size: 24, weight: .semibold)         // card/section hero
    static let sectionHeader = Font.system(size: 15, weight: .semibold)        // SMALL CAPS tracking; section labels
    static let rowTitle     = Font.system(size: 18, weight: .semibold)         // list/destination row title
    static let body         = Font.system(size: 16, weight: .regular)
    static let bodyEmphasis = Font.system(size: 16, weight: .medium)
    static let label        = Font.system(size: 14, weight: .medium)           // buttons, chips
    static let caption      = Font.system(size: 13, weight: .regular)          // metadata
    static let captionEmph  = Font.system(size: 13, weight: .semibold)         // badge text
    static let micro        = Font.system(size: 11, weight: .medium)           // counts, tags
}
```

Hierarchy rule fixing the `settings` "header collapses into rows" finding: **section headers use `sectionHeader` (15/semibold) with +0.6 tracking and uppercase; row titles use `rowTitle` (18/semibold).** Header reads as a label *above* content, not a competing peer.

### 2.3 Spacing & Radius Scale (8pt grid)

```swift
enum VPSpace {
    static let micro: CGFloat   = 4
    static let tight: CGFloat   = 8
    static let snug: CGFloat    = 12
    static let normal: CGFloat  = 16
    static let roomy: CGFloat   = 24
    static let section: CGFloat = 32   // between major sections
    static let hero: CGFloat    = 48   // top-of-screen / generous visionOS breathing
}

enum VPRadius {
    static let chip: CGFloat    = 12   // tags, small buttons
    static let control: CGFloat = 16   // buttons, rows
    static let card: CGFloat    = 22   // cards (unifies the 16/20/26 chaos)
    static let window: CGFloat  = 28   // page-level glass container, sheets
    static let pill: CGFloat    = 999  // capsules
}
```

Single radius set kills the 12/14/16/20/26 inconsistency. `card` = 22 everywhere; `CinematicStateCard`'s 26 → 22, `MediaCardView`'s 20 → 22.

### 2.4 Elevation / Shadow / Material Recipes

The keystone fix. Five tiers; material, stroke, and shadow scale together. Encoded as one enum consumed by the `glassSurface` modifier.

```swift
enum VPElevation {
    case base      // page background content plane
    case surface   // list rows, chips, inline elements
    case raised    // cards, nav chrome, pickers
    case modal     // sheets, popovers
    case overlay   // hero glass, hover-lifted cards

    var material: Material {
        switch self {
        case .base:    return .ultraThinMaterial
        case .surface: return .ultraThinMaterial
        case .raised:  return .regularMaterial
        case .modal:   return .regularMaterial
        case .overlay: return .thinMaterial
        }
    }
    // Specular stroke top-leading brightness (Fresnel: brighter when nearer)
    var strokeTop: Double {
        switch self {
        case .base: return 0.10; case .surface: return 0.18
        case .raised: return 0.28; case .modal: return 0.32; case .overlay: return 0.40
        }
    }
    var strokeBottom: Double { 0.06 }
    var strokeWidth: CGFloat { self == .base ? 0.5 : 1 }

    // Stratified shadows (ambient + contact), scale with tier — fixes "uniform 0.07/0.13 everywhere"
    var shadows: [VPShadow] {
        switch self {
        case .base:    return []
        case .surface: return [VPShadow(0.18, 8, 2)]
        case .raised:  return [VPShadow(0.10, 20, 0), VPShadow(0.22, 8, 4)]
        case .modal:   return [VPShadow(0.14, 32, 0), VPShadow(0.30, 14, 8)]
        case .overlay: return [VPShadow(0.16, 40, 0), VPShadow(0.34, 16, 10),
                               VPShadow(0.10, 6, 2)] // tight contact line
        }
    }
}

struct VPShadow { let opacity: Double; let radius: CGFloat; let y: CGFloat
    init(_ o: Double, _ r: CGFloat, _ y: CGFloat) { opacity = o; radius = r; self.y = y } }
```

### 2.5 Motion

```swift
enum VPMotion {
    static let settle  = Animation.spring(response: 0.55, dampingFraction: 0.86) // appearance, layout
    static let hover   = Animation.spring(response: 0.35, dampingFraction: 0.80) // lift/highlight
    static let snap    = Animation.spring(response: 0.28, dampingFraction: 0.88) // selection/toggle
    static let ambient = Animation.easeInOut(duration: 8).repeatForever(autoreverses: true) // bg orbs
    static let staggerStep: Double = 0.04 // row entrance cascade (cap total < 0.4s)
    static let hoverLift: CGFloat = 1.04
    static let hoverLiftZ: CGFloat = 8 // visionOS z-translation toward viewer
}
```

---

## 3. CORE COMPONENT LIBRARY (SwiftUI)

Each entry: the component, what it replaces, the API. Files under `Design/Components/`.

### 3.1 `glassSurface(_:cornerRadius:tint:)` — the one modifier

The single source of truth replacing the **41 inline specular strokes + 15+ shadow pairs + material/border combos**. Everything visual flows through here.

```swift
struct GlassSurface: ViewModifier {
    var elevation: VPElevation
    var cornerRadius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(elevation.material)
                    if let tint { shape.fill(tint.opacity(0.16)) } // tint layered, not replacing material
                    shape.fill(VPColor.glassFill) // neutral gloss plane
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(elevation.strokeTop),
                                            .white.opacity(elevation.strokeBottom)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: elevation.strokeWidth)
            }
            .modifier(VPShadowStack(shadows: elevation.shadows))
            .contentShape(shape)
    }
}
extension View {
    func glassSurface(_ e: VPElevation, cornerRadius r: CGFloat = VPRadius.card,
                      tint: Color? = nil) -> some View {
        modifier(GlassSurface(elevation: e, cornerRadius: r, tint: tint))
    }
}
```

`VPShadowStack` just folds `.shadow` calls. **Every `.glassCard()`, `.glassStroke()`, `.glassShadow()`, and inline `RoundedRectangle.strokeBorder(...)` in the codebase becomes one `.glassSurface(...)` call.**

### 3.2 `VPCard` — page & section container

Wraps content in the premium "glass window" the `settings` and `downloads` audits call missing. Provides the macro-scale unifying frame.

```swift
VPCard(elevation: .raised) { content }            // section card
VPPageShell(title: "Settings") { sections }        // full-screen window glass (radius .window)
```
`VPPageShell` gives Settings/Library the immersive Codex-style framed surface (audit `settings` topProblem #2). Native `List` sections are replaced by `VPCard` groups.

### 3.3 Buttons — `VPButtonStyle` (one style, three roles)

Replaces `SpatialButton`, `GlassIconButton`, `actionCapsuleLabel`, `WizardAccentButton`, `folderChip`, type-filter buttons, action-button rows.

```swift
enum VPButtonRole { case primary, secondary, tertiary, destructive, icon }

struct VPButtonStyle: ButtonStyle {
    var role: VPButtonRole
    var isSelected: Bool = false
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(VPFont.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, role == .icon ? 0 : VPSpace.normal)
            .frame(minWidth: 60, minHeight: 60)            // 60pt HIG — fixes ALL tap-target violations
            .glassSurface(elevation, cornerRadius: radius, tint: tintColor)
            .overlay { if isSelected || focused { selectionRing } }
            .scaleEffect(pressed ? 0.97 : 1)
            .hoverEffect(.lift)
            .animation(VPMotion.hover, value: pressed)
    }
    private var selectionRing: some View {  // glass-preserving selection (NOT opaque red)
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(VPColor.accent, lineWidth: 1.5)
            .shadow(color: VPColor.accentGlow, radius: 12)
    }
    // primary → accent gradient fill; secondary → .raised glass; tertiary → .surface;
    // destructive → danger-tinted glass; icon → circular .surface, 60×60
}
```

Key fixes:
- **Every interactive element is ≥60pt** via `.frame(minWidth:60,minHeight:60)` — kills the sidebar 44pt, folder-chip 32pt, close-button 14pt, type-filter 22pt, action-button 44pt violations across `settings`, `library`, `explore`, `downloads`, `foundations`.
- **Selected = glass + red ring + glow**, never opaque slab (fixes Library/tab regressions).
- **Focus ring** unified for visionOS gaze nav (audit: missing everywhere).

### 3.4 `VPRow` — list / form / destination rows

Replaces `SettingsDestinationRow`, `downloadRow`, folder rows, form fields.

```swift
VPRow(icon: "gear", iconTint: .accent,
      title: "Debrid", subtitle: "Connected",
      badge: .init(.positive, "Recent"),
      trailing: { Chevron() })
```
- 36pt glass icon container (`.surface`), `rowTitle` title, `textSecondary` subtitle.
- `.frame(minHeight: 60)` + `VPSpace.snug` vertical padding (fixes `settings` 48pt rows).
- `.hoverEffect(.highlight)` + focus ring (fixes missing hover on rows).
- Row background `.surface` glass for depth separation (fixes "fully transparent rows").

### 3.5 `VPSectionHeader`

Replaces `SettingsSectionHeader` + inline `MediaRow`/`aiCuratedSection` headers.

```swift
VPSectionHeader("CONFIGURATION", icon: "slider.horizontal.3", action: { ... })
```
- `sectionHeader` font, uppercase, +0.6 tracking, `textTertiary` → establishes hierarchy *above* `rowTitle`. 36pt icon to match rows (fixes 28pt undersize).

### 3.6 Nav chrome — `VPNavButton` + `VPNavBar`

Collapses the ~90% duplicated `VPSidebarView` / `VPBottomTabBar` into one button + two layout shells (audit `foundations`/`codestructure` topProblem).

```swift
VPNavButton(item: tab, isSelected: sel, badge: count, axis: .vertical)  // sidebar
VPNavButton(item: tab, isSelected: sel, badge: count, axis: .horizontal) // bottom bar
```
- 60×60 hit target, `.raised` glass, selected = glass + accent ring + glow, badge dot tokenized, `.hoverEffect(.highlight)`, focus ring. `chromeScale` moves to an `EnvironmentKey`.

### 3.7 `VPProgressBar`

Replaces `GlassProgressBar`. Height param (`6/8/12`), gradient fill (`accentLight→accent`), inner specular highlight on the filled portion, shadow under unfilled track, optional inline label `"45% · 2.3/5.0 GB"`.

```swift
VPProgressBar(value: 0.45, height: 10, tint: .live, label: "45% · 2.3/5.0 GB")
```
Fixes `downloads` "progress de-emphasized" + `foundations` "no jewel-like quality." Reusable in player scrubber/download/resume.

### 3.8 `VPBadge` + `VPBadgeStyle`

Replaces `GlassTag` + the custom status-color logic duplicated in `SettingsDestinationRow` and download rows.

```swift
enum VPBadgeStyle { case neutral, positive, warning, danger, info, accent, metric }
VPBadge("4K HDR", style: .neutral)
VPBadge("Downloading", style: .info, icon: "arrow.down")
```
- `.surface` glass + tinted stroke, `captionEmph` font, `.frame(minHeight: 32)` when tappable. One styling source ends the badge-rhythm inconsistency (`settings`, `downloads`, `library`).

### 3.9 `VPStateCard` — empty / error / loading

Unifies `CinematicStateCard`, `LibraryEmptyStateView`, `LoadingOverlay`, `AppErrorInlineView`. Embeds backdrop artwork (`0.40` opacity, up from `0.28`), accent glow, icon (80pt, up from 52pt), narrative copy, action row. Crucially uses the **same `.raised` glass aesthetic as normal cards** so empty/error don't feel like a different screen (fixes `downloads` continuity break).

```swift
VPStateCard(.empty, icon: "tray", title: "Ready when you are",
            message: "...", accent: .accent) { actions }
```

### 3.10 `VPSheet` / `VPMenu`

Wraps system sheets/`Form`/`confirmationDialog` in `.modal` glass with `VPPageShell` chrome — fixes `explore` "filter sheet breaks cinematic aesthetic" (system `Form` styling). Custom layout, `VPRow` items, glass header.

### 3.11 `VPBackground` — the world

Replaces `VPMenuBackground`. Gradient `void→abyss`, three blurred orbs (`orbBlue/Purple/Green` at 0.30/0.26/0.22, blur 80–90) with `ambient` motion, **plus a radial `contentPlane` lift + edge vignette** behind the scroll region so body text always has a brighter, higher-contrast bed (fixes the dark-region readability flags in `settings`/`discover`). Intensity driven by one `EnvironmentKey`.

---

## 4. visionOS SPECIFICS

- **Materials vs custom glass.** Use system `Material` for the blur (it's GPU-cheap and respects vibrancy/Dynamic) — never hand-roll blur. Custom layer = the *tint + specular stroke + stratified shadow* on top, all via `glassSurface`. Tier→material map is fixed in `VPElevation` (§2.4): `.ultraThin` for surface/base, `.regular` for raised/modal, `.thin` for overlay/hero. This gives the depth grading the audit says is missing (everything was flat `.regularMaterial`).
- **Vibrancy.** All on-glass text/icons use `.foregroundStyle(VPColor.textPrimary/Secondary)` over material so the backdrop shifts through — do **not** stack manual `.opacity()` on already-semantic colors (audit: "opacity cascading" makes contrast untraceable). One opacity, from the token.
- **60pt targets, always.** `VPButtonStyle`, `VPRow`, `VPNavButton`, `VPBadge` (interactive) all hard-enforce `minWidth/minHeight: 60`. The 14pt close button, 28pt folder buttons, 36pt icon buttons, 44pt nav/info buttons, 48–50pt tab buttons all resolve through these components. Visible glyph can stay small (e.g., 24pt icon) inside a 60pt hit area.
- **Hover + lift + focus (unified language).**
  - Cards/buttons/nav → `.hoverEffect(.lift)` + `VPMotion.hover` scale `1.04` + z-translate `8pt` toward viewer.
  - Rows/secondary → `.hoverEffect(.highlight)`.
  - **Focus ring** (gaze/keyboard): every interactive component renders the accent `selectionRing` on `@Environment(\.isFocused)` — fixes "no focus indicators anywhere."
- **Ornaments.** Player transport controls and per-screen primary actions (Settings save, Library sort/import) move from inline material buttons to `.ornament` (bottom edge) so the content plane stays uncluttered and depth reads correctly (audit: immersive controls use inline buttons instead of ornaments).
- **Depth / z-layering.** Strict tier order so nothing sits at an ambiguous depth: `VPBackground` (z0, far) → `contentPlane` (z1) → `VPCard .raised` (z2) → rows/badges `.surface` (z3, *nested inside* card, +2pt local shadow for ambient occlusion) → `.modal` sheets (z4) → `.overlay` hero/hover (z5, nearest). The +2pt nested contact shadow on `.surface` inside `.raised` creates the "thickness"/ambient-occlusion the audit found missing between nested glass layers.
- **Reduce Motion / Transparency.** When `reduceMotion`, swap springs for `easeInOut(0.25)` and disable orb `ambient`. When `reduceTransparency`, `glassSurface` falls back to a solid `contentPlane`-derived fill (keep stroke, drop blur) so contrast is preserved.

---

## Build order (so an engineer can start now)

1. `Design/VPDesign.swift` — all token enums (§2). 2. `GlassSurface` modifier + `VPShadowStack` (§3.1). 3. `VPButtonStyle`, `VPBadge`, `VPProgressBar` (leaf components). 4. `VPRow`, `VPSectionHeader`, `VPCard`/`VPPageShell`. 5. `VPNavButton`/`VPNavBar`, `VPStateCard`, `VPSheet`, `VPBackground`. 6. Migrate per screen, deleting `GlassCard.swift`'s scattered primitives and the 41 inline strokes / 15+ shadow pairs as you go.

This token file + 11 components collapse the duplication cited across all seven audits into a single source of truth, bring every tap target to 60pt, grade glass depth into five real tiers, and guarantee on-glass text contrast — delivering the glossy-black, Codex-grade premium feel within the visionOS HIG.

# Part B — Phased Roadmap

I have all the synthesized inputs I need — the design language, five per-screen specs, and the code-structure audit. This is a pure assembly task, so I'll write the executive plan directly.

# VPStudio UI/UX Revamp — Executive Plan: "Obsidian Glass"

## 1. The Vision

VPStudio becomes a single, cohesive **glossy-black glassmorphism** experience for visionOS — Codex-grade premium, where frosted glass floats on near-black with restrained VP-red accents used only as a glow. Today's surfaces are flat (one uniform material, the same shadow everywhere), depth is undifferentiated, and the same glass recipe is hand-rolled in 41+ places. We fix this at the root by shipping **one design-token file + 11 reusable components** that grade glass into five real depth tiers, guarantee ≥4.5:1 text contrast, and hard-enforce 60pt tap targets. The 40+ scattered edits-per-tweak collapse to 3–5 canonical sites, and every screen inherits premium depth, motion, and accessibility for free.

## 2. Phased Roadmap (foundation first, then screens by priority)

**Foundation → Settings → Downloads → Library → Explore → Discover**, with code-structure wins woven into each screen pass (extract monoliths, delete duplicated primitives as call sites migrate).

---

### Phase 0 — Design-System Foundation `[L]` (no UI ships yet, but unblocks everything)

The keystone. Build the single source of truth before touching any screen.

**Deliverables**
- `Design/VPDesign.swift` — all token enums: `VPColor` (glossy-black bases, glass tints, specular endpoints, accent, semantic states, on-glass text tokens replacing the 29 scattered opacities), `VPFont` (semantic scale), `VPSpace` (8pt grid), `VPRadius` (unifies the 12/14/16/20/26 chaos → one set), `VPElevation`/`VPShadow` (five-tier material+stroke+shadow recipes), `VPMotion` (one spring family).
- `Design/Components/GlassSurface.swift` — the `.glassSurface(_:cornerRadius:tint:)` modifier + `VPShadowStack`, plus a `.vpInteractive()` modifier folding hover/lift/z-translate/focus-ring + Reduce Motion/Transparency fallbacks. **This one modifier replaces all 41 inline specular strokes and 15+ shadow pairs.**

**Components built:** tokens, `GlassSurface`, `VPShadowStack`, `.vpInteractive()`.
**Dependencies:** none. **This is the critical path — everything else depends on it.**

---

### Phase 1 — Core Component Library `[L]`

The 11 leaf/composite components every screen consumes. Build leaves first, then composites.

**Deliverables (build order):**
1. Leaves: `VPButtonStyle` (roles: primary/secondary/tertiary/destructive/icon — 60pt enforced, glass+ring selection), `VPBadge`/`VPBadgeStyle`, `VPProgressBar` (height + inline label + specular fill), `VPCloseButton` (the canonical 60pt "x" fix).
2. Composites: `VPRow`, `VPSectionHeader`, `VPCard` + `VPPageShell`.
3. Chrome/states: `VPSegmentedControl`, `VPChip`/`VPChipRail`, `VPStatusStrip`, `VPStateCard`, `VPSheet`, `VPBackground` (replaces `VPMenuBackground` — adds the `contentPlane` lift + vignette that fixes dark-text readability), `VPNavButton`/`VPNavBar` (collapses the ~90% duplicated sidebar/bottom-bar).

**Effort:** Buttons/Badge/Progress `[M]`; Row/Header/Card `[M]`; SegmentedControl/Chip/StateCard/Sheet/Background/Nav `[L]`.
**Dependencies:** Phase 0.

---

### Phase 2 — Settings Revamp `[M]` (first screen — highest ratio of clear wins, lowest risk)

Settings is the proving ground: contained scope, every component exercised once, immediate contrast/tap-target payoff.

**Deliverables**
- Replace native `List` with `VPPageShell(title:"Settings")` over `VPBackground`; `ScrollView` of `VPCard(.raised)` groups at `VPSpace.section`.
- Health card → `.raised` glass with `VPProgressBar(height:10, label:)` centerpiece; section headers → `VPSectionHeader` (fixes hierarchy collapse); destination rows → `VPRow` at 60pt (was ~48pt); status logic → `VPBadge`; Quick Actions → `VPButtonStyle`; Reset → `.destructive` glass (not bare red text). Primary actions → bottom `.ornament`.
- **Code structure:** split 411-line `SettingsRootView` into `SettingsHealthCard`/`SettingsCategorySection`/`SettingsAppearanceCard`/`SettingsAboutCard`; `SettingsDestinationRow` → thin `VPRow` adapter (delete `statusForeground/Background`); centralize RGB triples from `GlassCard.swift:500-510` + `VPMenuBackground` into `VPColor`.

**Components exercised:** all of Phase 1. **Dependencies:** Phases 0–1.

---

### Phase 3 — Downloads Revamp `[M]`

**Deliverables**
- Four z-tiers: `VPBackground` → `VPPageShell` → `VPCard(.raised)` group cards → `VPRow` task rows. Poster grows 60×90 → 96×144 (scannability). Group + task progress become **headline `VPProgressBar`s with inline `"45% · 2.3/5.0 GB"`** instead of hairlines. Action buttons → 60pt `VPButtonStyle` with destructive `delete` spatially isolated from `play`. Empty/error → `VPStateCard` (same `.raised` aesthetic — no "different screen" break).
- **Code structure:** split the 687-line `DownloadsView` into `DownloadGroupCard`/`DownloadTaskRow`/`DownloadTaskActionButtons`/`DownloadStateSurfaces`; promote `statusColor`/`progressText`/`formatBytes` to model extensions + shared `ByteCountFormatting`; consolidate four scattered `@State` flags into one `DownloadsScreenState`. ViewModel data shape untouched.

**Dependencies:** Phases 0–1 (+ adds inline-label capability to `VPProgressBar`, reusable everywhere after).

---

### Phase 4 — Library Revamp `[L]` (largest screen; biggest structural payoff)

**Deliverables**
- `VPPageShell` window; title cluster with count + **surfaced sort `VPBadge`**; actions → bottom `.ornament` (`LibraryActionBar`). Tab picker → `VPSegmentedControl` (selected = glass + red ring, **never opaque red slab**). Folder chips → `VPChip` at 60pt (was ~32pt, was opaque-red selected); +/trash → 60pt `VPButton(.icon)` (was 28pt). Status/error → `VPStatusStrip`. `MediaCardView` → radius 22, **resting** glass depth, tokenized metadata (off failing 0.3–0.5 opacity), `VPProgressBar` resume bar. Empty/loading → `VPStateCard`.
- **Code structure:** decompose the 1482-line god-view — extract `CreateLibraryFolderSheet` (stops parent recompiling on sheet state), `LibraryFolderRail`, `LibraryActionBar`, `LibraryTitleRow`; one `VPChip` kills the two-overload duplication; wire the dead `LibraryGridPolicy.columns(containerWidth:)`.

**Components exercised:** adds `VPSegmentedControl`, `VPChip`/`VPChipRail`, `VPStatusStrip` to production. **Dependencies:** Phases 0–1.

---

### Phase 5 — Explore/Search Revamp `[L]` (includes the critical undersized-clear-button fix)

**Deliverables**
- **Critical tap-target fix:** recent-chip close (8.5pt glyph / ~14pt target — 78% under HIG) and search-clear (14pt) → `VPCloseButton` (60pt). This is a flagged severe violation.
- Cohesive 60pt control row (search bar + "Curate For Me" pill + filter button, all same height). Type filter → `VPSegmentedControl` — **retires the off-palette cyan slab** for glass + accent ring. Two overlapping filter-chip systems (`compactSummaryChip` + `activeFilterSummary`) → one model-driven `FilterChipStack` where color signals removable-vs-informational. Genre tiles → 2-stop stroke + real `.raised` lift (was a 5-stop over-engineered near-zero-shadow). Filter sheet's system `Form` → `VPSheet`/`VPPageShell` glass. AI accent purple → the one accent red.
- **Code structure:** `SearchView.swift` **1527 → ~700 lines** by extracting `SearchTypeFilter`, `FilterChipStack`, `SearchQueryBar`; externalize the 19-row language list to `languages.json`; export `RecentSearchChip` for tests.

**Dependencies:** Phases 0–1.

---

### Phase 6 — Discover Polish + GlassCard Teardown `[M]`

**Deliverables**
- Hero gets a real `.thinMaterial` glass anchor + overlay-tier stroke/shadow (fixes "flat glass, neither material"); 5-stop feathered gradient; **solid `textPrimary` upright title** (drops the −12% contrast red-gradient italic), red kept as glow only. `FeaturedHeroView` + `AICuratedHeroCard` (85% identical) collapse into one `VPCinematicHero`. Section headers → `VPSectionHeader` with 36pt glass icon chips. Metadata bullet row (duplicated 3×) → `VPMetadataRow`. States → `VPStateCard`.
- **Teardown:** after all screens migrate, **delete** `GlassTag`, `SpatialButton`, `GlassIconButton`, `GlassProgressBar`, `CinematicStateCard`, and the `glassStroke`/`glassShadow`/`glassCard` extensions from `GlassCard.swift` (577 → focused `FlowLayout` + `ArtworkFallback`). Remove the `VPMenuBackground` typealias shim.

**Components exercised:** adds `VPCinematicHero`, `VPMetadataRow`. **Dependencies:** Phases 0–5 (teardown must come last).

---

## 3. Quick Wins (achievable immediately, high visible payoff)

1. **`VPBackground` swap** — once Phase 0 + `VPBackground` exist, swapping `VPMenuBackground()` → `VPBackground()` app-wide instantly fixes dark-text readability via the `contentPlane` lift. Biggest perceived-quality jump for the least code.
2. **`VPCloseButton` + 60pt enforcement** — drop into Explore's 8.5pt/14pt close buttons; clears the most severe HIG violation in one component.
3. **`VPProgressBar` in Downloads** — turn hairline progress into a jewel-like headline element; immediately reads as "premium."
4. **Token-only contrast pass** — point existing `.secondary`/`white.opacity(0.4)` text at `VPColor.textSecondary` (0.74) even before full component migration; clears WCAG AA across screens cheaply.

## 4. Risks & De-Risking

- **Big-bang regression risk → ship behind a feature flag, screen-by-screen.** Gate the new design system behind an `@AppStorage("useObsidianGlass")` (or build config) so old and new screens coexist. Migrate one screen per phase, validate, then move on — Settings first precisely because it's the smallest blast radius.
- **`GlassCard.swift` primitives are shared across all screens → keep a deprecation shim, delete last.** Do **not** delete `GlassTag`/`SpatialButton`/`GlassMenuBackground` until every call site migrates (Phase 6). Keep a `VPMenuBackground = VPBackground` typealias so unmigrated screens never break mid-flight.
- **Foundation churn → freeze tokens early.** The token file is the dependency root; late changes ripple. Lock `VPColor`/`VPElevation`/`VPRadius` values at the end of Phase 0 and treat changes as deliberate design decisions, not casual tweaks.
- **visionOS-specific behaviors (ornaments, gaze focus, Reduce Motion/Transparency) are hard to unit-test → bake fallbacks into `.vpInteractive()`/`glassSurface` centrally** so they're correct-by-construction everywhere, and validate on-device per screen as part of each phase's acceptance.
- **Monolith extraction risk (PlayerView 5,251 lines / AISettingsView 2,033 lines) → keep out of the visual critical path.** These are real but orthogonal; flag them as a parallel code-health track (extract `PlayerSession` state model, `SettingsSectionContainer`/`CredentialFieldGroup`) so refactor risk doesn't block the UI revamp.
- **Test fragility → update render/policy tests to read from tokens** (`VPRadius`/`VPColor`) as each screen migrates, so future spacing/radius tweaks don't silently break `ExploreGenreGridPolicyTests`/`LibraryHeaderConsistencyTests`.

**Net:** one token file + 11 components, built once, collapse the duplication cited across all seven audits into a single source of truth — bringing every tap target to 60pt, grading glass into five real depth tiers, and guaranteeing on-glass contrast — then each screen, shipped safely behind a flag in priority order, inherits the glossy-black Codex-grade premium feel for free.

# Part C — Per-Screen Redesign Specs


## Screen: settings

I now have full precision on the current code, the shared primitives, and the background. Here is the concrete redesign spec.

---

# Settings Screen Redesign — "Obsidian Glass"

## (a) New layout & intended look

Replace the native `List` with a `VPPageShell(title: "Settings")` — a single immersive glass window (radius `VPRadius.window` = 28, `.modal` elevation) floating on `VPBackground`. Inside, a `ScrollView` of stacked `VPCard(elevation: .raised)` groups separated by `VPSpace.section` (32pt). The screen reads top-to-bottom as: hero title row → Configuration Health card → Continue (recent) → category section cards → Appearance card → Quick Actions card → About card → destructive Reset card.

Visual intent, top to bottom:

- **Hero header.** Large `VPFont.title1` "Settings" left-aligned at `VPSpace.hero` top inset, with the search field directly beneath it as a glass `.surface` pill (replacing `.searchable`, which renders as native chrome that breaks the cinematic frame). Primary actions (Run Setup, Refresh) move to a bottom `.ornament` on visionOS so the content plane stays clean.
- **Configuration Health** becomes a real `.raised` glass card: left a 44pt accent-tinted glass icon (`gauge.with.dots.needle.50percent`), center the title in `VPFont.title2` + `VPFont.caption` secondary line at `textSecondary` (0.74, up from `.secondary`), right a `VPBadge(style: .warning)`. Below, a taller `VPProgressBar(height: 10, tint: healthTint, label: "3/5 configured")` with the jewel-like specular fill — the card's centerpiece.
- **Category sections** are `VPCard`s, each opening with a `VPSectionHeader` (uppercase, +0.6 tracking, `sectionHeader` font, 36pt icon) that clearly sits *above* the rows, then `VPRow`s at 60pt min height with `.surface` glass beds nested inside the `.raised` card (+2pt contact shadow for thickness). Each row: 36pt glass icon + status dot, `rowTitle` (18/semibold) title, `textSecondary` summary, trailing `VPBadge` and chevron.
- **Appearance / Quick Actions / About** all become `VPCard`s with `VPRow`-styled content — the intensity slider sits in a row with a live value `VPBadge`; Quick Actions become `VPButtonStyle` buttons (60pt); About rows reuse `VPRow` with trailing `VPBadge(style: .metric)` for version/build.
- **Reset** is a `VPCard` containing a `VPButtonStyle(role: .destructive)` button (danger-tinted glass, not bare `.red` text), with the warning footer in `textTertiary`.

## (b) Design-system components & tokens used

Tokens: `VPColor` (textPrimary/Secondary/Tertiary replace `.secondary`/`.tertiary`; `accent`/`accentGlow`; `success`/`warning`/`info`; `contentPlane`), `VPFont` (title1/title2/sectionHeader/rowTitle/caption/captionEmph), `VPSpace` (8pt grid), `VPRadius` (window/card/control/chip), `VPElevation` (.modal shell, .raised cards, .surface rows/icons), `VPMotion` (settle entrance, hover, snap), `VPShadow`.

Components: `VPPageShell`, `VPCard`, `VPSectionHeader`, `VPRow`, `VPBadge`/`VPBadgeStyle`, `VPProgressBar`, `VPButtonStyle`, `VPBackground`, and the `.glassSurface(_:cornerRadius:tint:)` modifier underpinning all of them.

## (c) Before → after, per element

| Element | Before | After |
|---|---|---|
| Container | native `List` + `scrollContentBackground(.hidden)` | `VPPageShell` glass window (radius 28, `.modal`) over `VPBackground`, `ScrollView` of `VPCard`s |
| Background | `VPMenuBackground`, void colors 0.02–0.09, no content-plane lift | `VPBackground`: `void→abyss` gradient + 3 orbs (`orbBlue/Purple/Green`) + radial `contentPlane` lift + vignette behind scroll → fixes dark-text readability (top problem #4) |
| Health card | transparent `VStack`, `.subheadline` title, `.secondary` caption, 8pt gaps | `VPCard(.raised)`, `title2` title, `textSecondary` caption, `VPSpace.snug` (12) gaps, 44pt accent icon, `VPProgressBar(height:10,label:)` |
| Section header | 28pt icon, `.subheadline.weight(.semibold)` title competing with rows | `VPSectionHeader`: 36pt icon, uppercase `sectionHeader` (15) +0.6 tracking, `textTertiary` → reads as a label above (fixes hierarchy collapse #3) |
| Destination row | `HStack`, `.padding(.vertical,4)` (~48pt), `.headline` title, transparent bg, no hover | `VPRow`: `.frame(minHeight:60)` + `VPSpace.snug` padding (~68–72pt), `rowTitle` title, `.surface` glass bed, `.hoverEffect(.highlight)` + focus ring (fixes #1, hover, separation) |
| Row icon | 36pt `LinearGradient.vpAccent` 0.14 fill | 36pt `.surface` glass + `accent` tint, status dot tokenized via `VPColor.success/warning/info` |
| Status badge | inline `statusForeground`/`statusBackground` Color logic | `VPBadge(style:)` — one source; `.positive/.warning/.neutral` map to `success/warning` tinted glass (kills duplicated badge logic) |
| "Recent" tag | `GlassTag(weight:.semibold)` mismatched rhythm | `VPBadge("Recent", style: .accent)` consistent sizing |
| Appearance slider | native `Slider` + `.secondary` value text | `VPRow` host + value as `VPBadge(style:.metric, monospaced)`; slider gets focus indication |
| Quick Actions | native `Label` buttons, no glass | `VPButtonStyle(role:.secondary)` 60pt glass buttons (fixes inconsistency) |
| About rows | plain `HStack` | `VPRow` with trailing `VPBadge(style:.metric)` |
| Reset | bare `.red` `Label` | `VPButtonStyle(role:.destructive)` danger-tinted glass card; footer `textTertiary` |
| Progress bar stroke | 0.5pt | 1pt via `VPProgressBar`/`glassSurface` (consistency) |

## (d) SwiftUI-level changes

**New files (Design system, build once, shared across all screens):**
- `VPStudio/Views/Design/VPDesign.swift` — `VPColor`, `VPFont`, `VPSpace`, `VPRadius`, `VPElevation`, `VPShadow`, `VPMotion` (centralizes the RGB triples currently inline at `GlassCard.swift:500-509`, `VPMenuBackground.swift:16-40`).
- `VPStudio/Views/Design/Components/`: `GlassSurface.swift` (+`VPShadowStack`), `VPCard.swift` (+`VPPageShell`), `VPRow.swift`, `VPSectionHeader.swift`, `VPBadge.swift`, `VPProgressBar.swift`, `VPButtonStyle.swift`, `VPBackground.swift`.

**Modify:**
- `SettingsRootView.swift` — replace `List{…}` body with `VPPageShell` + `ScrollView` + `LazyVStack(spacing: VPSpace.section)` of `VPCard`s; drop `.scrollContentBackground(.hidden)`, swap `VPMenuBackground()` → `VPBackground()`; convert `.searchable` to an in-shell glass search field bound to `$query`; move `infoRow`/health/quick-actions inline builders to `VPRow`/`VPButtonStyle`; move Run Setup + Refresh into `.ornament(attachmentAnchor:.scene(.bottom))`. Extract three subviews — `SettingsHealthCard`, `SettingsCategorySection`, `SettingsAppearanceCard` — to shrink the 411-line file.
- `SettingsDestinationRow.swift` — reduce to a thin adapter that builds a `VPRow` (icon, title, summary, `VPBadge` for status/recent); delete `statusForeground`/`statusBackground`/`statusBadge` (now in `VPBadgeStyle`). Keep the accessibility policy calls.
- `SettingsSectionHeader.swift` — reduce to a `VPSectionHeader` adapter (36pt icon, uppercase title, summary as `textTertiary`).
- `SettingsAppearancePolicy.swift` — keep policy logic; appearance *values* (fonts/spacing/material) now come from `VPDesign`, not new ad-hoc constants.
- `VPMenuBackground.swift` — re-implement as a thin wrapper over `VPBackground` (or deprecate) so other screens migrate without breakage; intensity binding unchanged.

## (e) visionOS interactions, accessibility, tap targets

- **60pt everywhere.** `VPRow.frame(minHeight:60)`, `VPButtonStyle.frame(minWidth:60,minHeight:60)`, interactive `VPBadge` minHeight 32 inside ≥60pt rows. Resolves the ~48pt row violation (top problem #1), 28pt header icon, native-button targets. Visible glyphs stay 15–24pt inside the hit area.
- **Hover.** Rows `.hoverEffect(.highlight)`; buttons/cards `.hoverEffect(.lift)` with `VPMotion.hover` scale 1.04 + 8pt z-translate toward viewer (rows currently have none).
- **Focus.** Every interactive component renders the accent `selectionRing` on `@Environment(\.isFocused)` (gaze/keyboard) — none exist today. Slider gets a focused glass track.
- **Depth.** Strict z-order: `VPBackground` → `contentPlane` → `VPPageShell` (.modal) → `VPCard` (.raised) → `VPRow`/`VPBadge`/icons (.surface, +2pt nested contact shadow for ambient occlusion). Fixes "flat material, no depth grading."
- **Contrast/a11y.** All secondary/tertiary text moves to `textSecondary` (0.74, ≥4.5:1) / `textTertiary` (0.58, hints only) over the lifted `contentPlane` — fixes the unreadable `.secondary` descriptions (#4). Preserve existing `SettingsAccessibilityPolicy` labels/hints, slider `accessibilityValue`. Respect `reduceMotion` (springs→`easeInOut(0.25)`, orbs off) and `reduceTransparency` (`glassSurface`→solid `contentPlane` fill, stroke kept).
- **Motion.** Card/row entrance uses `VPMotion.settle` with `staggerStep` 0.04 capped <0.4s; selection/toggle uses `snap`.

## (f) Code-structure improvements specific to this screen

- Centralize the RGB triples (`GlassCard.swift:500-510`, `VPMenuBackground.swift`) into `VPColor`; the duplicated `glassStroke`/`glassShadow`/`glassCard` extensions (`GlassCard.swift:547-577`) collapse into the single `glassSurface` modifier — delete after migration.
- Extract status-badge color logic out of `SettingsDestinationRow` (`:93-107`) into `VPBadgeStyle` (one source, reused by health card + rows).
- Split `SettingsRootView` (411 lines, 11 `@State`/6 `@AppStorage`) into `SettingsHealthCard`, `SettingsCategorySection`, `SettingsAppearanceCard`, `SettingsAboutCard` subviews.
- `GlassProgressBar`→`VPProgressBar`, `GlassTag`→`VPBadge`, native buttons→`VPButtonStyle` — removes per-component inline material/stroke/shadow duplication.

**Build order by impact:** (1) `VPDesign.swift` + `GlassSurface`; (2) `VPBackground` + swap into Settings (immediate contrast win, top problem #4); (3) `VPRow` 60pt + `VPCard` macro-frame via `VPPageShell` (top problems #1, #2); (4) `VPSectionHeader` hierarchy fix (#3); (5) `VPBadge`/`VPProgressBar`/`VPButtonStyle` to finish glassmorphism + badge unification (#5).

Key files: `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Settings/Root/SettingsRootView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Settings/Components/SettingsDestinationRow.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Settings/Components/SettingsSectionHeader.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/GlassCard.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/VPMenuBackground.swift`, plus new `/Users/brendan/Developer/VPStudio/VPStudio/Views/Design/VPDesign.swift` and `/Users/brendan/Developer/VPStudio/VPStudio/Views/Design/Components/`.

## Screen: downloads

I have everything I need. The audit JSON, the actual current code (DownloadsView 687 lines, GlassTag/GlassProgressBar/CinematicStateCard primitives), the model fields (DownloadStatus, DownloadTask, DownloadMediaGroup with `overallProgress`/`hasActiveDownloads`/`completedCount`/`totalCount`/`posterURL`), and confirmed no `Design/` directory exists yet. Here is the concrete redesign spec.

---

# Downloads Screen Redesign — "Obsidian Glass"

## (a) New layout & hierarchy — intended look

The screen reads top-to-bottom as: **world → page shell → media-group cards → task rows**, four clean z-tiers instead of today's flat single-material plane.

**Page level.** The whole view sits on `VPBackground` (void→abyss gradient + three blurred orbs + a `contentPlane` radial lift behind the scroll region so body text always has a brighter bed). A `VPPageShell(title: "Downloads")` wraps the scroll content in `.window`-radius (28) glass, replacing the bare `navigationTitle` + `VPMenuBackground`. A right-aligned overview strip in the shell header shows aggregate state ("3 active · 12 GB" via `VPBadge .metric`) — an anchor the audit says the monolithic list lacks.

**Media-group card (`.raised`, radius 22).** A redesigned banner header:
- **Poster grows 60×90 → 96×144** (2:3 preserved), wrapped in its own `.surface` glass frame with a +2pt nested contact shadow so it reads as a foreground layer floating above the card (ambient occlusion). This is the scannability fix.
- Title in `VPFont.title2` (24/semibold), `textPrimary`. Below it: a `VPBadge` for Series/Movie (glass, not opaque blue/purple slab) + a `textSecondary` "8/12 downloaded" line.
- When the group has active downloads, a **prominent full-width `VPProgressBar` (height 10, `.live` tint, inline label "45% · 2.3/5.0 GB")** spans under the title — group-level progress becomes a headline element, not a hairline.
- The "delete all" affordance moves out of the header corner into the card's bottom **ornament-style action row** so destructive actions are spatially isolated (see buttons below).

**Task rows (`VPRow`, `.surface` nested in `.raised`).** Each row is restructured into three readable zones instead of the cramped 2-line label:
1. **Leading:** 36pt glass status glyph (color-coded via `DownloadStatus.accentColor`), giving every row an instant scannable anchor.
2. **Center (stacked):** episode/file title in `rowTitle` (18); a metadata line with a `VPBadge` status chip + `textSecondary` size; and — for any in-flight task — a **dedicated full-width `VPProgressBar` row (height 8) with inline percent/ETA label** on its own line, no longer wedged between status and size. Error text uses `VPColor.danger` at `caption`.
3. **Trailing:** a `DownloadTaskActionButtons` group (see c/d) — primary `play` (60pt accent glass), utility cancel/retry (60pt secondary glass), and a **visually separated destructive `delete`** (danger-tinted glass) with a real gap, so delete is never adjacent to play.

**Empty/error states** are redrawn to use the **same `.raised` glass card aesthetic** as a normal group card (via `VPStateCard`), with the cinematic artwork pushed *behind* the scroll region as a decorative backdrop (0.40 opacity) rather than being a different-feeling `CinematicStateCard` container. Continuity is preserved — no "transported to another screen" break. Icon grows 52→80pt.

## (b) Design-system components & tokens used

New (build first, in `VPStudio/Design/`):
- **Tokens** `VPDesign.swift` — `VPColor`, `VPFont`, `VPSpace`, `VPRadius`, `VPElevation`/`VPShadow`, `VPMotion`.
- **`GlassSurface` modifier** (`.glassSurface(_:cornerRadius:tint:)`) — replaces every inline `.background(.regularMaterial…)` + specular `strokeBorder` + dual `.shadow` triplet on this screen (group card lines 351-364, inline error banner 186-197).
- **`VPProgressBar`** — replaces `GlassProgressBar`, adds height + inline label + gradient + filled-portion specular highlight + track shadow.
- **`VPBadge` / `VPBadgeStyle`** — replaces `GlassTag` usages (type chip, status chips, count).
- **`VPButtonStyle`** (roles: primary/secondary/destructive/icon, 60pt enforced, glass+ring selection) — replaces `SpatialButton`, raw `Image(systemName:)` action buttons, `GlassTag`-as-button.
- **`VPRow`** — task-row scaffold.
- **`VPCard` / `VPPageShell`** — group container + page shell.
- **`VPStateCard`** — empty/error.
- **`VPBackground`** — replaces `VPMenuBackground`.

Tokens applied here specifically: `VPRadius.card` (22, unifies 16-vs-26), `VPElevation.raised`/`.surface` (depth grading), `VPColor.textSecondary` (0.74, replaces failing `.secondary`/`.caption2`), `VPColor.live`/`success`/`danger`, `VPSpace.roomy`/`section` (card gaps), `VPMotion.hover`/`settle`.

## (c) Before → after per major element

| Element | Before | After |
|---|---|---|
| Group card container | `.regularMaterial`, radius 16, fixed `[0.28,0.06]` stroke, dual shadow inline (351-364) | `VPCard(.raised)` → `.glassSurface(.raised, cornerRadius: .card)`; tier-scaled stroke (top 0.28) + 2-layer stratified shadow from token |
| Poster | 60×90, radius 8, plain `AsyncImage` (281-282) | 96×144, `.surface` glass frame + nested contact shadow; placeholder unchanged |
| Group title | `.headline` (286) | `VPFont.title2`, `textPrimary` |
| Type/count | `GlassTag` blue/purple + `.caption .secondary` (289-297) | `VPBadge(.info/.accent)` glass + `textSecondary` count line |
| Group progress | `GlassProgressBar` 6pt, no label (300-303) | `VPProgressBar(height:10, tint:.live, label:"45% · …")` full-width headline |
| Task row | bare `HStack`, 2-line label, inline 6pt bar wedged mid-stack (370-498) | `VPRow` with leading status glyph, stacked zones, dedicated 8pt labeled progress row |
| Status chip | `GlassTag(status, color)` + `.caption2 .secondary`/`.tertiary` (377-393) | `VPBadge(style: status.badgeStyle)`; metadata at `textSecondary` (0.74) |
| Action buttons | 4× raw `Image` 44×44 in tight HStack(16), equal weight (412-494) | `DownloadTaskActionButtons`: 60pt `VPButtonStyle` primary(play)/secondary(cancel,retry) + spatially separated destructive(delete) |
| Delete-all | `trash.circle.fill` in header corner (310-316) | moved to card footer action row, danger-tinted 60pt, isolated |
| Divider | `Color.primary.opacity(0.2)` (337,345) | glass hairline gradient (`white 0.10→0.02`) |
| Inline error banner | hand-rolled glass (186-197) | `.glassSurface(.surface)` + `VPButtonStyle` retry |
| Empty/error | `CinematicStateCard` 26-radius, 52pt icon, 0.28 art (619-669, 203-248) | `VPStateCard` matching `.raised` card aesthetic, 80pt icon, 0.40 backdrop behind scroll, `VPButtonStyle` actions |

## (d) Specific SwiftUI-level changes (files)

**New files** under `VPStudio/Design/`: `VPDesign.swift`; `Components/GlassSurface.swift`, `VPProgressBar.swift`, `VPBadge.swift`, `VPButtonStyle.swift`, `VPRow.swift`, `VPCard.swift`, `VPStateCard.swift`, `VPBackground.swift`.

**`DownloadsView.swift` (split the 687-line monolith):**
- `Views/Windows/Downloads/Components/DownloadGroupCard.swift` — `mediaGroupCard` (261-368) → `DownloadGroupCard(group:vm:)` using `VPCard(.raised)` + enlarged poster + `VPProgressBar`.
- `.../DownloadTaskRow.swift` — `downloadRow` (370-498) → `DownloadTaskRow` built on `VPRow`.
- `.../DownloadTaskActionButtons.swift` — extract the per-status button set (currently inline 412-494); takes `(task:vm:)`, emits the correct buttons via `VPButtonStyle`, owns the per-task `confirmDeleteTaskID` dialog. Kills the duplicated frame/`contentShape`/`hoverEffect` boilerplate.
- `.../DownloadStateSurfaces.swift` — `downloadsEmptyState` (616-677) + `downloadsErrorState` (200-259) + `downloadsInlineErrorBanner` (172-198) → `VPStateCard`-based.
- `DownloadsView` body keeps lifecycle (`.task`/`onReceive`) + `VPPageShell` + `VPBackground`.

**Move formatting/logic out of the view (reuse):**
- `Models/DownloadStatus+Style.swift`: `extension DownloadStatus { var accentColor: Color; var badgeStyle: VPBadgeStyle; var glyph: String }` — replaces `statusColor(for:)` (572-581), reusable in search/library overlays.
- `Models/DownloadTask+Format.swift`: `var formattedProgress: String` (from `progressText` 583-603) and a shared `ByteCountFormatting` util (from `formatBytes`/the static formatter 605-614).
- Encapsulate scattered `@State` (`confirmDeleteMediaId`, `confirmDeleteTaskID`, `playbackValidationMessage`, `didPerformQADownloadAction`) into a `DownloadsScreenState` `@Observable` passed down, so re-render scope is predictable.

Note: `DownloadsViewModel` data shape is untouched — `posterURL`, `overallProgress`, `hasActiveDownloads`, `completedCount`/`totalCount` already exist, so all new components bind to existing properties.

## (e) visionOS interactions, depth, accessibility / tap targets

- **Tap targets → 60pt.** All four action buttons (currently 44×44, lines 420/437/454/470), the delete-all (icon-only, 313), and any tappable `VPBadge` resolve through `VPButtonStyle`/`VPRow`/`VPBadge` which hard-enforce `minWidth/minHeight: 60`; visible glyph stays ~24pt inside the hit area.
- **Hover (unified).** Group card `.hoverEffect(.lift)` + `VPMotion.hover` scale 1.04 / z-translate 8pt toward viewer; task rows and buttons `.hoverEffect(.highlight)`. Fixes today's inconsistency where badges/progress had no hover.
- **Focus.** Every interactive component renders the accent `selectionRing` on `@Environment(\.isFocused)` (gaze/keyboard) — the screen currently relies on the bare system ring.
- **Depth z-order.** `VPBackground`(z0) → `contentPlane`(z1) → `VPCard .raised`(z2) → poster + `VPRow .surface`(z3, +2pt nested contact shadow for ambient occlusion) → confirmation `VPSheet .modal`(z4). The +2pt nested shadow is what gives the "thickness" the audit found missing.
- **Reduce Motion / Transparency.** Springs → `easeInOut(0.25)`, orbs frozen; `glassSurface` falls back to solid `contentPlane` fill (keep stroke, drop blur) so the dense progress/metadata stays legible.
- **Contrast.** All `.secondary`/`.tertiary`/`.caption2` metadata (status %, file size, "downloaded" count, error text) moves to `VPColor.textSecondary` (0.74 ≥4.5:1) or `danger`; `.tertiary` (0.58) only for non-essential hints.
- **Confirmation dialogs** (319-333, 478-493) move into `VPSheet`/`.modal` glass with an icon + `VPRow` actions so destructive flows match the cinematic language instead of plain system text.
- **Ornaments.** The group-level "delete all" and any screen-level bulk action move to a `.ornament` on the card/page bottom edge, keeping the content plane uncluttered.

## (f) Code-structure improvements driven by this screen

1. Split the 687-line `DownloadsView` into `DownloadGroupCard` / `DownloadTaskRow` / `DownloadTaskActionButtons` / `DownloadStateSurfaces` (testable, reusable, single-responsibility).
2. Promote `statusColor`/`progressText`/`formatBytes` to model extensions + a shared `ByteCountFormatting` util — removes view-private duplication and unlocks reuse in library/search/history.
3. Replace the three hand-rolled glass treatments (group card, inline error banner, and the would-be button styles) with one `.glassSurface(...)` call each — eliminates this screen's slice of the 41 inline strokes / 15+ shadow pairs.
4. Extend `VPProgressBar` with the inline-label capability the task rows currently fake with a separate `Text(progressText)`, removing manual placement logic.
5. Consolidate the four scattered `@State` flags into one `DownloadsScreenState` `@Observable` for predictable invalidation.

**Build/migration order (by impact):** (1) `VPDesign.swift` tokens + `GlassSurface`. (2) `VPProgressBar`, `VPBadge`, `VPButtonStyle` (leaf). (3) `DownloadStatus+Style` / `DownloadTask+Format` extensions. (4) `DownloadTaskActionButtons` + `DownloadTaskRow` (biggest readability + tap-target win). (5) `DownloadGroupCard` with enlarged poster + headline progress. (6) `VPStateCard` empty/error continuity. (7) `VPPageShell` + `VPBackground` wrapper, delete `VPMenuBackground` usage.

Key files: `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Downloads/DownloadsView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/ViewModels/Downloads/DownloadsViewModel.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/GlassCard.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Models/DownloadTask.swift`; new code under `/Users/brendan/Developer/VPStudio/VPStudio/Design/` and `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Downloads/Components/`.

## Screen: library

I now have full ground truth. I have the exact current implementations of every Library element: the header (lines 721-757), actionRow + actionCapsuleLabel (0.14 tint / 0.22 stroke), folderControls with 28pt GlassIconButtons, the two folderChip overloads (opaque vpRed selected, ~32-36pt), GlassPillPicker (opaque vpRed pill), MediaCardView (170×255, radius 20, hover-only shadow), LibraryEmptyStateView, LoadingOverlay, AppErrorInlineView, and VPMenuBackground. I have everything needed to write a precise, implementable spec.

---

# Library Screen Redesign — "Obsidian Glass"

Concrete migration of `LibraryView` and its components onto the VPDesign system. Ordered by impact. All file paths absolute. Line numbers reference current `main`.

---

## A. New Layout & Hierarchy (the intended look)

The Library becomes a **single framed glass window** floating on the obsidian world, with three clearly-stratified depth tiers instead of today's flat sea of capsules.

**Top to bottom:**

1. **`VPPageShell` window** (radius `.window` = 28, `.raised`) wraps the whole screen so Library reads as an immersive Codex-style panel, not loose chrome on a gradient. `VPBackground` (replacing `VPMenuBackground`) sits behind it with a radial `contentPlane` lift so posters and metadata always have a brighter bed.

2. **Header band** (`VPSpace.hero` = 48 top padding, `VPSpace.roomy` = 24 internal rhythm):
   - **Title cluster** — `VPFont.title1` ("Watchlist") with a `VPBadge(.metric)` count chip ("128 titles") beside it. The current sort is now *surfaced here* as a second `VPBadge(.neutral, icon: "arrow.up.arrow.down")` reading "Recently Added" so the user sees sort state at a glance (fixes audit readability #7 / topProblem #5).
   - **Primary actions move to a bottom `.ornament`.** Sort / Import / Export / Refresh leave the inline horizontal scroll and become an ornament strip pinned to the window's bottom edge — declutters the content plane and gives them real 60pt targets (visionOS §4). On macOS they fall back to a toolbar row of `VPButton(role: .secondary)`.
   - **Tab selector** — `VPSegmentedControl` (the migrated `GlassPillPicker`) with `VPSpace.snug` (12pt) breathing room above and below so it stops merging with neighbors (glassGap #7). Selected segment = frosted glass + accent ring + glow, never an opaque red slab.
   - **Folder rail** (when `supportsFolders`) — a `VPChipRail` of `VPChip` folder pills at 60pt, selected chip = glass + red ring (not opaque red), with a trailing `+` and contextual trash as 60pt `VPButton(role: .icon)`.
   - **Status / error** — a single `VPStatusStrip` (`.surface` glass, tinted by severity) replaces the naked `.caption` Text and the background-less `AppErrorInlineView`.

3. **Content plane** — the `LazyVGrid` of `MediaCardView` posters, now each card with a **resting** shadow and depth, sitting visibly *inside* the window (nested `.surface`-on-`.raised` ambient-occlusion).

4. **Empty / loading / error** — all three route through one `VPStateCard` so an empty Watchlist looks like the same screen, just quiet.

**Spatial logic:** `VPBackground` (z0) → `VPPageShell` window glass `.raised` (z2) → tab/folder/status chrome `.surface` (z3, +2pt nested contact shadow) → poster cards `.surface` with resting depth (z3) → ornament action bar `.overlay` (z5, nearest). One light, top-left; shadows fall down-right.

---

## B. Design-System Components & Tokens Used

**Tokens (`Design/VPDesign.swift`):** `VPColor.{void, abyss, contentPlane, accent, accentGlow, textPrimary/Secondary/Tertiary, glassFillHover, success, warning, danger, info}`, `VPFont.{title1, sectionHeader, label, caption, captionEmph, micro}`, `VPSpace.{snug, normal, roomy, section, hero}`, `VPRadius.{chip, control, card, window, pill}`, `VPElevation.{surface, raised, overlay}`, `VPMotion.{settle, hover, snap, ambient}`.

**Components consumed by Library:**
| Component | Replaces in Library |
|---|---|
| `glassSurface(_:cornerRadius:tint:)` | The 6 inline specular strokes + dual shadow pairs across actionCapsuleLabel, folderChip, pill, empty state, loading overlay, MediaCard |
| `VPPageShell` | (new) the missing window frame |
| `VPBackground` | `VPMenuBackground()` at line 602 |
| `VPButtonStyle` (`.secondary`,`.icon`,`.primary`,`.destructive`) | `actionCapsuleLabel`, the two `GlassIconButton`s, `SpatialButton` in empty state |
| `VPSegmentedControl` | `GlassPillPicker` (line 734) |
| `VPChip` + `VPChipRail` | both `folderChip` overloads (lines 908-944) |
| `VPBadge` | `GlassTag` count (line 727); new sort badge; rating badges in card |
| `VPStatusStrip` | feedback block (lines 743-752) + `AppErrorInlineView` |
| `VPStateCard` | `LibraryEmptyStateView` + `LoadingOverlay` surface |
| `VPProgressBar` | `MediaCardView.resumeProgressBar` (lines 172-184) + `GlassProgressBar` |

---

## C. Before → After (each major element)

**Header container**
- Before: `VStack(spacing:12)` with `.horizontal,20 / .top,14 / .bottom,10` padding, no background, sitting directly on the gradient (sharp contrast, glassGap #1).
- After: header lives inside `VPPageShell`; spacing `VPSpace.roomy`(24); padding `.horizontal VPSpace.roomy`, `.top VPSpace.hero`(48). Header inherits the window's `.raised` glass so there's no contrast cliff.

**Title + count**
- Before: `Text(displayName).font(.headline)` + `GlassTag("\(count) titles", "film")`.
- After: `Text(displayName).font(VPFont.title1).foregroundStyle(VPColor.textPrimary)` + `VPBadge("\(count) titles", style: .metric, icon: "film")` + new `VPBadge(sortOption.displayName, style: .neutral, icon: "arrow.up.arrow.down")`.

**Action buttons (Sort/Export/Import/Refresh)**
- Before: `actionCapsuleLabel` — `.subheadline.semibold`, `14×10` padding (~44pt), `.regularMaterial` + `tint.opacity(0.14)` fill + `white.opacity(0.22)` stroke + single shadow. Inline horizontal scroll. Styling lives 130 lines from creation.
- After: each becomes `Button{…}.buttonStyle(VPButtonStyle(role:.secondary, tint: action.tint))` — 60×60 min, `.surface` glass with `tint.opacity(0.16)` (vibrant, not 0.14 mud), unified specular stroke via `glassSurface`, hover-lift + focus ring. Hosted in a bottom `.ornament` (`VPActionBar`). Sort keeps its `Menu`; its 60pt `VPButton` label shows the current option inline.

**Tab picker**
- Before: `GlassPillPicker` — selected pill is opaque `Color.vpRed` (line 64), flush against neighbors.
- After: `VPSegmentedControl` — selected segment renders `glassFillHover` + `accent` `strokeBorder(1.5)` + `accentGlow` shadow via `matchedGeometryEffect`; `VPSpace.snug` margins; `.snap` animation. Glass preserved (glassGap #2, topProblem #3).

**Folder chips**
- Before: two `folderChip` overloads, `10×7` padding (~32-36pt), selected = opaque `Color.vpRed` + white text, `white.opacity(0.16)` stroke. Drag-drop with no visible affordance.
- After: one `VPChip(title:isSelected:onTap:)`; `.frame(minHeight:60)`, `VPFont.label`, `.surface` glass; selected = glass + `accent` ring + `accentGlow` (matches the new tab look). Drag handle dot + `.draggable`/`.dropDestination`; `.hoverEffect(.highlight)` + focus ring. `LibraryFolder` overload becomes a thin `init(folder:)` convenience — no duplicated padding logic.

**Folder +/trash buttons**
- Before: `GlassIconButton(size: 28)` — sub-minimum, icon container == hit area.
- After: `VPButton(role:.icon)` 60×60 hit target, 24pt glyph centered, `.surface` glass, focus ring, haptic on create/delete success.

**Status / error**
- Before: `Text(status).font(.caption).foregroundStyle(.secondary)` (lost in noise) OR `AppErrorInlineView` with no background.
- After: `VPStatusStrip(message:)` — `.surface` glass pill, icon + `VPColor.textSecondary` (0.74, was failing 0.4–0.5 contrast), severity tint (`info`/`warning`/`danger`). Transitions with `.settle`.

**MediaCardView**
- Before: radius 20; resting shadow only `0.15/6pt`, jumps to `0.35/16` on hover; metadata at `white.opacity(0.4/0.5/0.3)` (fails contrast); `resumeProgressBar` raw `Capsule` white fill.
- After: radius `VPRadius.card`(22); `glassSurface(.surface)` resting depth (`0.18/8 + contact`), `.overlay`-tier shadow on hover via `VPMotion.hover`; metadata → `VPColor.textSecondary`/`textTertiary`; rating chip → `VPBadge`; resume bar → `VPProgressBar(tint:.live, height:6)` with specular highlight.

**Empty / Loading**
- Before: bespoke `LibraryEmptyStateView` (`.regularMaterial`, radius 20, 72pt icon, 40pt symbol) and `LoadingOverlay` (radius 16) — different weights, both duplicate the dual shadow.
- After: both `VPStateCard(.empty/.loading, …)` at `.raised`, radius `.card`(22), 80pt icon, accent glow, backdrop art at 0.40 — same aesthetic as content (continuity).

**Background**
- Before: `VPMenuBackground()` — `0.02–0.09` muddy gradient + 3 orbs.
- After: `VPBackground()` — `void→abyss` + tokenized orbs (`ambient` motion) + radial `contentPlane` lift behind the grid + edge vignette.

---

## D. SwiftUI-Level Changes (files to modify, components to introduce)

**New files (build order):**
1. `VPStudio/Design/VPDesign.swift` — all token enums.
2. `VPStudio/Design/Components/GlassSurface.swift` — `GlassSurface` modifier + `VPShadowStack`.
3. `VPStudio/Design/Components/VPButton.swift` — `VPButtonStyle`, `VPButtonRole`.
4. `VPStudio/Design/Components/VPBadge.swift`, `VPProgressBar.swift`.
5. `VPStudio/Design/Components/VPChip.swift` (`VPChip` + `VPChipRail`), `VPSegmentedControl.swift`, `VPStatusStrip.swift`.
6. `VPStudio/Design/Components/VPStateCard.swift`, `VPPageShell.swift`, `VPBackground.swift`.
7. `VPStudio/Views/Windows/Library/LibraryActionBar.swift` — the `.ornament` action strip (extract from `actionRow`).
8. `VPStudio/Views/Windows/Library/LibraryFolderRail.swift` — extract `folderControls` (lines 770-826) into its own view taking a reorder-policy dependency.
9. `VPStudio/Views/Windows/Library/CreateLibraryFolderSheet.swift` — **extract the 110-line nested struct out of `LibraryView`** (codeStructure #5) so the 1482-line parent stops recompiling on its state changes; wrap it in `VPSheet`.

**`LibraryView.swift` edits:**
- Line 602: `VPMenuBackground()` → `VPBackground()`.
- Lines 514-595 `body`: wrap content in `VPPageShell(title: selectedList.displayName) { … }`.
- Lines 721-757 `header`: split into `LibraryTitleRow` (title + count + sort badges), keep `VPSegmentedControl`, delegate folder UI to `LibraryFolderRail`, status to `VPStatusStrip`. Remove `actionRow` from header; attach `LibraryActionBar` via `.ornament(attachmentAnchor: .scene(.bottom))`.
- Lines 759-768 `actionRow` + 889-906 `actionCapsuleLabel`: delete; logic moves to `LibraryActionBar` using `VPButtonStyle`. Keep `LibraryActionRowPolicy` as the action-spec source of truth; add `tint` to `LibraryHeaderActionSpec` so the switch at 846-887 collapses to one `ForEach`.
- Lines 908-944 both `folderChip` overloads: delete; replaced by `VPChip`.
- Lines 734-737: `GlassPillPicker` → `VPSegmentedControl` (same `$selectedList` binding).
- Lines 519-540: loading/empty branches call `VPStateCard`.

**Component file edits:**
- `MediaCardView.swift` lines 26, 41-56, 94-143, 172-184: radius→`VPRadius.card`; `glassSurface(.surface)` resting; tokenized text; `VPBadge` rating; `VPProgressBar` resume.
- `GlassCard.swift`: keep `FlowLayout`, `ArtworkFallbackPosterView`. Deprecate `GlassTag`/`SpatialButton`/`GlassIconButton`/`GlassProgressBar`/`glassStroke`/`glassShadow`/`glassCard` once call sites migrate; `CinematicStateCard` radius 26→22, folds into `VPStateCard`.
- `LibraryEmptyStateView.swift`, `AsyncStateViews.swift` (`LoadingOverlay`, `AppErrorInlineView`): re-implement atop `VPStateCard`/`VPStatusStrip`.
- `LibraryGridPolicy.swift`: wire the unused `columns(containerWidth:)` (line 8) to drive the grid instead of the hardcoded `.adaptive(minimum:180)` at line 545, killing the dead-code/inconsistency (codeStructure #10).

---

## E. visionOS Interactions, Accessibility & Tap-Target Fixes

- **60pt everywhere.** `VPButtonStyle`, `VPChip`, `VPSegmentedControl` segments, and folder icon buttons hard-enforce `minWidth/minHeight: 60`. Resolves: folder chips ~32-36pt, action buttons ~44pt, `GlassIconButton` 28pt (visionOS #1-2, topProblem #2). Glyphs stay small (24pt) inside the 60pt zone.
- **Focus rings.** Every interactive component renders the accent `selectionRing` on `@Environment(\.isFocused)` — folder chips, tabs, action/icon buttons, cards. Fixes "no explicit focus()" (visionOS #3).
- **Hover language.** Cards/buttons/tabs → `.hoverEffect(.lift)` + `VPMotion.hover` (scale 1.04, z +8pt). Chips/status → `.hoverEffect(.highlight)`. Sort/Import buttons get a hover preview label.
- **Drag affordance.** `VPChip` shows a grip-dot when reorderable and uses `.draggable`/`.dropDestination` (modern API) instead of the closure-coupled `FolderChipDropDelegate`, disambiguating drag vs context-menu (visionOS #5).
- **Haptics.** `VPMotion`-paired feedback on folder reorder commit, create success, and remove (visionOS #6).
- **Loading safe areas.** `VPStateCard` loading variant respects `.safeAreaPadding` so it can't collide with the persistent header (visionOS #7).
- **Reduce Motion / Transparency.** `glassSurface` falls back to solid `contentPlane` fill (stroke kept) under `reduceTransparency`; springs → `easeInOut(0.25)` and orb `ambient` disabled under `reduceMotion` (already partly honored in `LoadingOverlay` lines 22-27 / 57-60).
- **Contrast.** All metadata moves off `white.opacity(0.3–0.5)` to `VPColor.textSecondary`(0.74)/`textTertiary`(0.58 floor), guaranteeing ≥4.5:1 (visionOS #8, glassGap, MediaCard lines 104-140).

---

## F. Code-Structure Improvements (this screen)

- **Decompose the 1482-line god view.** Extract `CreateLibraryFolderSheet`, `LibraryFolderRail`, `LibraryActionBar`, and a `LibraryTitleRow` into their own files (topProblem #1, codeStructure #1/#5) — design tweaks stop rippling through the whole file and the parent stops recompiling on sheet state.
- **Kill duplication.** One `VPChip` ends the two-overload folderChip duplication (codeStructure #4); `VPButtonStyle` ends the actionCapsuleLabel-far-from-creation split; the action switch (846-887) collapses to a tinted `ForEach` once `tint` is on the spec.
- **Decouple reordering.** `LibraryFolderRail` takes `LibraryFolderReorderPolicy` as an injected dependency; the duplicated `reorderedIDs()`/`commitFolderReorder()` call paths (codeStructure #2) consolidate into one commit path the rail owns.
- **Wire dead policy.** `LibraryGridPolicy.columns(containerWidth:)` becomes the single grid-sizing source, removing the hardcoded `.adaptive(minimum:180)` inconsistency.
- **Testability.** New components are leaf views with pure inputs; existing `LibraryViewPolicyTests` / `LibraryHeaderConsistencyTests` extend to cover the extracted `LibraryActionBar` spec mapping and `VPChip` selected-state rendering (codeStructure #7).

**Highest-impact first:** (1) `VPDesign.swift` + `glassSurface`; (2) `VPButtonStyle`/`VPChip`/`VPSegmentedControl` → fixes every tap-target + the opaque-red glass break in one pass; (3) `VPPageShell` + `VPBackground` → the window frame and depth grading; (4) `MediaCardView` resting depth + contrast; (5) `VPStateCard`/`VPStatusStrip`; (6) extract `CreateLibraryFolderSheet`/`LibraryFolderRail`/`LibraryActionBar` for the structural win.

Relevant files: `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Library/LibraryView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/MediaCardView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/GlassCard.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/GlassPillPicker.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/AsyncStateViews.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Library/LibraryEmptyStateView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Library/LibraryGridPolicy.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/VPMenuBackground.swift`. New: `/Users/brendan/Developer/VPStudio/VPStudio/Design/VPDesign.swift` (+ `Design/Components/*`), and extracted `Library/{CreateLibraryFolderSheet,LibraryFolderRail,LibraryActionBar}.swift`.

## Screen: explore

I now have a complete, precise picture of the screen. I have all the concrete numbers, file locations, line ranges, and component structures needed. Here is the redesign spec.

---

# VPStudio Explore/Search — "Obsidian Glass" Redesign Spec

Ordered by impact. Every change maps to the `Obsidian Glass` token file (`Design/VPDesign.swift`) and the 11-component library; nothing introduces new ad-hoc primitives. Concrete file/line anchors throughout.

---

## (a) New layout & hierarchy — the intended look

The Explore tab becomes a single vertically-stratified **glass column** floating on the obsidian world, with three depth tiers that never blur into each other:

1. **Header zone (z1, on `contentPlane`)** — "Explore" hero title (`displayHero`/40) over a single supporting line. Below it, one **search row** at a real input height (60pt) containing the query field, the "Curate For Me" pill, and the filter button — all the same height, all reading as a cohesive control cluster, not three mismatched sizes.
2. **Filter strip (z3 nested in z2)** — the All/Movies/TV segmented control rendered as a real glass segment (material backing + sliding accent indicator), with the active-filter summary chips wrapping below it as `.surface`-glass badges with a red glow on removable ones.
3. **Content plane (z1→z2)** — Recent searches as a distinct `VPCard`, visually separated from the genre wall by a real card edge (not just 32pt of air). The genre wall keeps its 7-up poster grid but on a calmer 2-stop stroke, on `.adaptive` columns so it breathes on wide visionOS displays. Results grid sits in the same card rhythm.

The whole screen reads as **one premium dark surface with graded depth**, a single light from top-left, restrained red used only for selection/CTA — instead of today's mix of cyan toggles, multicolor filter chips, and 14pt hit targets.

---

## (b) Design-system components & tokens it consumes

| New DS element | Replaces (current) |
|---|---|
| `VPColor` / `VPFont` / `VPSpace` / `VPRadius` | 29 inline opacities, `.system(size:)` literals (34/18/16/12/11.5/11/10/9/8.5pt), radii 11/14/16/17/20/26, paddings 24/26/34/40 |
| `glassSurface(_:cornerRadius:tint:)` (§3.1) | every inline `Capsule().fill(.white.opacity)…overlay(stroke)…shadow` cluster: search bar (1358-1379), AI pill (492-513), filter button (534-554), type-filter track (770-791), summary chips (741-757), recent chips (85-92) |
| `VPButtonStyle` (`.primary/.secondary/.tertiary/.icon`) | `askAIButton`, `filterUtilityButton`, `GlassIconButton`, `SpatialButton`, `Clear All` button |
| `VPSegmentedControl` (new thin wrapper over `VPButtonStyle` selected-state, or part of §3.3) | `typeFilterSection` + `typeFilterButton` (762-818) |
| `VPBadge` (`.neutral/.accent/.info/.metric`) | `GlassTag`, `InlineFilterChip`, `compactSummaryChip`, AI-pick score tag |
| `VPRow` | `LanguageToggleRow` (filter sheet), language `Menu` items |
| `VPSectionHeader` | "Recent" header (RecentSearchesSection 11-39), "Browse by Genre & Mood" (ExploreGenreGrid 33-35), "AI Picks" label (1103) |
| `VPCard` | Recent-searches container, genre-wall container, AI-picks rail container |
| `VPStateCard` (`.empty/.error`) | `CinematicStateCard` → `ExploreEmptyView` / `ExploreErrorView` |
| `VPSheet` + `VPPageShell` | `ExploreFilterSheet`'s system `Form` (46-85) |
| `VPProgressBar` | `GlassProgressBar`, AI/search inline loading |
| `VPBackground` | `VPMenuBackground` |
| `VPMotion` | the scattered `.spring(response:0.28/0.3)`, `.easeInOut(0.18/0.2/0.25)` literals |

A reusable `VPCloseButton` (60pt hit area, 20pt glyph, `.surface` glass, `textSecondary` glyph) is the canonical fix for the three different "x" buttons (recent chip 8.5pt, search clear 14pt frame, AI-picks clear).

---

## (c) Before → After, each major element

**1. Recent-search chip close button — the critical fix**
- Before: `xmark.circle.fill` at `8.5pt`, `.white.opacity(0.26)`, no background; whole remove tap lives in an implicit ~17pt box (RecentSearchesSection 74-78). **14pt-class target, 78% under HIG.**
- After: `VPCloseButton` — 60×60 hit area, 20pt glyph at `VPColor.textSecondary`, `.surface` glass capsule, `.hoverEffect(.highlight)` + focus ring. The chip itself becomes a `VPButtonStyle(.tertiary)` pill (`label` font, `textPrimary`, `minHeight 60`). Term tap and remove tap are two clearly separated 60pt zones.

**2. Search clear button**
- Before: 14×14 frame, `xmark.circle.fill` 12pt at opacity `0.28` (SearchView 1335-1340). Sub-target + low contrast.
- After: same `VPCloseButton`, sized to sit inside the 60pt search row's trailing inset; glyph `textSecondary` (0.74), 60pt hit area.

**3. Search bar**
- Before: `Capsule().fill(.white.opacity(0.095))` + top gradient + 0.09 hairline + single 0.14/6 shadow; 8pt vertical padding → ~30pt tall (1358-1379). Placeholder/leading glass at `0.52`.
- After: `.glassSurface(.surface, cornerRadius: .pill)` with `minHeight 60`; leading magnifier and placeholder at `VPColor.textSecondary`; field text `textPrimary`. Reads as a genuine input surface with graded stroke + stratified `.surface` shadow.

**4. "Curate For Me" (Ask AI) pill**
- Before: bespoke capsule, cyan-tinted gradient, `0.10` fill, manual shadow (492-516); ~32pt tall.
- After: `VPButtonStyle(.secondary)` with leading `sparkles`, `accent`-tinted (not cyan) so the AI affordance aligns with the one accent language; 60pt height; loading state swaps glyph for `ProgressView`. Drops bespoke gradient.

**5. Filter button**
- Before: 44×44 frame, gear 12pt at `0.72`, radius-11 glass, red count capsule offset (525-565).
- After: `VPButtonStyle(.icon)` at 60×60, 22pt gear glyph `textPrimary`; the count becomes a `VPBadge(.accent)` dot anchored top-trailing (tokenized, not raw `Color.red`).

**6. Type filter (All / Movies / TV Shows)**
- Before: three inline buttons in a 400pt capsule; selected = opaque bright **cyan** slab `(0.46,0.93,0.95)` with black text, no material, glow only (762-818). Flat, off-palette, ~22pt tall, low discoverability.
- After: `VPSegmentedControl` — `.surface` glass track, a sliding selected indicator that is **glass + accent stroke + `accentGlow`** (never an opaque slab), labels in `label` font (`textPrimary` selected / `textSecondary` idle), each segment a 60pt hit zone, `VPMotion.snap` slide. Cohesive with everything else; cyan retired.

**7. Active-filter summary chips**
- Before: `compactSummaryChip` multicolor tints — orange genre, green sort, blue language, red clear, each `0.22-0.28` capsule + top gradient (655-758); plus a parallel `activeFilterSummary` using `GlassTag` (923-950). Two code paths, weak hierarchy.
- After: one `FilterChipStack` of `VPBadge`s. Removable chips (genre, clear) are `VPButtonStyle(.tertiary)` wrapping a `VPBadge(.accent)` with a trailing `xmark` and a 60pt tap zone + red glow ring; informational chips (sort, language, year) are `VPBadge(.neutral/.metric)`. Color now signals **removable vs. informational**, not arbitrary hue. Single render path replaces both `compactFilterSummaryRow` and `activeFilterSummary`.

**8. Genre/mood tiles**
- Before: 5-stop spec stroke with `.screen` blend (ExploreGenreGrid 73-88), radius 17, near-zero shadow `0.012/0.35` (89). Over-engineered, flat depth.
- After: `tileShape` radius → `VPRadius.card` (22); stroke → the **2-stop `glassSurface(.raised)` specular gradient** (`strokeTop 0.28 → 0.06`, `.normal` blend); add `.raised` stratified shadow so tiles read with real lift. `.hoverEffect(.lift)` + `VPMotion.hover` scale 1.04 + z-translate 8 + focus ring. The `#if os(visionOS)` hover fork (94-103) moves into a shared `.vpInteractive()` modifier.

**9. Recent-searches section separation**
- Before: only 32pt spacing between Recent and genre grid (SearchView 832); no card edge.
- After: Recent searches wrapped in `VPCard(.raised)` with `VPSectionHeader("RECENT", action: clearAll)`; genre wall in its own `VPCard(.raised)`. Two distinct planes, `VPSpace.section` (32) between — the separation now reads structurally.

**10. AI Picks rail**
- Before: `AIRecommendationCard` = `.regularMaterial` + `glassStroke` + `glassShadow`, 210pt fixed, purple `GlassTag` score; header `Label` in `.purple` (1100-1141).
- After: card → `.glassSurface(.raised, cornerRadius: .card)`; score → `VPBadge(.metric)`; section header → `VPSectionHeader("AI PICKS", icon: "sparkles")` in `accent` (one accent, drop purple); clear → `VPCloseButton`. Sits in a `VPCard` rail so it matches the genre/recent rhythm.

**11. Filter sheet**
- Before: system `Form` with default iOS section styling, `LanguageToggleRow` plain rows (ExploreFilterSheet 45-108). Breaks the cinematic look entirely.
- After: `VPSheet { VPPageShell(title: "Filters") { … } }` on `.modal` glass over `VPBackground`. Genre/Sort/Year become `VPRow` pickers inside `VPCard(.raised)` groups under `VPSectionHeader`s; languages become `VPRow`s with a trailing `checkmark` in `accent`, 60pt rows, hover + focus. Apply/Cancel move to an `.ornament` at the bottom edge.

**12. Empty / Error states**
- Before: `CinematicStateCard` radius 26, backdrop `0.28`, 50pt icon circle, `SpatialButton` actions (AsyncStateViews 311-397; GlassCard 439-494).
- After: `VPStateCard(.empty/.error)` — `.raised` glass (same aesthetic as normal cards, no continuity break), backdrop `0.40`, 80pt icon, narrative copy in `textSecondary`, actions as `VPButtonStyle(.primary/.secondary)`. Radius → `VPRadius.card` (22).

**13. Background**
- Before: `VPMenuBackground` gradient + 3 orbs + flat bottom darkening (VPMenuBackground 13-53).
- After: `VPBackground` — `void→abyss` gradient, same 3 orbs (now `VPColor.orbBlue/Purple/Green`) with `VPMotion.ambient` drift, **plus a radial `contentPlane` lift + edge vignette** behind the scroll region so the genre-subtitle and metadata text sit on a brighter bed.

**14. Text contrast pass (kills the readability flags)**
- `searchShellSubtitle` `0.32`→`textSecondary` (0.74) (SearchView 427); shell title `0.56`→`textSecondary` (423); placeholder/leading `0.52`→`textSecondary` (1290, 1301); recent term `0.78`→`textPrimary`; all chip text `0.82`→`textPrimary`. One opacity per element, from a token — no more opacity cascading.

---

## (d) SwiftUI-level changes — files & order

**New files (build first, per the §"Build order"):**
1. `VPStudio/Design/VPDesign.swift` — `VPColor`, `VPFont`, `VPSpace`, `VPRadius`, `VPElevation`, `VPShadow`, `VPMotion`.
2. `VPStudio/Design/Components/GlassSurface.swift` — `GlassSurface` modifier + `VPShadowStack` + `glassSurface(_:cornerRadius:tint:)` + a `.vpInteractive(_:)` modifier (folds `.hoverEffect` + scale/z-lift + focus ring + `reduceMotion`/`reduceTransparency` fallbacks, replacing every `#if os(visionOS) .hoverEffect` fork on this screen).
3. `VPStudio/Design/Components/VPButtonStyle.swift`, `VPBadge.swift`, `VPProgressBar.swift`, `VPCloseButton.swift`, `VPSegmentedControl.swift`.
4. `VPStudio/Design/Components/VPRow.swift`, `VPSectionHeader.swift`, `VPCard.swift` (+ `VPPageShell`).
5. `VPStudio/Design/Components/VPStateCard.swift`, `VPSheet.swift`, `VPBackground.swift`.

**Modified files:**
- `SearchView.swift` (1527 lines) — the big one. Concretely:
  - `searchBarSection` (413-454): titles → `VPFont`/`VPColor`; the `HStack` becomes a fixed-60pt control row.
  - Delete `askAIButton` body internals (472-524) → `VPButtonStyle(.secondary)`; delete `filterUtilityButton` internals (525-574) → `VPButtonStyle(.icon)` + `VPBadge`.
  - Replace `typeFilterSection` + `typeFilterButton` (762-818) with one `VPSegmentedControl(selection: $viewModel.selectedType, …)` — **extract to `SearchTypeFilter.swift`**.
  - Replace `compactFilterSummaryRow` + `compactSummaryChip` + `activeFilterSummary` + `chipDivider` + `InlineFilterChip` (596-758, 923-950, 1424-1457) with one **`FilterChipStack.swift`** driven by a `[FilterChip]` model — collapses two summary code paths into one.
  - `SearchQueryBar` (1239-1386): background → `.glassSurface(.surface, .pill)`, `minHeight 60`; `leadingIndicator`/`draftField`/`clearButton` colors → tokens; `clearButton` → `VPCloseButton`.
  - `SearchResultsGrid.columns` (1398): keep `.adaptive` but token the spacing (`VPSpace.snug`) — already adaptive, good; just widen `maximum` for visionOS.
  - Extract `SearchLanguageOption.common` (1468-1488) → a `languages.json`/`SearchLanguageCatalog` loaded once (i18n + shrinks the file).
- `RecentSearchesSection.swift`: header → `VPSectionHeader`; `RecentSearchChip` → `VPButtonStyle(.tertiary)` + `VPCloseButton`; export `RecentSearchChip` (un-`private`) so it's testable. Wrap section in `VPCard`.
- `ExploreGenreGrid.swift`: `cornerRadius` 17→`VPRadius.card`; replace 5-stop stroke + micro-shadow (73-89) with `.glassSurface(.raised, cornerRadius: .card)` over the clipped image; header → `VPSectionHeader`; hover fork (94-103) → `.vpInteractive(.lift)`; move `columns/tileWidth/spacing` constants into a DS token struct.
- `ExploreFilterSheet.swift`: replace `Form` (46-85) with `VPSheet`/`VPPageShell` + `VPCard` groups + `VPRow` pickers; `LanguageToggleRow` → `VPRow`; Apply/Cancel → `.ornament`.
- `AIRecommendationCard.swift`: `.regularMaterial`+`glassStroke`+`glassShadow` (44-46) → `.glassSurface(.raised, cornerRadius: .card)`; score `GlassTag` → `VPBadge(.metric)`.
- `AsyncStateViews.swift`: `ExploreErrorView`/`ExploreEmptyView` (311-397) → `VPStateCard`; `ExploreSkeletonView` radii 16→`VPRadius.card`.
- `GlassCard.swift` (577 lines): after migration, **delete** `GlassTag`, `SpatialButton`, `GlassIconButton`, `GlassProgressBar`, `CinematicStateCard`, and the `glassStroke/glassShadow/glassCard` extensions (the 4× duplicated specular stroke + dual-shadow). Keep only `FlowLayout`, `ArtworkFallback*`, and the `vpRed`/`vpAccent` tokens (which fold into `VPColor`/`VPDesign`). This resolves the "577-line single-responsibility violation."

---

## (e) visionOS interactions & accessibility / tap-target fixes

- **60pt everywhere.** Enforced structurally via `minWidth/minHeight: 60` baked into `VPButtonStyle`, `VPSegmentedControl` segments, `VPCloseButton`, `VPRow`, interactive `VPBadge`. This single change closes every flagged violation: recent-chip close 14pt, search clear 14pt, filter button 44pt, type-filter ~22pt, genre tile (now explicit), language `Menu` items, AI-picks clear. Visible glyphs stay small (20-24pt) inside the 60pt area.
- **Unified hover/lift/depth via `.vpInteractive`:** cards/tiles/buttons → `.hoverEffect(.lift)` + `VPMotion.hover` scale 1.04 + 8pt z-translate toward viewer; rows/segments/badges → `.hoverEffect(.highlight)`. Replaces the inconsistent `.highlight` vs `.lift` choices and the non-vision `onHover` fork in the genre tile.
- **Focus rings everywhere** (currently absent): every interactive component renders the `accent` selection ring on `@Environment(\.isFocused)` for gaze/keyboard nav — fixes "no focus indicators."
- **Selection legibility:** type filter and removable chips show selection as glass + accent stroke + glow (discoverable, on-palette) instead of opacity-modulated cyan/black text.
- **Reduce Motion / Transparency:** `VPBackground` stops orb drift and `VPMotion` swaps springs for `easeInOut(0.25)` under reduceMotion; `glassSurface` falls back to a solid `contentPlane` fill (keep stroke, drop blur) under reduceTransparency — preserving contrast.
- **Contrast:** every on-glass text token guarantees ≥4.5:1 (`textSecondary` 0.74) with `textTertiary` (0.58) only for non-essential hints; resolves all six readability flags.
- **Depth order:** `VPBackground` (z0) → `contentPlane` (z1) → `VPCard .raised` (z2) → rows/badges/segments `.surface` (z3, +2pt nested contact shadow for ambient occlusion) → filter `.modal` sheet (z4) → hovered tile `.overlay` (z5). The +2pt nested shadow gives the "thickness" the genre wall currently lacks.

---

## (f) Code-structure improvements unlocked here

- **`SearchView.swift` 1527 → ~700 lines** by extracting `SearchTypeFilter.swift` (was inline `typeFilterButton` ×3), `FilterChipStack.swift` (was `compactFilterSummaryRow` + `compactSummaryChip` + `activeFilterSummary` + `InlineFilterChip` — three overlapping chip systems collapsed to one model-driven view), and `SearchQueryBar.swift`.
- **One chip model, one render path** eliminates the divergence between `compactFilterSummaryRow` (tinted capsules) and `activeFilterSummary` (`GlassTag`) — they showed the same filters two different ways.
- **`RecentSearchChip` exported** from `RecentSearchesSection` (currently `private`, 57) so its close-button logic is unit-testable; the existing `RecentSearchesSectionRenderTests` can assert the new 60pt target.
- **`GlassCard.swift` decomposed** — the 577-line grab-bag loses 5 components + 3 extensions to the DS, leaving it a focused `FlowLayout` + fallback-artwork file (or split further: `FlowLayout.swift`, `ArtworkFallback.swift`).
- **Language list externalized** (`SearchLanguageOption.common`, 19 hardcoded rows) → `languages.json`, enabling i18n and removing ~25 lines from the view file.
- **`SearchResultsGrid` columns** already `.adaptive` (good); just token spacing and widen the `maximum` for large visionOS displays.
- **Tokens replace the test-fragile literals** the existing `ExploreGenreGridPolicyTests` / `VPMenuBackgroundIntensityPolicyTests` assert against — update those to read from `VPRadius`/`VPColor` so future spacing/radius tweaks don't silently break rendering tests.

---

**Highest-impact first three to ship:** (1) `VPCloseButton` + 60pt enforcement in `VPButtonStyle` — clears every critical/high tap-target violation in one pass; (2) `VPSegmentedControl` replacing the off-palette cyan type filter; (3) `glassSurface` + token migration of the search bar / AI pill / filter button cluster into one cohesive 60pt control row. These three resolve all five `topProblems` from the audit.

Key files: `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Search/SearchView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Search/RecentSearchesSection.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Search/ExploreGenreGrid.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Search/ExploreFilterSheet.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/GlassCard.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/AsyncStateViews.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/AIRecommendationCard.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/MediaCardView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/VPMenuBackground.swift`. New DS dir to create: `/Users/brendan/Developer/VPStudio/VPStudio/Design/`.

## Screen: discover

I have everything I need. The audit, the spec, and the actual code are all confirmed and precise. Here is the concrete redesign spec.

---

# Discover Screen Redesign — "Obsidian Glass" Applied

Implementable spec, ordered by impact. File paths are absolute. Line references are to the code I re-read.

## (a) New layout & hierarchy — the intended look

The Discover tab becomes a vertically rhythmic, depth-graded **content plane** floating on glossy black. Five concrete z-tiers, top to bottom:

1. **`VPBackground` (z0, far)** — replaces `VPMenuBackground`. Same `void→abyss` gradient and three ambient orbs, but adds a **radial `contentPlane` lift + edge vignette** behind the scroll region so the dim catalog metadata (currently `white.opacity(0.4)` on `0.02–0.09` navy) sits on a brighter bed. Orbs animate with `VPMotion.ambient` and disable under Reduce Motion.

2. **Hero carousel (z5 overlay tier, nearest)** — `FeaturedHeroView` gets a real **`.thinMaterial` glass anchor** behind the backdrop image plus the overlay-tier specular stroke and stratified shadow, fixing the audit's #1 problem ("hero is flat glass, neither material"). The cinematic bottom gradient feathers across **5 stops** instead of 4 hard stops (0.0/0.18/0.45/0.75/1.0) for the sub-pixel smoothing the glassmorphism audit asks for. Title drops the red/white gradient italic (the −12% contrast tax) for **solid `textPrimary`, `VPFont.title1` (30/bold), upright**, with the red reserved as a soft glow shadow only. An **edge vignette** frames the backdrop so it reads "embedded in glass," not a cutout.

3. **Continue Watching + catalog rows (z3 surface, nested in z2 plane)** — `MediaRow` headers gain a real anchor: `VPSectionHeader` with a 36pt glass icon chip and uppercase tracked label, establishing hierarchy *above* the cards rather than floating as bare `.secondary` text (audit visionOS issue #4). Cards keep the 170×255 footprint but route all stroke/shadow/material through `glassSurface(.surface)` and gain a +2pt nested contact shadow for ambient occlusion against the plane.

4. **AI Curated section** — `AICuratedHeroCard` and `FeaturedHeroView` collapse into **one `VPCinematicHero` base** (they're 85% identical per topProblem #4). The AI accent migrates from system `.purple` to the **single VP accent red as a glow** so both focal points share one accent energy (audit color-vibrance issue). Supporting rows become `VPRow` with proper `.surface` glass + focus rings.

5. **Error / empty / loading** — `CinematicStateCard`, `aiCuratedEmptyState` (currently a raw `ContentUnavailableView`), and skeletons unify under `VPStateCard` using the **same `.raised` glass** as normal cards so error states don't feel like a different screen.

Spacing moves to the 8pt grid: the literal `36` section gap → `VPSpace.section` (32), `16`/`14`/`12`/`8` paddings → `VPSpace` tokens, the `.padding(.horizontal, 4)` outer / `8` inner inconsistency resolves to one `VPSpace.normal` content inset.

## (b) New design-system components/tokens used

New file **`/Users/brendan/Developer/VPStudio/VPStudio/Design/VPDesign.swift`** (none exists today — confirmed greenfield) holds the token enums: `VPColor`, `VPFont`, `VPSpace`, `VPRadius`, `VPElevation`/`VPShadow`, `VPMotion`.

Components this screen consumes (under `/Users/brendan/Developer/VPStudio/VPStudio/Design/Components/`):
- `glassSurface(_:cornerRadius:tint:)` + `VPShadowStack` — the one modifier replacing every inline stroke/shadow/material combo on this screen.
- `VPBackground` — replaces `VPMenuBackground`.
- `VPCinematicHero` — new shared base for `FeaturedHeroView` + `AICuratedHeroCard`.
- `VPMetadataRow` — shared year/type/rating bullet row (duplicated 3× today).
- `VPSectionHeader` — row + AI section headers.
- `VPRow` — AI supporting rows + error action rows.
- `VPBadge`/`VPBadgeStyle` — replaces `GlassTag` (AI PICK, % match, HDR, error tags).
- `VPButtonStyle` (roles: primary/secondary/icon) — hero CTA, info button, regenerate, error actions.
- `VPProgressBar` — replaces the bespoke `resumeProgressBar` (MediaCardView.swift:172–184) and `GlassProgressBar`.
- `VPStateCard` — error/empty/loading.

## (c) Before → After for each major element

**Background — `VPMenuBackground` → `VPBackground`**
- Before: gradient + 3 static blurred orbs + flat `0.03→0.18` darken overlay (VPMenuBackground.swift:13–53). No content-plane lift, so body text sits on raw navy.
- After: same orbs but tokenized (`orbBlue/Purple/Green`), `ambient` motion, **radial `contentPlane` highlight behind the scroll + edge vignette**. Reduce Transparency → solid `contentPlane` fill.

**Hero carousel — `FeaturedHeroView` (DiscoverView.swift:924–1112)**
- Before: image + 4-stop gradient + manual hover state + per-call `isHovered` stroke/shadow math (lines 1081–1104); italic 34pt red-gradient title (974–982); 44×44 secondary info button (1056); no material anchor.
- After: `VPCinematicHero(style: .featured)`. `.overlay` glass tier via `glassSurface(.overlay, cornerRadius: VPRadius.card)`; 5-stop feathered cinematic gradient + edge vignette; **solid `textPrimary` `title1` upright title** with red glow shadow only; metadata via `VPMetadataRow`; HDR via `VPBadge`. Primary "View Details" → `VPButtonStyle(.primary)` (accent gradient, ≥60pt). Secondary info → `VPButtonStyle(.icon)` at **60×60** (was 44). Hover/focus handled by the button/surface, deleting the bespoke `isHovered` spring.

**AI hero — `AICuratedHeroCard` (740–857)**
- Before: separate 120-line view, 85% duplicate of hero; `.purple` tags; 4-stop gradient; `white.opacity(0.12)` flat stroke (849); single shadow (851).
- After: `VPCinematicHero(style: .aiPick)` — same base, parameterized for height 236, accent red glow, "AI PICK"/match `VPBadge`. Gains depth via `.raised` glass + stratified shadow (fixes "AI cards lack spatial differentiation").

**Supporting rows — `AICuratedSupportingRow` (860–920)**
- Before: `.regularMaterial` + `glassStroke(18)` + `glassShadow()`; all copy `.secondary` (3 nested levels → "secondary-secondary"); chevron `.secondary`.
- After: `VPRow(title:subtitle:badge:trailing:)`. Title `rowTitle`/`textPrimary`, subtitle `textSecondary` (0.74, was failing ~3.5:1), match `VPBadge(.accent)`, chevron in 36pt glass affordance. `.surface` glass + `.hoverEffect(.highlight)` + focus ring.

**Catalog cards — `MediaCardView` (MediaCardView.swift:1–272)**
- Before: inline 4-way stroke math (44–56), dual shadow (41–42), 48pt play overlay (63), `resumeProgressBar` bespoke (172–184), metadata `white.opacity(0.4/0.5)` (104–123), magic `170/255/20`.
- After: `glassSurface(.surface, cornerRadius: VPRadius.card)` for poster chrome; play overlay → **60pt** hit area (24pt glyph) via `VPButtonStyle(.icon)` semantics; resume bar → `VPProgressBar(value:tint:.live)`; metadata → `VPMetadataRow` with `textSecondary`/`textTertiary`; dims → tokens. `radius 20 → VPRadius.card (22)`.

**Section headers — `MediaRow` header (1132–1144) & AI header (531–587)**
- Before: bare `Image+Text` at `.headline`/`.secondary`, no anchor (visionOS issue #4); AI header uses `.purple` sparkle + ad-hoc capsule regenerate button.
- After: `VPSectionHeader("TRENDING NOW", icon:"flame")` — 36pt glass icon chip, uppercase `sectionHeader` font +0.6 tracking. AI header `action:` slot hosts a `VPButtonStyle(.secondary)` Regenerate (≥60pt, was a ~32pt capsule).

**Error panel — `discoverStatePanel` (441–523) / `CinematicStateCard`**
- Before: `CinematicStateCard` radius 26, artwork `0.28`, 50pt accent circle, close button `xmark.circle.fill` at `.secondary` (~14pt glyph), action `GlassTag` buttons in `FlowLayout`.
- After: `VPStateCard(.error/.setup)` radius `VPRadius.window`, artwork `0.40`, 80pt icon, close → `VPButtonStyle(.icon)` **60×60**, actions → `VPButtonStyle(.primary/.secondary)`.

**Empty state — `aiCuratedEmptyState` (634–646)**
- Before: system `ContentUnavailableView` in `.regularMaterial` — breaks cinematic aesthetic.
- After: `VPStateCard(.empty, icon:"sparkles.tv", ...)` matching card glass.

## (d) SwiftUI-level changes — files & order

1. **Create** `VPStudio/Design/VPDesign.swift` (token enums) and `VPStudio/Design/Components/GlassSurface.swift` (`GlassSurface` modifier + `VPShadowStack`). This is the prerequisite for everything.
2. **Create leaf components** `VPBadge.swift`, `VPProgressBar.swift`, `VPButtonStyle.swift`.
3. **Create** `VPMetadataRow.swift`, `VPSectionHeader.swift`, `VPRow.swift`, `VPStateCard.swift`, `VPCinematicHero.swift`, `VPBackground.swift`.
4. **Edit `DiscoverView.swift`:**
   - `body` `.background { VPMenuBackground() }` (352) → `VPBackground()`; spacing `36`→`VPSpace.section`; outer/inner padding to one `VPSpace.normal` inset.
   - Delete `FeaturedHeroView` (924–1112) and `AICuratedHeroCard` (740–857); replace both call sites (305, 598) with `VPCinematicHero`.
   - Replace `AICuratedSupportingRow` (860–920) body with `VPRow`.
   - `MediaRow` header (1132–1144) → `VPSectionHeader`; the AI section header (531–587) likewise, with Regenerate as `VPButtonStyle(.secondary)`.
   - `discoverStatePanel` (441–523) → build on `VPStateCard`; `aiCuratedEmptyState` (634–646) → `VPStateCard(.empty)`; `aiCuratedLoadingView` `SkeletonBlock` radii `22/16` → `VPRadius.card/.control`.
5. **Edit `MediaCardView.swift`:** replace inline stroke/shadow/overlay (41–73) with `glassSurface(.surface)` + tokenized play overlay; `resumeProgressBar` (172–184) → `VPProgressBar`; metadata opacities (104–123) → text tokens; hoist `170/255/20` into a small `VPCardMetrics` or `VPSpace`/`VPRadius` use.
6. **Edit `GlassCard.swift`:** keep `vpRed`/`vpRedLight`/`vpAccent` (move into `VPColor` and re-export), delete `glassStroke`/`glassShadow`/`glassCard`/`GlassTag`/`SpatialButton`/`GlassIconButton`/`GlassProgressBar` *after* migration, leaving `FlowLayout`, `ArtworkFallbackPosterView`, and the fallback-style helpers (still used).
7. **Delete** `VPMenuBackground.swift` after all call sites move (it's shared across tabs — migrate globally or keep a thin `VPMenuBackground = VPBackground` typealias for the other screens until they migrate).

## (e) visionOS interactions, depth & tap-target fixes

- **Tap targets → 60pt everywhere.** Hero secondary info **44 → 60** (DiscoverView.swift:1056), card play glyph **48 → 60** hit area (MediaCardView.swift:63), AI regenerate capsule **~32 → 60** (557–576), error close **~14 → 60** (482–485). All via `VPButtonStyle`'s hard `minWidth/minHeight: 60`; visible glyphs stay 24pt inside the target.
- **Unified hover/focus.** Replace the mixed treatment (hero's custom `isHovered` + `.hoverEffect(.lift)` vs AI cards' `.hoverEffect()` only) with one rule: cinematic heroes & cards → `.hoverEffect(.lift)` + `VPMotion.hover` scale 1.04 + 8pt z-translate; rows/secondary → `.hoverEffect(.highlight)`. **Every interactive component renders an accent focus ring on `@Environment(\.isFocused)`** — fixes "no focus indicators anywhere."
- **Depth/z-layering.** Strict tier order: `VPBackground` z0 → `contentPlane` z1 → catalog/AI cards `.raised`/`.surface` → hero `.overlay` → `VPStateCard`/sheets `.modal`. The **+2pt nested contact shadow** on `.surface` cards inside the plane gives the ambient occlusion the audit found missing.
- **Accessibility.** `textSecondary` (0.74) replaces every `.secondary`/`white.opacity(0.4–0.5)` for body/metadata (≥4.5:1); `textTertiary` (0.58) floor for hints only. One opacity per element from tokens — kills the "opacity cascading" untraceable-contrast problem. Reduce Motion swaps springs for `easeInOut(0.25)` and disables orb + hero auto-advance scaling; Reduce Transparency makes `glassSurface` fall back to a solid `contentPlane` fill (keep stroke, drop blur).

## (f) Code-structure wins specific to this screen

- **Kills the 85% hero duplication** (FeaturedHeroView vs AICuratedHeroCard) → one `VPCinematicHero` with a `style` enum; future hero changes happen once.
- **Removes ~6 inline specular-stroke copies and ~4 inline shadow pairs** on this screen alone (hero, AI hero, supporting row, error circle, regenerate capsule, info button) into `glassSurface`.
- **Extracts the metadata bullet row** rendered 3× (DiscoverView.swift:986–1016, 798–826; MediaCardView.swift:100–143) into `VPMetadataRow`.
- **Magic numbers tokenized** (`170/255/20/22/18/36`, delays `0.02/0.05/0.07`, opacities `0.16/0.28/0.4/0.82`) — moves toward the DesignTokens enum the code-structure audit requested.
- Consider folding the 3 large `@ViewBuilder` AI computed properties (527–646) into the new `VPStateCard`/`VPCinematicHero`/`VPRow` view types, shrinking `DiscoverView`'s body. (The 9-`@State`/5-task and memoization items from the audit are real but orthogonal to this visual redesign — flag, don't bundle.)

**Net for this screen:** every surface gets a real material+stroke+shadow depth tier, every interactive element hits 60pt with a focus ring, all body/metadata text clears 4.5:1, the dual hero implementations become one, and ~10 inline glass primitives collapse into the shared `glassSurface` + component set.

Relevant files: `/Users/brendan/Developer/VPStudio/VPStudio/Views/Windows/Discover/DiscoverView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/MediaCardView.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/GlassCard.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/VPMenuBackground.swift`, `/Users/brendan/Developer/VPStudio/VPStudio/Views/Components/AsyncStateViews.swift`; new: `/Users/brendan/Developer/VPStudio/VPStudio/Design/VPDesign.swift` and `/Users/brendan/Developer/VPStudio/VPStudio/Design/Components/`.

# Part D — Adversarial Review (MiniMax-M3, vision)

# Hard Adversarial Review: "Obsidian Glass" Plan

The plan is ambitious, structurally sound, and will likely *work* — but several of its core premises collide with what makes visionOS feel native. Below is what I would push back on in a design review. I've grouped by severity and tied every issue to something visible in the screenshot or missing from the spec.

---

## CRITICAL

### C1. The "near-black with custom glass" direction fights visionOS at the platform level
**Problem:** visionOS windows are already system glass over a live passthrough. The platform's spatial idiom is *transparent, world-blended, light-feeling* — see Freeform, Apple TV, Mindfulness, Photos, Safari. Apple does not ship dark-on-dark, near-black, custom-glass apps on visionOS. The reference is "Codex Mac," but macOS apps sit on a fixed monitor — that translation doesn't hold. Worse, the current screenshot shows the exact failure mode: the panel is opaque-ish dark, the celestial artwork shows through dimly, and the result reads as "a macOS dark-mode panel shrunk into a small floating rectangle in my living room," not as something that belongs in space. The plan's contentPlane/orbs system is essentially trying to re-create a *fixed background inside a transparent window* — which is precisely what the platform tells you not to do.
**Fix:** Re-scope. Either (a) go full native — system materials, light-leaning glass, no custom near-black void, no animated orbs; or (b) commit to an *Immersive* experience (`.immersiveSpace`) where a near-black world is justifiable, but in that case the app should be spatially-present, not a small floating panel. As written, the plan is the worst of both: small window + macOS-style dark substrate. Recommend the team re-evaluate whether Obsidian Glass is a visionOS product or a visionOS port of a macOS one.

### C2. Two competing onboarding prompts in the same window is a real UX bug, and the plan does not address onboarding at all
**Problem:** The screenshot shows **"Quick Start" modal card AND a "Finish setup to unlock Discover" banner at the bottom in the same window**, with overlapping copy ("Skip setup for now and browse Library…" vs. "Finish setup to unlock Discover"). This is the actual user-facing problem on first-run. None of the six phases mention onboarding, copy architecture, or first-run sequencing. The plan is a styling system; it doesn't ship a coherent first-run experience.
**Fix:** Add a Phase 0.5 / Phase 7 dedicated to onboarding: define one first-run entry point (Quick Start modal wins, banner hides), reduce four-button overflow ("Open Settings / Retry Later / Go to Library / Open Downloads" → max 2 actions), and re-test the cold-launch path on device.

### C3. Dynamic Type is mentioned in the principles but completely absent from the spec
**Problem:** visionOS users can change system text size. The `VPFont` enum hard-codes point sizes (40, 30, 24, 18, 16, 14, 13, 11). There is no `.dynamicTypeSize()` modifier, no `@ScaledMetric`, no minimum/maximum bounds, no treatment of layout reflow at AX sizes. On visionOS specifically, increasing type at distance can be the difference between legible and not. Shipping a fixed-size type system violates HIG and breaks accessibility for the audience that needs it most.
**Fix:** Replace `Font.system(size:weight:)` with `Font.system(.title, design: default, weight: .semibold).leading(.tight)` *or* `@ScaledMetric` wrappers, set sane min/max bounds (e.g., `.xSmall ... .accessibility3`), and document line-spacing rules. Re-validate at AX3 on device — the entire 22pt card radius and 60pt hit targets need to survive a type bump.

### C4. Accessibility is a structural gap, not a feature
**Problem:** The spec talks about focus rings, hit targets, and Reduce Motion/Transparency — but never once mentions VoiceOver labels, traits, rotor, accessibility element grouping, custom actions, or the accessibility hierarchy of the new components. visionOS users navigate by gaze + voice; a glossy focus ring is meaningless to a VoiceOver user. The `VPButtonStyle.icon` with a 24pt glyph inside a 60pt glass container is exactly the kind of element that ships with no label. The `VPBadge` is decorative. The `VPStateCard` has no defined live region for "Download complete."
**Fix:** Define an `accessibilityElement(children: .combine)` strategy for cards, a `accessibilityLabel(_:)` for every icon button, `.accessibilityAddTraits(.isButton/.isHeader/.updatesFrequently)` semantics, and live-region announcements for progress. Bake these into the component API — they cannot be retrofit at the call site.

---

## HIGH

### H1. Material selection is inverted from the spec's own depth logic
**Problem:** `VPElevation` says "more depth = more visual weight," then assigns `.thinMaterial` (the *more transparent* system material) to `.overlay` (the *nearest* tier) and `.regularMaterial` to `.modal`. On visionOS, `.thin < .regular < .thick` in blur amount. So the "nearest, most important" tier is the *most see-through* tier. This will read as backwards in practice: a hovered card will let more passthrough bleed through than a resting card, breaking the depth gradient the spec is so carefully building. Either the tier labels are wrong or the material mapping is wrong.
**Fix:** Decide what "elevation" means here. If it means "more weight/opacity from the world," `.overlay` should be `.thickMaterial` or `.regularMaterial`. If it means "closer to the world" (transparency as a feature), name it differently (`.hover`/`.hero` vs. `.modal`/`.raised`) and stop calling it an elevation system.

### H2. Contrast claims are unverified against the actual failure mode
**Problem:** `textPrimary = white @ 0.96` over `glassFill = white @ 0.10` over `.regularMaterial` over `contentPlane` (0.06 RGB) is *not* the same as white text on a 0.96 background. The composite luminance after blur + tint + passthrough is the real contrast floor, and it varies wildly with whatever is behind the window — bright windows, a TV, a beige wall. The spec asserts "≥7:1" and "≥4.5:1" but only for the raw color pairs, not for the rendered-on-passthrough outcome. The screenshot shows body copy ("Skip setup for now and browse Library…") that is borderline-legible right now; the plan does not run a worst-case passthrough matrix.
**Fix:** Specify a tested matrix: simulate a bright passthrough (white room, sunlit) behind the worst text region, verify that the *composited* foreground/background luminance ratio clears 4.5:1, and lock `textTertiary`'s 0.58 against the brightest acceptable passthrough luminance. If it doesn't pass, raise the floor or force an opaque content-plane pad under text regions.

### H3. Hover-effect + custom-scale layering will cause jitter
**Problem:** The plan applies `.hoverEffect(.lift)` (a system effect that translates + brightens) **and** `.scaleEffect(pressed ? 0.97 : 1)` **and** a custom `hoverLiftZ = 8` z-translation **and** `VPMotion.hover` animation. Stacking the system hover effect with a custom scale + z + spring is a known recipe for visual conflict and double-animations on visionOS — and worse, on visionOS the system hover effect is gesture-driven, not state-driven, so a SwiftUI animation will fight the gesture driver. This hasn't been spec'd carefully.
**Fix:** Pick one: either commit to `.hoverEffect(.lift)` everywhere and remove the custom scale + z (let the system handle it), or commit to fully custom hover and bypass the system modifier. Don't stack. Also note: `.hoverEffect` requires a real `RealityView`/spatial layout to feel right; in a 2D `WindowGroup` it can look like a button, not a spatial object.

### H4. The "starfield/celestial" brand is being silently killed
**Problem:** The current UI has stars, mountain silhouettes, and celestial tones — that's brand identity. The plan's `VPBackground` (near-black with three *different-colored* orbs, blue/purple/green) replaces this with what reads as a generic "abstract tech gradient." No discussion of the brand, no migration note, no comparison render. The plan also collapses the AI purple accent into the red — a brand decision that is asserted, not argued.
**Fix:** This is a brand decision, not a token decision. Lock the brand direction first: keep the celestial theme (and the orbs become subtle nebula tints in the same palette), or formally retire it. If retiring, the AI accent collapse should be a deliberate product call, not a side effect of "one accent red."

### H5. Code-health and visual revamp are mixed; monoliths block shipping
**Problem:** Phase 4 says "Library: 1482 lines → extract 4 components." Phase 5 says "SearchView: 1527 → ~700." These are not UI revamps; they are rewrites. The "PlayerView 5,251 lines" and "AISettingsView 2,033 lines" are explicitly *out* of the visual critical path — but the user spends 95% of their time in Player. Shipping a beautiful Settings screen and a beautifully-revamped Library while the player stays the same is a regression of attention. Also, mixing extract-with-revamp means a refactor bug blocks a visual ship and vice versa.
**Fix:** Split into two tracks. Track A (design system) is token + components + migration of leaf surfaces. Track B (architecture) is the monolith extractions, sequenced separately. Player gets its own dedicated phase *after* the design system is stable; do not ship "Obsidian Glass" as a partial rollout that excludes the player's chrome.

### H6. 5 elevation tiers is more than the eye can use
**Problem:** 5 tiers (`base, surface, raised, modal, overlay`) + 5 stroke-top brightnesses + stratified shadow recipes = a system with 5+ visual variables, all scaling together, all requiring a designer/engineer to make a deliberate tier choice per element. Apple's own apps on visionOS use 2–3 perceptual depth levels. The plan even adds *more* tiers via the "nested .surface inside .raised" +2pt trick, which is a 6th implicit tier. This is over-fitting.
**Fix:** Collapse to 3 tiers: `.rest` (rows, chips, badges), `.raised` (cards, nav, sheets), `.hero` (hovered, modal, immersive). Map all five current tiers to those three. The "premium feel" the spec is chasing comes from *contrast between tiers*, not from *count of tiers*.

### H7. Window sizing / presentation model is unaddressed
**Problem:** The screenshot shows a small floating window with a banner and a modal — three UI surfaces competing in a constrained space. The plan does not address *what kind of window* the app uses (`WindowGroup` vs. `

## (a) H7 + remaining issues

**H7 — Window/presentation model unaddressed (complete):**
The plan describes chrome ("glass tiers", hover, elevation) but never declares the *scene types* it lives in. visionOS has three, and they have different rules:

- **Standard Window** (`WindowGroup`, 2D-ish) — supports `.windowStyle(.volumetric)` and ornaments; this is where most "media player + library" UI belongs.
- **Volumetric Window** — bounded 3D volume for objects; the right home for a celestial globe/Star Map, but you must declare a *size* and it can't follow the user.
- **Full Space / ImmersiveSpace** — unbounded (passthrough off, fully immersive, or mixed). Right for a "dome" or planetarium mode, but expensive and bad as a default.

The plan doesn't say which scenes exist, how `RealityView` vs `SwiftUI` is split, where the `Ornament` lives (top? trailing? attached to focus entity?), whether a second window is a separate `WindowGroup(id:)` (for PiP/multitasking) or a `Presentation`, or how `scenePhase` transitions handle mid-video. **It also doesn't define the Player container** — is the video a `VideoPlayer` in a `RealityView` Material, an `AVPlayerLayer` in a volumetric window, or an `ImmersiveSpace` with a screen? This choice determines *everything* downstream (gestures, focus, performance, dim policy).

**Fix sketch:** Lock the scene map first. Recommend: Standard Window for library/search/profile, Volumetric Window for Star Map/celestial, full ImmersiveSpace only as opt-in "Observatory Mode", and the Player lives in a Standard window with a `.videoPlayer` modifier that supports `.spatialAudio` and a floating `Ornament` for transport.

---

**Remaining HIGH (not previously listed):**

- **H8 — Perf/thermal budget missing for the 95% case.** No frame budget, no draw-call ceiling, no texture/glass-blur caps, no stated behavior on Pro/Air, no AVPlayer resolution ladder. The most-used path has no perf plan.
- **H9 — No Reduce Motion / Reduce Transparency / Increase Contrast handling.** visionOS exposes these; the plan never branches on them. A "glass + parallax + orbit motion" design is a motion-sickness and legibility landmine without these branches.
- **H10 — Spatial depth discipline absent.** No statement of focus distance, no `ScaledMetric`/scale-relative sizing, no rule for what floats near vs. far. Apple HIG is explicit: content sits at comfortable viewing distance, not stacked at z=0. Without a depth contract, the "5 tiers" become accidental z-fight.

**MEDIUM (1–2 lines each):**

- **M1 — Audio is part of the celestial brand and is unmentioned.** Plan is visual-only. `.spatialAudio` cues, ambient bed, haptics for transport are all missing.
- **M2 — State restoration / window resumption unaddressed.** visionOS users expect windows to come back where they were after device removal; the plan says nothing about scene restoration, `SceneStorage`, or mid-playback resume.
- **M3 — SharePlay / spatial Persona integration missing.** A "celestial" co-watching experience is the obvious differentiator and is absent.
- **M4 — Empty / error / offline states for Player not designed.** 95% of use, no state map.
- **M5 — Asset/3D pipeline undefined.** Who authors the celestial models, what's the poly/texture budget, where do they ship (bundle vs. download-on-first-launch)?
- **M6 — Notification/permission UX split between "onboarding" and runtime prompt (extends C2).** If location + calendar + notifications each fire on first use, you need a single permission-rationale pattern, not three.
- **M7 — Localization / RTL for a "sky" UI.** Constellation labels, Arabic/Hebrew text, CJK vertical, and locale-dependent date/time for "tonight's sky" all need design calls.
- **M8 — Test plan is "code health" only.** No Vision Pro device-lab plan, no capture/comparator for passthrough contrast in varied lighting, no accessibility audit pass.

---

## (b) Overall verdict

**Change direction. Do not execute as-is, and don't just patch.**

The plan's central premise — *dark obsidian glass as the brand carrier on a platform whose entire design language is light, airy glass over a bright world* — is in conflict with visionOS. Layering accessibility, a real window model, onboarding, and the Player-first architecture onto a wrong-foundation visual will produce a schizophrenic v1: a dim, jittery, inaccessible, brand-misaligned app that fights passthrough and excludes 95% of its users (the Player). Reset the visual direction (celestial carried by **light aurora-tinted glass, motion, and spatial audio**, with dark reserved for true focus/fullscreen-immersive modes only), then reapply the engineering structure (3 tiers, Player-first, accessibility-as-foundation, single onboarding). Everything else follows from those four decisions.

---

## (c) Top 5 must-fix (priority order)

1. **Invert the material story.** Light, low-opacity glass that *complements* passthrough; dark surfaces only inside opt-in full immersion. This single change resolves C1, H2, H4, and most of H1/H6.
2. **Make the Player a first-class scene, not an afterthought.** Define Player scene type, container (`VideoPlayer` in Standard window with spatial audio + floating `Ornament`), state map, resume, perf budget (resolution ladder, thermal fallback), and empty/error/offline states before designing any other chrome. H5, H8, M4.
3. **Accessibility as foundation, not retrofit.** Dynamic Type, VoiceOver labels/rotor, Reduce Motion, Reduce Transparency, Increase Contrast, color-independent state, focus order — all designed in from frame 1 and verified on-device. C3, C4, H9.
4. **Lock the window/presentation model first.** Declare scene types, ornament placement, second-window strategy, scenePhase behavior, and the SwiftUI-vs-RealityView split *before* drawing any glass tier. H7, H10.
5. **Collapse onboarding to one entry point with a clear first-run plan.** Merge first-run and runtime permission rationales into a single guided flow tied to a real task (not "tap to continue"); provide skip, resume, and a settings re-entry. C2, M6.