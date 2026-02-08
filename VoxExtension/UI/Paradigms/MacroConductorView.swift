//
//  MacroConductorView.swift
//  VoxExtension
//
//  Paradigm 5: Macro Conductor — 4 semantic macro knobs for performative control.
//

import SwiftUI

// MARK: - Sound Personas

struct SoundPersona: Identifiable {
    let id: String
    let icon: String
    let name: String
    let intensity: Double
    let color: Double
    let movement: Double
    let space: Double
}

private let personas: [SoundPersona] = [
    SoundPersona(id: "observer",    icon: "👁️", name: "Observer",    intensity: 0.15, color: 0.3,  movement: 0.1,  space: 0.5),
    SoundPersona(id: "firestarter", icon: "🔥", name: "Firestarter", intensity: 0.9,  color: 0.7,  movement: 0.85, space: 0.4),
    SoundPersona(id: "oceanic",     icon: "🌊", name: "Oceanic",     intensity: 0.4,  color: 0.5,  movement: 0.7,  space: 0.9),
    SoundPersona(id: "machine",     icon: "🤖", name: "Machine",     intensity: 0.6,  color: 0.4,  movement: 0.3,  space: 0.2),
    SoundPersona(id: "ghost",       icon: "👻", name: "Ghost",       intensity: 0.1,  color: 0.2,  movement: 0.5,  space: 0.95),
]

// MARK: - Macro Slider

struct MacroSlider: View {
    let label: String
    let icon: String
    let lowLabel: String
    let highLabel: String
    let gradient: [Color]
    @Binding var value: Double

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            // Icon and label
            Text(icon)
                .font(.system(size: 28))

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Range label top
            Text(highLabel)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.synthSecondary)

            // The slider track
            GeometryReader { geo in
                let trackHeight = geo.size.height
                let fillHeight = trackHeight * CGFloat(value)

                ZStack(alignment: .bottom) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(white: 0.25), lineWidth: 1)
                        )

                    // Filled portion with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: fillHeight)

                    // Thumb line
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 40, height: 4)
                        .shadow(color: .white.opacity(0.5), radius: 4)
                        .offset(y: -(fillHeight - 2))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            let y = drag.location.y
                            let newValue = 1.0 - Double(y / trackHeight)
                            value = min(1, max(0, newValue))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: 56)

            // Range label bottom + value
            Text(lowLabel)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.synthSecondary)

            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Persona Button

struct PersonaChip: View {
    let persona: SoundPersona
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(persona.icon)
                    .font(.system(size: 18))
                Text(persona.name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isSelected ? .white : .synthSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.cyan.opacity(0.6) : Color(white: 0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Macro Conductor View

struct MacroConductorView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    @State private var intensity: Double = 0.3
    @State private var color: Double = 0.5
    @State private var movement: Double = 0.2
    @State private var space: Double = 0.4
    @State private var selectedPersona: String?

    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("🎭")
                    .font(.system(size: 20))
                Text("MACRO CONDUCTOR")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)

            // Four macro sliders
            HStack(spacing: 16) {
                MacroSlider(
                    label: "INTENSITY",
                    icon: "🌡️",
                    lowLabel: "calm",
                    highLabel: "aggressive",
                    gradient: [Color.blue, Color.purple, Color.red],
                    value: $intensity
                )

                MacroSlider(
                    label: "COLOR",
                    icon: "🎨",
                    lowLabel: "dark",
                    highLabel: "bright",
                    gradient: [Color(red: 0.3, green: 0.0, blue: 0.5), Color.orange, Color.yellow],
                    value: $color
                )

                MacroSlider(
                    label: "MOVEMENT",
                    icon: "🌀",
                    lowLabel: "static",
                    highLabel: "evolving",
                    gradient: [Color(white: 0.3), Color.teal, Color.green],
                    value: $movement
                )

                MacroSlider(
                    label: "SPACE",
                    icon: "🌌",
                    lowLabel: "intimate",
                    highLabel: "vast",
                    gradient: [Color(red: 0.2, green: 0.1, blue: 0.3), Color.indigo, Color.cyan],
                    value: $space
                )
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)

            // Sound Personas
            VStack(spacing: 6) {
                Text("PERSONAS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.synthSecondary)

                HStack(spacing: 6) {
                    ForEach(personas) { persona in
                        PersonaChip(
                            persona: persona,
                            isSelected: selectedPersona == persona.id,
                            action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedPersona = persona.id
                                    intensity = persona.intensity
                                    color = persona.color
                                    movement = persona.movement
                                    space = persona.space
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)

            // Mod matrix activity
            ModMatrixActivityView(activityObserver: nil)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.vertical)
    }
}

#Preview {
    MacroConductorView(parameterTree: nil, audioUnit: nil)
        .frame(width: 500, height: 600)
        .background(Color.black)
}