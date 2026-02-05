//
//  LFOSection.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// The LFO section containing oscillator controls and modulation routing
struct LFOSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section title
            Text("LFO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.synthPrimary)
            
            VStack {
                // Main content: Two columns
                HStack(alignment: .top, spacing: 16) {
                    // Left column: Controls
                    VStack(spacing: 10) {
                        // Top row: Wave, Rate, Phase, Delay (horizontal)
                        HStack(spacing: 12) {
                            // Waveform selection
                            VStack(spacing: 4) {
                                Text("WAVE")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.synthSecondary)
                                
                                SynthButtonGroup(param: parameterTree.lfo.lfoWaveform, orientation: .horizontal, showWaveformIcons: true)
                            }
                            
                            // Rate control (knob has its own label, disabled when synced)
                            SynthKnob(param: parameterTree.lfo.lfoRate, size: 40)
                                .opacity({
                                    let syncParam = parameterTree.lfo.lfoSyncMode as! ObservableAUParameter
                                    return syncParam.value > 0.5 ? 0.3 : 1.0
                                }())
                                .allowsHitTesting({
                                    let syncParam = parameterTree.lfo.lfoSyncMode as! ObservableAUParameter
                                    return syncParam.value <= 0.5
                                }())
                            
                            // Phase control (knob has its own label)
                            SynthKnob(param: parameterTree.lfo.lfoPhase, size: 40)
                            
                            // Delay control (knob has its own label)
                            SynthKnob(param: parameterTree.lfo.lfoDelay, size: 40)
                        }
                        
                        // Bottom row: Sync (with tempo rate underneath), Retrig
                        HStack(alignment: .top, spacing: 12) {
                            // Sync with tempo rate picker underneath
                            VStack(spacing: 4) {
                                Text("SYNC")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.synthSecondary)
                                
                                SynthButton(param: parameterTree.lfo.lfoSyncMode, style: .toggle, size: .medium)
                                
                                TempoRatePicker(param: parameterTree.lfo.lfoTempoRate)
                                    .opacity({
                                        let syncParam = parameterTree.lfo.lfoSyncMode as! ObservableAUParameter
                                        return syncParam.value > 0.5 ? 1.0 : 0.3
                                    }())
                            }
                            
                            VStack(spacing: 4) {
                                Text("RETRIG")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.synthSecondary)
                                
                                SynthButton(param: parameterTree.lfo.lfoRetrigger, style: .toggle, size: .medium)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Right column: Mod Destinations
                    VStack(spacing: 6) {
                        Text("MOD")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.synthSecondary)
                            .fixedSize()
                        
                        HStack(spacing: 8) {
                            ModulationDestination(
                                title: "OSC",
                                param: parameterTree.lfoModulation.lfoOscAmount
                            )
                            
                            ModulationDestination(
                                title: "FILT",
                                param: parameterTree.lfoModulation.lfoFilterAmount
                            )
                            
                            ModulationDestination(
                                title: "PWM",
                                param: parameterTree.lfoModulation.lfoPWMAmount
                            )
                            
                            ModulationDestination(
                                title: "E>PW",
                                param: parameterTree.envelopeModulation.envelopePWMAmount
                            )
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
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

/// A small modulation destination control
struct ModulationDestination: View {
    let title: String
    @State var param: ObservableAUParameter
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.synthSecondary)
            
            SynthKnob(param: param, size: 30, showValue: false, showLabel: false)
        }
    }
}

/// Tempo rate picker menu component
struct TempoRatePicker: View {
    @State var param: ObservableAUParameter
    @State private var showingMenu = false
    
    private var currentTempoRate: String {
        let index = Int(param.value)
        guard let valueStrings = param.valueStrings,
              index >= 0 && index < valueStrings.count else {
            return "1/4"
        }
        return valueStrings[index]
    }
    
    var body: some View {
        Button(action: {
            showingMenu.toggle()
        }) {
            HStack(spacing: 4) {
                Text(currentTempoRate)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.synthPrimary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .medium))
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
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showingMenu) {
            VStack(alignment: .leading, spacing: 2) {
                if let valueStrings = param.valueStrings {
                    ForEach(Array(valueStrings.enumerated()), id: \.offset) { index, tempoRate in
                        Button(action: {
                            param.value = Float(index)
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

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("LFO & Performance Sections Preview")
                .font(.title2)
                .foregroundColor(.white)
            
            // Individual component previews would go here
            // Note: Actual preview requires mock parameter tree
            
            HStack(spacing: 15) {
                ModulationDestination(
                    title: "OSC",
                    param: ObservableAUParameter(
                        address: 0,
                        parameterTree: nil,
                        spec: ParameterSpec(
                            address: 0,
                            identifier: "lfoOsc",
                            name: "LFO Osc",
                            units: .percent,
                            valueRange: 0...100,
                            defaultValue: 0
                        )
                    )
                )
                
                ModulationDestination(
                    title: "FILTER",
                    param: ObservableAUParameter(
                        address: 1,
                        parameterTree: nil,
                        spec: ParameterSpec(
                            address: 1,
                            identifier: "lfoFilter",
                            name: "LFO Filter",
                            units: .percent,
                            valueRange: 0...100,
                            defaultValue: 0
                        )
                    )
                )
            }
        }
        .padding()
    }
    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
}
