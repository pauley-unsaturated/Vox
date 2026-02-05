//
//  MainSection.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI
import AudioToolbox

/// The main section containing preset management, master controls, and metering
struct MainSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    var audioUnit: VoxExtensionAudioUnit?
    @State var presetManager: PresetManager

    @State private var levelObserver: OutputLevelObserver?

    var body: some View {
        VStack(spacing: 12) {
            // Section title
            HStack {
                Text("MAIN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                Spacer()
            }

            VStack(spacing: 16) {
                // Preset management
                PresetControls(presetManager: presetManager)

                // Master volume and metering
                MasterControls(
                    volumeParam: parameterTree.master.masterVolume,
                    levelObserver: levelObserver
                )
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.3, green: 0.3, blue: 0.3), lineWidth: 1)
                )
        )
        .onAppear {
            // Level meter disabled - SwiftUI redraws are too expensive
            // See backlog issue for Metal-backed implementation
            // levelObserver = OutputLevelObserver(audioUnit: audioUnit)
            // levelObserver?.startPolling()
        }
        .onDisappear {
            levelObserver?.stopPolling()
        }
    }
}



/// Preset management controls
struct PresetControls: View {
    @State var presetManager: PresetManager

    @State private var showingSaveDialog = false
    @State private var newPresetName = ""

    var body: some View {
        VStack(spacing: 8) {
            Text("PRESET")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.synthSecondary)

            // Preset display and navigation
            VStack(spacing: 6) {
                // Current preset display with dropdown menu
                Menu {
                    // Factory presets section
                    if !presetManager.factoryPresets.isEmpty {
                        Section("Factory") {
                            ForEach(presetManager.factoryPresets, id: \.number) { preset in
                                Button(action: {
                                    presetManager.selectPreset(preset)
                                }) {
                                    HStack {
                                        Text(preset.name)
                                        if presetManager.currentPreset?.number == preset.number {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // User presets section
                    if !presetManager.userPresets.isEmpty {
                        Section("User") {
                            ForEach(presetManager.userPresets, id: \.number) { preset in
                                Button(action: {
                                    presetManager.selectPreset(preset)
                                }) {
                                    HStack {
                                        Text(preset.name)
                                        if presetManager.currentPreset?.number == preset.number {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(presetManager.currentPresetName)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.synthPrimary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.synthSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(red: 0.4, green: 0.4, blue: 0.4), lineWidth: 1)
                            )
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                // Preset navigation buttons
                HStack(spacing: 8) {
                    Button(action: {
                        presetManager.selectPreviousPreset()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.synthPrimary)
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        presetManager.selectNextPreset()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.synthPrimary)
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Save button (only if user presets supported)
            if presetManager.supportsUserPresets {
                Button(action: {
                    newPresetName = ""
                    showingSaveDialog = true
                }) {
                    Text("SAVE")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.synthPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Error message display
            if let error = presetManager.errorMessage {
                Text(error)
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .alert("Save Preset", isPresented: $showingSaveDialog) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !newPresetName.isEmpty {
                    presetManager.saveUserPreset(name: newPresetName)
                }
            }
        } message: {
            Text("Enter a name for your preset")
        }
    }
}

/// Master volume and output controls
struct MasterControls: View {
    @State var volumeParam: ObservableAUParameter
    var levelObserver: OutputLevelObserver?

    var body: some View {
        VStack(spacing: 8) {
            Text("MASTER")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.synthSecondary)

            HStack(spacing: 12) {
                // Master volume knob
                VStack(spacing: 4) {
                    SynthKnob(param: volumeParam, size: 50)
                    Text("VOLUME")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.synthSecondary)
                }

                // Output level meter
                VStack(spacing: 4) {
                    Text("OUT")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.synthSecondary)

                    LevelMeter(
                        level: Double(levelObserver?.level ?? 0.0),
                        orientation: .vertical,
                        segmentCount: 10,
                        width: 12,
                        height: 60
                    )

                    PeakIndicator(
                        isActive: levelObserver?.isPeaking ?? false,
                        size: 10,
                        color: .red
                    )
                }
            }
        }
    }
}



#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Main Section Preview")
                .font(.title2)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                PresetControls(
                    presetManager: PresetManager(audioUnit: nil)
                )

                MasterControls(
                    volumeParam: ObservableAUParameter(
                        address: 0,
                        parameterTree: nil,
                        spec: ParameterSpec(
                            address: 0,
                            identifier: "masterVolume",
                            name: "Master Volume",
                            units: .decibels,
                            valueRange: -60...0,
                            defaultValue: -6
                        )
                    ),
                    levelObserver: nil
                )
            }
        }
        .padding()
    }
    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
}
