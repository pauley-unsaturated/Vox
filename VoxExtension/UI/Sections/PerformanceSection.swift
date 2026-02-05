//
//  PerformanceSection.swift
//  VoxExtension
//
//  Performance section for legato, glide, arpeggiator, and sequencer controls
//  Based on ArpeggiatorSequencer-Design.md
//

import SwiftUI

/// Performance section containing voice controls and arp/seq - horizontal layout
struct PerformanceSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    var audioUnit: VoxExtensionAudioUnit?
    @State private var sequencerModel: SequencerModel?

    var body: some View {
        VStack(spacing: 8) {
            // Section title
            HStack {
                Text("PERFORMANCE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                Spacer()
            }
            
            // All controls in one horizontal row
            HStack(alignment: .top, spacing: 12) {
                // Voice controls (Legato, Glide)
                VoiceControlsView(parameterTree: parameterTree)

                Divider()
                    .frame(height: 80)
                    .background(Color(red: 0.3, green: 0.3, blue: 0.3))

                // Mode selector
                ModeControlsView(parameterTree: parameterTree)

                Divider()
                    .frame(height: 80)
                    .background(Color(red: 0.3, green: 0.3, blue: 0.3))

                // Arp-specific controls OR Seq-specific controls
                ArpSeqControlsView(parameterTree: parameterTree, sequencerModel: sequencerModel)

                Divider()
                    .frame(height: 80)
                    .background(Color(red: 0.3, green: 0.3, blue: 0.3))

                // Timing controls
                TimingControlsView(parameterTree: parameterTree)

                Divider()
                    .frame(height: 80)
                    .background(Color(red: 0.3, green: 0.3, blue: 0.3))

                // Velocity controls
                VelocityControlsView(parameterTree: parameterTree)
            }
        }
        .onAppear {
            // Create sequencer model when view appears
            if sequencerModel == nil {
                sequencerModel = SequencerModel(audioUnit: audioUnit)
            }
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
    }
}

// MARK: - Voice Controls (Legato, Glide) - Compact horizontal

struct VoiceControlsView: View {
    @State var parameterTree: ObservableAUParameterGroup

    var body: some View {
        HStack(spacing: 12) {
            // Glide Mode with Legato underneath
            VStack(spacing: 4) {
                Text("GLIDE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthSecondary)
                SynthButtonGroup(param: parameterTree.voice.glideMode, orientation: .horizontal)
                VStack(spacing: 2) {
                    Text("LEGATO")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                        .fixedSize()
                    SynthButton(param: parameterTree.voice.legato, style: .toggle, size: .small)
                }
            }

            // Glide Time
            VStack(spacing: 4) {
                SynthKnob(param: parameterTree.voice.glideTime, size: 32, showValue: true, showLabel: false)
                Text("TIME")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Mode Controls (Off/Arp/Seq)

struct ModeControlsView: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(spacing: 4) {
            Text("MODE")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.synthSecondary)
            
            SynthButtonGroup(param: parameterTree.arpSeq.arpSeqMode, orientation: .vertical)
        }
    }
}

// MARK: - Combined Arp/Seq Controls (always visible, mode dims inactive)

struct ArpSeqControlsView: View {
    @State var parameterTree: ObservableAUParameterGroup
    var sequencerModel: SequencerModel?
    @State private var currentPage: Int = 0

    var body: some View {
        let modeParam = parameterTree.arpSeq.arpSeqMode as! ObservableAUParameter
        let mode = Int(modeParam.value)

        HStack(spacing: 12) {
            // ARP section - always visible
            ArpControlsSection(parameterTree: parameterTree, isActive: mode == 1)

            Divider()
                .frame(height: 70)
                .background(Color(red: 0.3, green: 0.3, blue: 0.3))

            // SEQ section - always visible
            SeqControlsSection(parameterTree: parameterTree, sequencerModel: sequencerModel, isActive: mode == 2, currentPage: $currentPage)
        }
    }
}

// MARK: - Arp Controls Section (always visible)

struct ArpControlsSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("PATTERN")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthSecondary)
                ArpPatternPicker(param: parameterTree.arpeggiator.arpPattern)
            }
            
            VStack(spacing: 4) {
                Text("OCTAVES")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthSecondary)
                SynthButtonGroup(param: parameterTree.arpeggiator.arpOctaves, orientation: .horizontal)
            }
            
            VStack(spacing: 4) {
                Text("LATCH")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthSecondary)
                SynthButton(param: parameterTree.arpeggiator.arpLatch, style: .toggle, size: .small)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .opacity(isActive ? 1.0 : 0.4)
        .allowsHitTesting(isActive)
    }
}

