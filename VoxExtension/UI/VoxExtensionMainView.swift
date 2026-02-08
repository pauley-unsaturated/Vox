//
//  VoxExtensionMainView.swift
//  VoxExtension
//
//  Main UI for Vox Pulsar Synthesizer
//  Tab-based interface supporting 5 interaction paradigms.
//

import SwiftUI
import AudioToolbox

// MARK: - Tab Definition

enum VoxTab: Int, CaseIterable, Identifiable {
    case panel = 0
    case navigator
    case cloud
    case trajectory
    case conductor

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .panel:      return "🎛️"
        case .navigator:  return "🧭"
        case .cloud:      return "☁️"
        case .trajectory: return "📐"
        case .conductor:  return "🎭"
        }
    }

    var label: String {
        switch self {
        case .panel:      return "Panel"
        case .navigator:  return "Navigator"
        case .cloud:      return "Cloud"
        case .trajectory: return "Trajectory"
        case .conductor:  return "Conductor"
        }
    }
}

// MARK: - Tab Bar

struct VoxTabBar: View {
    @Binding var selectedTab: VoxTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(VoxTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(tab.icon)
                            .font(.system(size: 14))
                        Text(tab.label.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .white : .synthTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        selectedTab == tab
                            ? Color.white.opacity(0.08)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.cyan)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(white: 0.06))
    }
}

// MARK: - Traditional Panel (Signal Flow Layout)

struct TraditionalPanelView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    @State private var levelObserver = OutputLevelObserver()
    @State private var showModMatrix = false

    var body: some View {
        VStack(spacing: 0) {
            // Main signal flow: horizontal scroll of sections
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    PulsarOscillatorPanel(parameterTree: parameterTree, audioUnit: audioUnit)
                    FormantFilterPanel(parameterTree: parameterTree, audioUnit: audioUnit)
                    EnvelopesPanel(parameterTree: parameterTree)
                    ModulationPanel(parameterTree: parameterTree, audioUnit: audioUnit)
                    PerformancePanel(parameterTree: parameterTree)
                    GlobalPanel()
                    MasterPanel(parameterTree: parameterTree, levelObserver: levelObserver)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Expandable mod matrix at bottom
            ModMatrixPanel(isExpanded: $showModMatrix)
        }
        .onAppear {
            levelObserver.setAudioUnit(audioUnit)
            levelObserver.startPolling()
        }
        .onDisappear {
            levelObserver.stopPolling()
        }
    }
}

// MARK: - Section Container

struct PanelSection<Content: View>: View {
    let title: String
    let accentColor: Color
    let content: Content

    init(title: String, accentColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - 1. Oscillator Panel

struct PulsarOscillatorPanel: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    var body: some View {
        PanelSection(title: "OSCILLATOR", accentColor: .cyan) {
            VStack(spacing: 8) {
                // Live waveform scope
                if #available(macOS 15.0, *), let au = audioUnit {
                    ScopeView(buffer: au.scopeBuffer, preferredFPS: 30)
                        .frame(width: 140, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.05))
                        .frame(width: 140, height: 70)
                        .overlay(
                            Text("SCOPE")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        )
                }

                if let tree = parameterTree {
                    // Shape selector
                    VStack(spacing: 2) {
                        Text("SHAPE")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                        SynthButtonGroup(param: tree.pulsarOsc.pulsaretShape, orientation: .horizontal)
                    }

                    // Duty cycle knob
                    SynthKnob(param: tree.pulsarOsc.dutyCycle, size: 40)
                } else {
                    staticKnobPlaceholder("Shape")
                    staticKnobPlaceholder("Duty")
                }
            }
        }
        .frame(width: 165)
    }
}

// MARK: - 2. Formant Filter Panel

struct FormantFilterPanel: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    var body: some View {
        PanelSection(title: "FORMANT", accentColor: .orange) {
            VStack(spacing: 8) {
                // Live FFT spectrum with formant markers
                if #available(macOS 15.0, *), let au = audioUnit {
                    SpectrumView(
                        buffer: au.spectrumBuffer,
                        sampleRate: 44100,
                        f1Frequency: parameterTree?.formantFilter.formant1Freq.value ?? 800,
                        f2Frequency: parameterTree?.formantFilter.formant2Freq.value ?? 2400,
                        preferredFPS: 30
                    )
                    .frame(width: 160, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.05))
                        .frame(width: 160, height: 60)
                        .overlay(
                            Text("SPECTRUM")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                }

                if let tree = parameterTree {
                    // Vowel morph
                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text("VOWEL")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.synthSecondary)
                            SynthButton(param: tree.formantFilter.useVowelMorph, style: .toggle, size: .small)
                        }
                        SynthKnob(param: tree.formantFilter.vowelMorph, size: 36)
                    }

                    // F1/F2 knobs
                    HStack(spacing: 6) {
                        SynthKnob(param: tree.formantFilter.formant1Freq, size: 32)
                        SynthKnob(param: tree.formantFilter.formant2Freq, size: 32)
                    }

                    // Q and Mix
                    HStack(spacing: 6) {
                        SynthKnob(param: tree.formantFilter.formant1Q, size: 28)
                        SynthKnob(param: tree.formantFilter.formant2Q, size: 28)
                        SynthKnob(param: tree.formantFilter.formantMix, size: 28)
                    }
                }
            }
        }
        .frame(width: 185)
    }
}

