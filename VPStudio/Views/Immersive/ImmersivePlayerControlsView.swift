#if os(visionOS)
import SwiftUI

/// Floating transport controls displayed inside immersive cinema environments.
///
/// This is the ONLY user interface available while in an immersive space. It
/// communicates with `PlayerView` via `NotificationCenter` messages and reads
/// state from the shared `VPPlayerEngine` injected into the SwiftUI environment.
struct ImmersivePlayerControlsView: View {
    @Environment(VPPlayerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let showsScreenSizeControl: Bool

    @State private var isDraggingScrubber = false
    @State private var isScrubberHovered = false
    @State private var scrubPercent: Double = 0

    init(showsScreenSizeControl: Bool = true) {
        self.showsScreenSizeControl = showsScreenSizeControl
    }

    private var playPauseAccessibilityValue: String {
        if engine.error != nil {
            return "Failed"
        }
        if engine.isBuffering {
            return engine.isPlaying ? "Buffering" : "Preparing"
        }
        return engine.isPlaying ? "Playing" : "Paused"
    }

    var body: some View {
        VStack(spacing: 0) {
            mediaInfoHeader
                .padding(.bottom, 14)

            scrubBar
                .padding(.bottom, 4)

            timeLabels
                .padding(.bottom, 14)

            transportRow
                .padding(.bottom, 14)

            secondaryControlsRow
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background {
            // `.fill(.clear)` is load-bearing: a bare RoundedRectangle used as a
            // View paints with the foreground style (opaque), which would sit on
            // top of the glass. Filling clear keeps only the glass + stroke visible.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .glassBackgroundEffect()
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    // MARK: - Media Info Header

    private var mediaInfoHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = engine.currentTitle {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.78)
            }
            if let chapter = engine.currentChapter(at: engine.currentTime) {
                Text(chapter.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The header is the semantic anchor of the panel; cap Dynamic Type so an
        // accessibility-size title can't blow out the fixed-width control panel.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: - Scrub Bar

    private var scrubBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let displayPercent = isDraggingScrubber ? scrubPercent : engine.progressPercent
            let clampedDisplayPercent = max(0, min(1, displayPercent))
            let thumbIsExpanded = isDraggingScrubber || isScrubberHovered
            let thumbSize = thumbIsExpanded
                ? ImmersiveControlsPolicy.scrubberDraggingThumbSize
                : ImmersiveControlsPolicy.scrubberIdleThumbSize

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: 4)

                // Buffered indicator
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(width: width * max(0, min(1, engine.bufferedPercent)), height: 4)

                // Chapter tick marks
                if !engine.chapters.isEmpty, engine.duration > 0 {
                    ForEach(engine.chapters) { chapter in
                        let x = (chapter.startTime / engine.duration) * width
                        Rectangle()
                            .fill(.white.opacity(0.5))
                            .frame(width: 1.5, height: 8)
                            .position(x: x, y: geo.size.height / 2)
                    }
                }

                // Filled progress
                Capsule()
                    .fill(.white)
                    .frame(width: width * clampedDisplayPercent, height: 4)

                // Scrub thumb
                Circle()
                    .fill(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(thumbIsExpanded ? 0.36 : 0), lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .shadow(color: .white.opacity(thumbIsExpanded ? 0.20 : 0), radius: 8)
                    .position(
                        x: ImmersiveControlsPolicy.scrubberMarkerX(
                            percent: clampedDisplayPercent,
                            barWidth: width,
                            markerWidth: thumbSize
                        ),
                        y: geo.size.height / 2
                    )
                    .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.15), value: thumbIsExpanded)
            }
            .contentShape(Rectangle())
            .onHover { isScrubberHovered = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue(scrubberAccessibilityValue)
            .accessibilityHint("Adjust to seek through the current video.")
            .accessibilityAdjustableAction { direction in
                adjustScrubberAccessibility(direction)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingScrubber = true
                        scrubPercent = ImmersiveControlsPolicy.scrubberDragPercent(
                            locationX: value.location.x,
                            barWidth: width
                        )
                    }
                    .onEnded { _ in
                        isDraggingScrubber = false
                        NotificationCenter.default.post(
                            name: .immersiveControlSeekToPercent,
                            object: NSNumber(value: scrubPercent)
                        )
                    }
            )
        }
        .frame(height: ImmersiveControlsPolicy.scrubberHitTargetHeight)
    }