// MARK: - Seq Controls Section (always visible)

struct SeqControlsSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    var sequencerModel: SequencerModel?
    let isActive: Bool
    @Binding var currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("LEN")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthSecondary)
                SeqLengthPicker(param: parameterTree.sequencer.seqLength)
            }

            // Step grid with page nav
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<4) { page in
                        Button(action: { currentPage = page }) {
                            Text("\(page + 1)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(currentPage == page ? .white : .gray)
                                .frame(width: 16, height: 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(currentPage == page ? Color.orange : Color(red: 0.2, green: 0.2, blue: 0.2))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                StepGridView(startStep: currentPage * 8, sequencerModel: sequencerModel)
            }

            // Transport
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    TransportButton(icon: "play.fill", color: .green)
                    TransportButton(icon: "stop.fill", color: .red)
                }
                HStack(spacing: 3) {
                    TransportButton(icon: "record.circle", color: .red)
                    TransportButton(icon: "xmark", color: .gray)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(isActive ? 1.0 : 0.4)
        .allowsHitTesting(isActive)
    }
}

// MARK: - Timing Controls (Sync, Rate, Gate, Swing) - Compact horizontal

struct TimingControlsView: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        let syncParam = parameterTree.arpSeq.arpSeqSyncMode as! ObservableAUParameter
        let isSynced = syncParam.value > 0.5
        let modeParam = parameterTree.arpSeq.arpSeqMode as! ObservableAUParameter
        let arpSeqMode = Int(modeParam.value)
        
        HStack(spacing: 10) {
            // Sync button with tempo rate picker or rate knob underneath (ZStack for stable layout)
            VStack(spacing: 4) {
                Text("SYNC")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                    .fixedSize()
                SynthButton(param: parameterTree.arpSeq.arpSeqSyncMode, style: .toggle, size: .small)
                
                ZStack {
                    ArpSeqTempoRatePicker(param: parameterTree.arpSeq.arpSeqTempoRate)
                        .opacity(isSynced ? 1.0 : 0.0)
                    
                    SynthKnob(param: parameterTree.arpSeq.arpSeqRate, size: 28, showValue: true, showLabel: false)
                        .opacity(isSynced ? 0.0 : 1.0)
                        .allowsHitTesting(!isSynced)
                }
            }
            
            VStack(spacing: 4) {
                SynthKnob(param: parameterTree.arpSeq.arpSeqGate, size: 28, showValue: false, showLabel: false)
                Text("GATE")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                    .fixedSize()
            }
            
            VStack(spacing: 4) {
                SynthKnob(param: parameterTree.arpSeq.arpSeqSwing, size: 28, showValue: false, showLabel: false)
                Text("SWING")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                    .fixedSize()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(arpSeqMode == 0 ? 0.4 : 1.0)
    }
}

// MARK: - Velocity Controls - Compact

struct VelocityControlsView: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        let modeParam = parameterTree.arpSeq.arpSeqMode as! ObservableAUParameter
        let arpSeqMode = Int(modeParam.value)
        
        HStack(spacing: 6) {
            VStack(spacing: 4) {
                SynthSlider(
                    param: parameterTree.arpSeq.arpSeqVelocity,
                    orientation: .vertical,
                    trackWidth: 5,
                    trackLength: 40,
                    showLabel: false
                )
                Text("VEL")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                    .fixedSize()
            }
            
            VStack(spacing: 4) {
                SynthSlider(
                    param: parameterTree.arpSeq.arpSeqAccentVelocity,
                    orientation: .vertical,
                    trackWidth: 5,
                    trackLength: 40,
                    showLabel: false
                )
                Text("ACC")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                    .fixedSize()
            }
        }
        .opacity(arpSeqMode == 0 ? 0.4 : 1.0)
    }
}