// MARK: - 3. Envelopes Panel

struct EnvelopesPanel: View {
    var parameterTree: ObservableAUParameterGroup?

    var body: some View {
        PanelSection(title: "ENVELOPES", accentColor: .green) {
            VStack(spacing: 10) {
                // AMP Envelope (uses existing EnvelopeSection logic)
                if let tree = parameterTree {
                    let a = tree.ampEnvelope.ampAttack as! ObservableAUParameter
                    let d = tree.ampEnvelope.ampDecay as! ObservableAUParameter
                    let s = tree.ampEnvelope.ampSustain as! ObservableAUParameter
                    let r = tree.ampEnvelope.ampRelease as! ObservableAUParameter

                    VStack(spacing: 4) {
                        Text("AMP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)

                        EnvelopeDisplay(
                            attack: normalizeTime(a),
                            decay: normalizeTime(d),
                            sustain: Double(s.value / 100.0),
                            release: normalizeTime(r),
                            curveColor: .green
                        )
                        .frame(width: 140, height: 40)

                        HStack(spacing: 6) {
                            SynthSlider(param: a, trackLength: 50, showLabel: false)
                            SynthSlider(param: d, trackLength: 50, showLabel: false)
                            SynthSlider(param: s, trackLength: 50, showLabel: false)
                            SynthSlider(param: r, trackLength: 50, showLabel: false)
                        }
                        HStack(spacing: 6) {
                            ForEach(["A", "D", "S", "R"], id: \.self) { label in
                                Text(label)
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.synthSecondary)
                                    .frame(width: 14)
                            }
                        }
                    }
                }

                // MOD Envelope placeholder (parameters don't exist yet)
                VStack(spacing: 4) {
                    Text("MOD")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green.opacity(0.5))

                    EnvelopeDisplay(
                        attack: 0.2, decay: 0.3, sustain: 0.5, release: 0.4,
                        curveColor: .green.opacity(0.4)
                    )
                    .frame(width: 140, height: 40)
                    .overlay(
                        Text("FUTURE")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.green.opacity(0.3))
                    )
                }
            }
        }
        .frame(width: 170)
    }

    private func normalizeTime(_ param: ObservableAUParameter) -> Double {
        let value = Double(param.value)
        let minVal = Double(param.min)
        let maxVal = Double(param.max)
        if maxVal <= minVal { return 0.5 }
        return (value - minVal) / (maxVal - minVal)
    }
}

// MARK: - 4. Modulation Panel

struct ModulationPanel: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    var body: some View {
        PanelSection(title: "MODULATION", accentColor: .purple) {
            VStack(spacing: 10) {
                // LFO 1 placeholder
                VStack(spacing: 4) {
                    Text("LFO 1")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.purple)

                    HStack(spacing: 4) {
                        staticKnobPlaceholder("Rate")
                        staticKnobPlaceholder("Depth")
                    }
                    Text("Shape: Sine")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.synthTertiary)
                }

                Divider().background(Color.purple.opacity(0.2))

                // LFO 2 placeholder
                VStack(spacing: 4) {
                    Text("LFO 2")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.purple.opacity(0.7))

                    HStack(spacing: 4) {
                        staticKnobPlaceholder("Rate")
                        staticKnobPlaceholder("Depth")
                    }
                }

                // Mod matrix activity indicator
                if let au = audioUnit {
                    let observer = ModMatrixActivityObserver(audioUnit: au)
                    ModMatrixActivityView(activityObserver: observer)
                        .frame(width: 120)
                } else {
                    ModMatrixActivityView(activityObserver: nil)
                        .frame(width: 120)
                }
            }
        }
        .frame(width: 150)
    }
}

// MARK: - 5. Performance Panel

struct PerformancePanel: View {
    var parameterTree: ObservableAUParameterGroup?

