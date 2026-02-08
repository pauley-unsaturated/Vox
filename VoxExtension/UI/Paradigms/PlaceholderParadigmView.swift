//
//  PlaceholderParadigmView.swift
//  VoxExtension
//
//  Placeholder views for paradigms not yet implemented.
//

import SwiftUI

struct PlaceholderParadigmView: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(icon)
                .font(.system(size: 64))

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(accentColor)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.synthSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Text("Coming Soon")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(accentColor.opacity(0.5))
                )
                .frame(height: 120)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// Concrete placeholder views for each paradigm

struct NavigatorPlaceholderView: View {
    var body: some View {
        PlaceholderParadigmView(
            icon: "🧭",
            title: "NAVIGATOR",
            subtitle: "Chaos Attractor Parameter Space",
            description: "Navigate a 3D parameter space where strange attractors reveal hidden timbral territories. Fly through sound.",
            accentColor: .cyan
        )
    }
}

struct CloudSculptorPlaceholderView: View {
    var body: some View {
        PlaceholderParadigmView(
            icon: "☁️",
            title: "CLOUD SCULPTOR",
            subtitle: "Granular Parameter Clouds",
            description: "Shape clouds of grain parameters in 3D space. Each point is a potential sound. Sculpt the probability field.",
            accentColor: .orange
        )
    }
}

struct TrajectoryPlaceholderView: View {
    var body: some View {
        PlaceholderParadigmView(
            icon: "📐",
            title: "TRAJECTORY",
            subtitle: "Geometric Path Designer",
            description: "Draw trajectories through parameter space that play back as timbral journeys. Connect waypoints into evolving soundscapes.",
            accentColor: .green
        )
    }
}

#Preview("Navigator") {
    NavigatorPlaceholderView()
        .frame(width: 500, height: 500)
        .background(Color.black)
}