// MARK: - Step Grid View - Compact

struct StepGridView: View {
    let startStep: Int
    var sequencerModel: SequencerModel?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<8) { index in
                let stepIndex = startStep + index
                if let model = sequencerModel, let step = model.step(at: stepIndex) {
                    StepButtonView(stepNumber: stepIndex + 1, step: step)
                } else {
                    StepButtonPlaceholder(stepNumber: stepIndex + 1)
                }
            }
        }
    }
}

struct StepButtonView: View {
    let stepNumber: Int
    var step: SequencerStep
    @State private var isDragging: Bool = false
    @State private var dragStartPitch: Int = 0

    private let cellCornerRadius: CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            // Main content area (tappable for gate, draggable for pitch)
            VStack(spacing: 2) {
                Text("\(stepNumber)")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.synthSecondary)

                Text(step.pitchOffset >= 0 ? "+\(step.pitchOffset)" : "\(step.pitchOffset)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(step.gate ? .white : .gray)

                RoundedRectangle(cornerRadius: 1)
                    .fill(step.gate ? Color.orange : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 24, height: 4)
            }
            .padding(.top, 3)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                step.gate.toggle()
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartPitch = step.pitchOffset
                        }
                        let deltaY = -value.translation.height / 10
                        step.pitchOffset = max(-12, min(12, dragStartPitch + Int(deltaY)))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Bottom toggle buttons - flush with cell edges
            HStack(spacing: 0) {
                // Accent button (left)
                Button {
                    step.accent.toggle()
                } label: {
                    Text("!")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(step.accent ? .black : .gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: cellCornerRadius,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 0
                            )
                            .fill(step.accent ? Color.orange : Color(red: 0.08, green: 0.08, blue: 0.08))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Divider
                Rectangle()
                    .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .frame(width: 1)

                // Tie button (right)
                Button {
                    step.tie.toggle()
                } label: {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: cellCornerRadius,
                        topTrailingRadius: 0
                    )
                    .fill(step.tie ? Color.cyan : Color(red: 0.08, green: 0.08, blue: 0.08))
                    .overlay(
                        Text("⌢")
                            .font(.system(size: 12, weight: .bold))
                            .offset(y: -3)
                            .foregroundColor(step.tie ? .black : .gray)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 14)
        }
        .frame(width: 30, height: 55)
        .background(
            RoundedRectangle(cornerRadius: cellCornerRadius)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: cellCornerRadius)
                        .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
                )
        )
    }
}

/// Placeholder for when sequencer model isn't available
struct StepButtonPlaceholder: View {
    let stepNumber: Int

    private let cellCornerRadius: CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 2) {
                Text("\(stepNumber)")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.synthSecondary)

                Text("+0")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 24, height: 4)
            }
            .padding(.top, 3)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom toggle buttons placeholder - flush with cell edges
            HStack(spacing: 0) {
                // Accent placeholder (left)
                Text("!")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: cellCornerRadius,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                    )

                // Divider
                Rectangle()
                    .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .frame(width: 1)

                // Tie placeholder (right)
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: cellCornerRadius,
                    topTrailingRadius: 0
                )
                .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                .overlay(
                    Text("⌢")
                        .font(.system(size: 12, weight: .bold))
                        .offset(y: -3)
                        .foregroundColor(.gray.opacity(0.5))
                )
            }
            .frame(height: 14)
        }
        .frame(width: 30, height: 55)
        .background(
            RoundedRectangle(cornerRadius: cellCornerRadius)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: cellCornerRadius)
                        .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Transport Button - Compact