    // MARK: - Time Labels

    private var timeLabels: some View {
        HStack {
            Text(engine.currentTimeFormatted)
                .font(.caption2)
                .monospacedDigit()
            Spacer()
            Text("-\(engine.remainingFormatted)")
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(VPColor.textTertiary)
    }

    // MARK: - Transport Row

    private var transportRow: some View {
        HStack(spacing: 24) {
            chapterControl(
                icon: "backward.end.fill",
                label: "Previous chapter",
                notification: .immersiveControlPreviousChapter
            )

            // Seek back
            controlButton(icon: PlayerCinematicVisualPolicy.skipBackSymbolName, size: .body) {
                NotificationCenter.default.post(name: .immersiveControlSeekBack, object: nil)
            }
            .accessibilityLabel("Rewind \(PlayerCinematicChromePolicy.skipBackInterval) seconds")

            playPauseButton

            // Seek forward
            controlButton(icon: PlayerCinematicVisualPolicy.skipForwardSymbolName, size: .body) {
                NotificationCenter.default.post(name: .immersiveControlSeekForward, object: nil)
            }
            .accessibilityLabel("Fast forward \(PlayerCinematicChromePolicy.skipForwardInterval) seconds")

            chapterControl(
                icon: "forward.end.fill",
                label: "Next chapter",
                notification: .immersiveControlNextChapter
            )
        }
        .foregroundStyle(.white)
    }

    /// Chapter prev/next button that always occupies its slot so the transport
    /// row never reflows when chapter metadata loads mid-session (which could
    /// shift a seek button under the user's gaze and cause an accidental tap).
    private func chapterControl(
        icon: String,
        label: String,
        notification: Notification.Name
    ) -> some View {
        let hasChapters = !engine.chapters.isEmpty
        return controlButton(icon: icon, size: .caption) {
            NotificationCenter.default.post(name: notification, object: nil)
        }
        .accessibilityLabel(label)
        .opacity(hasChapters ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: hasChapters)
        .allowsHitTesting(hasChapters)
        .accessibilityHidden(!hasChapters)
    }

    /// Prominent center play/pause control. Shows a spinner while buffering so a
    /// frozen frame in a dark immersive space never looks like an unresponsive tap.
    private var playPauseButton: some View {
        Button {
            NotificationCenter.default.post(name: .immersiveControlTogglePlayPause, object: nil)
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                if engine.isBuffering {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.black)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.black)
                        .transition(.opacity)
                }
            }
            .animation(
                accessibilityReduceMotion ? nil : .easeInOut(duration: ImmersiveControlsPolicy.bufferingIndicatorTransitionDuration),
                value: engine.isBuffering
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")
        .accessibilityValue(playPauseAccessibilityValue)
        .accessibilityHint(
            engine.isBuffering
                ? "Playback is loading."
                : "Double-tap to toggle playback."
        )
    }

    // MARK: - Secondary Controls

