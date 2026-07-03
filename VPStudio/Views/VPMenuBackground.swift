import SwiftUI

/// Shared cinematic background used across top-level menus.
struct VPMenuBackground: View {
    @AppStorage(VPMenuBackgroundIntensityPolicy.appStorageKey)
    private var menuBackgroundIntensity = VPMenuBackgroundIntensityPolicy.defaultValue
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let intensity = VPMenuBackgroundIntensityPolicy.clamped(menuBackgroundIntensity)

            ZStack {
                if reduceTransparency {
                    LinearGradient(
                        colors: [
                            Color(red: 0.052, green: 0.058, blue: 0.066),
                            Color(red: 0.038, green: 0.044, blue: 0.053),
                            Color(red: 0.030, green: 0.034, blue: 0.041),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Rectangle().fill(.regularMaterial)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.035),
                            Color(red: 0.064, green: 0.074, blue: 0.084).opacity(0.30),
                            Color(red: 0.026, green: 0.030, blue: 0.036).opacity(0.22),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.12, green: 0.17, blue: 0.19).opacity(0.12 * intensity),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: size.width * 1.35, height: size.height * 1.35)
                .blur(radius: 36)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.17, green: 0.15, blue: 0.11).opacity(0.06 * intensity),
                        Color(red: 0.05, green: 0.12, blue: 0.11).opacity(0.08 * intensity),
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.018),
                                Color.black.opacity(0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}