struct TransportButton: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 22, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Arp/Seq Tempo Rate Picker

struct ArpSeqTempoRatePicker: View {
    @State var param: ObservableAUParameter
    @State private var showingMenu = false
    
    private var currentTempoRate: String {
        let index = Int(param.value)
        guard let valueStrings = param.valueStrings,
              index >= 0 && index < valueStrings.count else {
            return "1/16"
        }
        return valueStrings[index]
    }
    
    var body: some View {
        Button(action: {
            showingMenu.toggle()
        }) {
            HStack(spacing: 2) {
                Text(currentTempoRate)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthPrimary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 5, weight: .medium))
                    .foregroundColor(.synthSecondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(red: 0.4, green: 0.4, blue: 0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showingMenu) {
            VStack(alignment: .leading, spacing: 2) {
                if let valueStrings = param.valueStrings {
                    ForEach(Array(valueStrings.enumerated()), id: \.offset) { index, tempoRate in
                        Button(action: {
                            param.onEditingChanged(true)
                            param.value = Float(index)
                            param.onEditingChanged(false)
                            showingMenu = false
                        }) {
                            HStack {
                                Text(tempoRate)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Int(param.value) == index ? .orange : .primary)
                                Spacer()
                                if Int(param.value) == index {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(4)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(6)
        }
    }
}

// MARK: - Arp Pattern Picker

struct ArpPatternPicker: View {
    @State var param: ObservableAUParameter
    @State private var showingMenu = false
    
    private var currentPattern: String {
        let index = Int(param.value)
        guard let valueStrings = param.valueStrings,
              index >= 0 && index < valueStrings.count else {
            return "Up"
        }
        return valueStrings[index]
    }
    
    private var patternIcon: String {
        let index = Int(param.value)
        switch index {
        case 0: return "arrow.up"
        case 1: return "arrow.down"
        case 2: return "arrow.up.arrow.down"
        case 3: return "arrow.down.arrow.up"
        case 4: return "shuffle"
        case 5: return "number"
        default: return "arrow.up"
        }
    }
    
    var body: some View {
        Button(action: {
            showingMenu.toggle()
        }) {
            HStack(spacing: 3) {
                Image(systemName: patternIcon)
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
                    .frame(width: 12)

                Text(currentPattern)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.synthPrimary)
                    .frame(width: 50, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 5, weight: .medium))
                    .foregroundColor(.synthSecondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(red: 0.4, green: 0.4, blue: 0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showingMenu) {
            VStack(alignment: .leading, spacing: 2) {
                if let valueStrings = param.valueStrings {
                    ForEach(Array(valueStrings.enumerated()), id: \.offset) { index, pattern in
                        Button(action: {
                            param.onEditingChanged(true)
                            param.value = Float(index)
                            param.onEditingChanged(false)
                            showingMenu = false
                        }) {
                            HStack {
                                Text(pattern)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Int(param.value) == index ? .orange : .primary)
                                Spacer()
                                if Int(param.value) == index {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(4)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(6)
        }
    }
}

// MARK: - Sequencer Length Picker

struct SeqLengthPicker: View {
    @State var param: ObservableAUParameter
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: {
                param.onEditingChanged(true)
                param.value = max(param.min, param.value - 1)
                param.onEditingChanged(false)
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.synthPrimary)
                    .frame(width: 16, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("\(Int(param.value))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.synthPrimary)
                .frame(width: 22)
            
            Button(action: {
                param.onEditingChanged(true)
                param.value = min(param.max, param.value + 1)
                param.onEditingChanged(false)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.synthPrimary)
                    .frame(width: 16, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Performance Section Preview")
                .font(.title2)
                .foregroundColor(.white)
        }
        .padding()
    }
    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
}