    private var secondaryControlsRow: some View {
        HStack(spacing: 12) {
            // Playback speed — tinted when running at a non-1.0 rate.
            Button {
                NotificationCenter.default.post(name: .immersiveControlCycleRate, object: nil)
            } label: {
                Text(rateLabel)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isCustomRate ? .white : .white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isCustomRate
                            ? AnyShapeStyle(.white.opacity(0.22))
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel("Playback speed")
            .accessibilityValue(rateLabel)
            .accessibilityHint("Double-tap to cycle playback speed")

            secondaryGroupDivider

            // Subtitles — on/off toggle with a brighter surface when enabled.
            toggleControl(
                onIcon: "captions.bubble.fill",
                offIcon: "captions.bubble",
                isOn: engine.subtitlesEnabled,
                label: "Subtitles",
                notification: .immersiveControlToggleSubtitles
            )
            .accessibilityValue(engine.subtitlesEnabled ? "On" : "Off")
            .accessibilityHint("Double-tap to toggle subtitles")

            // Audio tracks
            controlButton(icon: "speaker.wave.3", size: .callout) {
                NotificationCenter.default.post(name: .immersiveControlToggleAudio, object: nil)
            }
            .accessibilityLabel("Audio track")
            .accessibilityHint("Double-tap to switch audio track")

            if showsScreenSizeControl {
                controlButton(icon: "tv", size: .callout) {
                    NotificationCenter.default.post(name: .immersiveControlCycleScreenSize, object: nil)
                }
                .accessibilityLabel("Screen size")
                .accessibilityHint("Double-tap to cycle screen size")
            }

            // Environment switch
            controlButton(icon: "mountain.2", size: .callout) {
                NotificationCenter.default.post(name: .immersiveControlRequestEnvironmentSwitch, object: nil)
            }
            .accessibilityLabel("Change environment")
            .accessibilityHint("Opens the environment picker")

            secondaryGroupDivider

            // Exit immersive — higher-consequence action gets a distinct, warm-tinted
            // labeled surface so it is never confused with neutral playback controls.
            exitImmersiveButton
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    private var secondaryGroupDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.16))
            .frame(width: 1, height: 26)
            .accessibilityHidden(true)
    }

    private var exitImmersiveButton: some View {
        Button {
            NotificationCenter.default.post(name: .immersiveControlDismiss, object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                Text("Exit")
            }
            .font(.system(.caption, design: .default).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: ImmersiveControlsPolicy.controlButtonDiameter)
            .background(.red.opacity(0.55), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel("Exit immersive space")
        .accessibilityHint("Closes the cinema environment and returns to the window")
    }

    private var isCustomRate: Bool {
        abs(engine.playbackRate - 1.0) > 0.001
    }

    /// A circular control that reflects an on/off state with a brighter surface
    /// (and filled glyph) when active.
    private func toggleControl(
        onIcon: String,
        offIcon: String,
        isOn: Bool,
        label: String,
        notification: Notification.Name
    ) -> some View {
        let diameter = ImmersiveControlsPolicy.controlButtonDiameter
        return Button {
            NotificationCenter.default.post(name: notification, object: nil)
        } label: {
            Image(systemName: isOn ? onIcon : offIcon)
                .font(.system(.callout, design: .default))
                .foregroundStyle(isOn ? .white : .white.opacity(0.85))
                .frame(width: diameter, height: diameter)
                .background(isOn ? .white.opacity(0.22) : .white.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private var rateLabel: String {
        let rate = engine.playbackRate
        if rate == Float(Int(rate)) {
            return "\(Int(rate)).0x"
        }
        return String(format: "%.1fx", rate)
    }

    private func controlButton(
        icon: String,
        size: Font.TextStyle,
        action: @escaping () -> Void
    ) -> some View {
        let diameter = ImmersiveControlsPolicy.controlButtonDiameter
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size, design: .default))
                .frame(width: diameter, height: diameter)
                // A faint at-rest surface so the control reads as tappable at
                // distance, brightening under the system hover highlight.
                .background(.white.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }

    private var scrubberAccessibilityValue: String {
        let current = isDraggingScrubber ? (scrubPercent * engine.duration) : engine.currentTime
        guard engine.duration > 0 else { return current.formattedDuration }
        return "\(current.formattedDuration) of \(engine.durationFormatted)"
    }

    private func adjustScrubberAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        // The scrubber's contract is "adjust position" by a small amount, not the
        // larger skip-button interval. Nudge by a few seconds, expressed as a
        // fraction of duration, and reuse the existing seek-to-percent plumbing.
        guard engine.duration > 0 else { return }
        let deltaPercent = ImmersiveControlsPolicy.accessibilityScrubSeconds / engine.duration
        let basePercent = max(0, min(1, engine.progressPercent))
        let target: Double
        switch direction {
        case .increment:
            target = min(1, basePercent + deltaPercent)
        case .decrement:
            target = max(0, basePercent - deltaPercent)
        default:
            return
        }
        NotificationCenter.default.post(
            name: .immersiveControlSeekToPercent,
            object: NSNumber(value: target)
        )
    }
}
#endif