    var body: some View {
        PanelSection(title: "PERFORMANCE", accentColor: .yellow) {
            VStack(spacing: 8) {
                if let tree = parameterTree {
                    // Glide
                    VStack(spacing: 2) {
                        Text("GLIDE")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                        SynthButton(param: tree.performance.glideEnabled, style: .toggle, size: .small)
                    }
                    SynthKnob(param: tree.performance.glideTime, size: 36)

                    // Pitch bend range
                    SynthKnob(param: tree.performance.pitchBendRange, size: 36)
                } else {
                    staticKnobPlaceholder("Glide")
                    staticKnobPlaceholder("PB Range")
                }

                Divider().background(Color.yellow.opacity(0.2))

                // Mono/Poly placeholder
                VStack(spacing: 2) {
                    Text("VOICES")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    Text("POLY 8")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }
        }
        .frame(width: 120)
    }
}

// MARK: - 6. Global Panel

struct GlobalPanel: View {
    var body: some View {
        PanelSection(title: "GLOBAL", accentColor: Color(white: 0.7)) {
            VStack(spacing: 8) {
                // Drift placeholder
                VStack(spacing: 2) {
                    Text("DRIFT")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    staticKnobPlaceholder("Amount")
                }

                Divider().background(Color.gray.opacity(0.2))

                // Chaos placeholder
                VStack(spacing: 2) {
                    Text("CHAOS")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    staticKnobPlaceholder("Amount")
                    Text("Type: Lorenz")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.synthTertiary)
                }
            }
        }
        .frame(width: 110)
    }
}

// MARK: - 7. Master Panel

struct MasterPanel: View {
    var parameterTree: ObservableAUParameterGroup?
    var levelObserver: OutputLevelObserver

    var body: some View {
        PanelSection(title: "MASTER", accentColor: .white) {
            VStack(spacing: 8) {
                if let tree = parameterTree {
                    SynthKnob(param: tree.master.masterVolume, size: 44)
                } else {
                    staticKnobPlaceholder("Volume")
                }

                // Level meters
                HStack(spacing: 4) {
                    VStack(spacing: 2) {
                        LevelMeter(level: Double(levelObserver.level), orientation: .vertical, segmentCount: 10, width: 10, height: 60)
                        Text("L")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                    }
                    VStack(spacing: 2) {
                        LevelMeter(level: Double(levelObserver.level), orientation: .vertical, segmentCount: 10, width: 10, height: 60)
                        Text("R")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                    }
                }

                PeakIndicator(isActive: levelObserver.isPeaking, size: 8, color: .red)
            }
        }
        .frame(width: 100)
    }
}

// MARK: - Mod Matrix Panel

struct ModMatrixPanel: View {
    @Binding var isExpanded: Bool

    private let sources = ["Env1", "Env2", "LFO1", "LFO2", "Vel", "AT", "Chaos", "Drift"]
    private let destinations = ["Pitch", "F1", "F2", "Vowel", "Duty", "Density", "Scatter", "Pan"]

    var body: some View {
        VStack(spacing: 0) {
            // Toggle bar
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Text("MOD MATRIX")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8))
                        .foregroundColor(.synthSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(white: 0.06))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 50)
                            ForEach(destinations, id: \.self) { dest in
                                Text(dest)
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan.opacity(0.7))
                                    .frame(width: 44)
                            }
                        }
                        .padding(.bottom, 2)

                        // Rows
                        ForEach(sources, id: \.self) { source in
                            HStack(spacing: 0) {
                                Text(source)
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple.opacity(0.7))
                                    .frame(width: 50, alignment: .trailing)
                                    .padding(.trailing, 4)

                                ForEach(destinations, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(white: 0.08))
                                        .frame(width: 40, height: 18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(Color(white: 0.15), lineWidth: 0.5)
                                        )
                                        .padding(2)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 190)
                .background(Color(white: 0.04))
            }
        }
    }
}

// MARK: - Static Knob Placeholder

@ViewBuilder
func staticKnobPlaceholder(_ label: String) -> some View {
    VStack(spacing: 2) {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: 28, height: 28)
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 22, height: 22)
        }
        Text(label)
            .font(.system(size: 7, weight: .medium))
            .foregroundColor(.synthTertiary)
    }
}

// MARK: - Main View

struct VoxExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    @State private var selectedTab: VoxTab = .panel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("VOX")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Pulsar Synthesizer")
                    .font(.system(size: 10))
                    .foregroundColor(.synthSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.04))

            // Tab bar
            VoxTabBar(selectedTab: $selectedTab)

            // Tab content
            Group {
                switch selectedTab {
                case .panel:
                    TraditionalPanelView(parameterTree: parameterTree, audioUnit: audioUnit)
                case .navigator:
                    ParameterSpaceNavigatorView(parameterTree: parameterTree, audioUnit: audioUnit)
                case .cloud:
                    CloudSculptorView(parameterTree: parameterTree, audioUnit: audioUnit)
                case .trajectory:
                    TrajectoryComposerView(parameterTree: parameterTree, audioUnit: audioUnit)
                case .conductor:
                    MacroConductorView(parameterTree: parameterTree, audioUnit: audioUnit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
    }
}

#Preview {
    VoxExtensionMainView(parameterTree: nil, audioUnit: nil)
        .frame(width: 500, height: 600)
}