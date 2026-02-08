//
//  ModMatrixActivityView.swift
//  VoxExtension
//
//  Phase 8.10: Visual feedback showing active modulation routes with glow effects.
//  Displays a compact grid of mod destinations with intensity-proportional glow
//  that pulses based on real-time modulation depth from the audio thread.
//

import SwiftUI

/// Compact modulation matrix activity indicator.
/// Shows a row of destination indicators that glow proportionally to active modulation depth.
struct ModMatrixActivityView: View {
    var activityObserver: ModMatrixActivityObserver?

    /// Destination labels matching ModDest enum order.
    private static let destLabels = [
        "PIT", "F1", "F2", "VOW", "DTY", "DEN",
        "SCT", "PAN", "AMP", "LR1", "LR2", "CHR",
        "PEP", "FTK", "EDG", "MSK"
    ]

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("MOD ACTIVITY")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.synthSecondary)
                Spacer()
                if let observer = activityObserver, observer.activeRouteCount > 0 {
                    Text("\(observer.activeRouteCount) routes")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                }
            }

            // Two rows of 8 destination indicators
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0..<8) { i in
                        ModDestIndicator(
                            label: Self.destLabels[i],
                            activity: activityObserver?.destinationActivity[i] ?? 0
                        )
                    }
                }
                HStack(spacing: 2) {
                    ForEach(8..<16) { i in
                        ModDestIndicator(
                            label: Self.destLabels[i],
                            activity: activityObserver?.destinationActivity[i] ?? 0
                        )
                    }
                }
            }
        }
    }
}

/// Single modulation destination activity indicator with glow effect.
struct ModDestIndicator: View {
    let label: String
    let activity: Float

    var body: some View {
        let intensity = Double(activity)
        let glowColor = Color.cyan

        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(intensity > 0.01 ? .white : Color(white: 0.4))

            RoundedRectangle(cornerRadius: 2)
                .fill(intensity > 0.01
                      ? glowColor.opacity(0.2 + intensity * 0.6)
                      : Color(white: 0.1))
                .frame(width: 22, height: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(intensity > 0.01
                                ? glowColor.opacity(0.3 + intensity * 0.7)
                                : Color(white: 0.2),
                                lineWidth: 1)
                )
                .shadow(color: glowColor.opacity(intensity > 0.1 ? intensity * 0.8 : 0),
                        radius: CGFloat(intensity) * 6, x: 0, y: 0)
        }
        .frame(width: 26, height: 16)
        .animation(.easeOut(duration: 0.1), value: activity)
    }
}

// MARK: - Glow Modifier (reusable for any view needing activity glow)

/// View modifier that adds a modulation activity glow to any view.
/// Intensity 0.0 = no glow, 1.0 = maximum glow.
struct ModActivityGlow: ViewModifier {
    let intensity: Double
    var color: Color = .cyan

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(intensity * 0.6), lineWidth: intensity > 0.01 ? 1.5 : 0)
            )
            .shadow(color: color.opacity(intensity > 0.05 ? intensity * 0.5 : 0),
                    radius: CGFloat(intensity) * 8, x: 0, y: 0)
            .animation(.easeOut(duration: 0.1), value: intensity)
    }
}

extension View {
    /// Adds a modulation activity glow effect.
    /// - Parameters:
    ///   - intensity: Glow intensity (0.0–1.0).
    ///   - color: Glow color (default: cyan).
    func modActivityGlow(intensity: Double, color: Color = .cyan) -> some View {
        modifier(ModActivityGlow(intensity: intensity, color: color))
    }
}
