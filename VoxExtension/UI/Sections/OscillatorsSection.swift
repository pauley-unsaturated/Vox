//
//  OscillatorsSection.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// The oscillators section showing OSC1, OSC2, and SUB side-by-side
struct OscillatorsSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section title - left aligned with content
            Text("OSCILLATORS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.synthPrimary)
            
            // Side-by-side oscillator controls with equal sizing
            HStack(alignment: .top, spacing: 8) {
                OscillatorControls(
                    title: "OSC 1",
                    waveformParam: parameterTree.oscillator1.osc1Waveform,
                    octaveParam: parameterTree.oscillator1.osc1Octave,
                    detuneParam: parameterTree.oscillator1.osc1Detune,
                    pulseWidthParam: parameterTree.oscillator1.osc1PulseWidth
                )
                
                OscillatorControls(
                    title: "OSC 2",
                    waveformParam: parameterTree.oscillator2.osc2Waveform,
                    octaveParam: parameterTree.oscillator2.osc2Octave,
                    detuneParam: parameterTree.oscillator2.osc2Detune,
                    pulseWidthParam: parameterTree.oscillator2.osc2PulseWidth,
                    syncParam: parameterTree.oscillator2.osc2Sync
                )
                
                SubOscillatorControls(
                    octaveParam: parameterTree.subOscillator.subOscOctave,
                    pulseWidthParam: parameterTree.subOscillator.subOscPulseWidth
                )
            }
        }
        .padding(10)
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

/// Individual oscillator controls (OSC1 or OSC2)
struct OscillatorControls: View {
    let title: String
    @State var waveformParam: ObservableAUParameter
    @State var octaveParam: ObservableAUParameter
    @State var detuneParam: ObservableAUParameter
    @State var pulseWidthParam: ObservableAUParameter
    @State var syncParam: ObservableAUParameter?
    
    init(
        title: String,
        waveformParam: ObservableAUParameter,
        octaveParam: ObservableAUParameter,
        detuneParam: ObservableAUParameter,
        pulseWidthParam: ObservableAUParameter,
        syncParam: ObservableAUParameter? = nil
    ) {
        self.title = title
        self._waveformParam = State(initialValue: waveformParam)
        self._octaveParam = State(initialValue: octaveParam)
        self._detuneParam = State(initialValue: detuneParam)
        self._pulseWidthParam = State(initialValue: pulseWidthParam)
        self._syncParam = State(initialValue: syncParam)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Oscillator title
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
            }
            
            // Tune knob and Octave
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    SynthKnob(param: detuneParam, size: 40, showValue: false, showLabel: false)
                    Text("TUNE")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                }
                
                VStack(spacing: 2) {
                    Text("OCTAVE")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    SynthButtonGroup(param: octaveParam, orientation: .horizontal)
                }
            }
            
            // Waveform selection
            VStack(spacing: 4) {
                Text("WAVE")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                SynthButtonGroup(param: waveformParam, orientation: .horizontal, showWaveformIcons: true)
            }
            
            // PW knob
            VStack(spacing: 2) {
                SynthKnob(param: pulseWidthParam, size: 40, showValue: false, showLabel: false)
                Text("PW")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
            }
            
            // Sync button for OSC2 (at bottom, left-aligned)
            if let syncParam = syncParam {
                HStack {
                    VStack(spacing: 2) {
                        Text("SYNC")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                        SynthButton(param: syncParam, style: .toggle, size: .small)
                    }
                    Spacer()
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
        )
    }
}

/// Sub oscillator controls - styled to match OSC1/OSC2
struct SubOscillatorControls: View {
    @State var octaveParam: ObservableAUParameter
    @State var pulseWidthParam: ObservableAUParameter
    
    var body: some View {
        VStack(spacing: 8) {
            // Title matching OSC1/OSC2 style
            HStack {
                Text("SUB")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
            }
            
            // Octave selector
            VStack(spacing: 2) {
                Text("OCTAVE")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
                SynthButtonGroup(param: octaveParam, orientation: .horizontal)
            }
            
            // PW knob
            VStack(spacing: 2) {
                SynthKnob(param: pulseWidthParam, size: 40, showValue: false, showLabel: false)
                Text("PW")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.synthSecondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
        )
    }
}

/// Noise generator controls
struct NoiseControls: View {
    var body: some View {
        VStack(spacing: 12) {
            // Simple centered layout for noise info
            VStack(spacing: 8) {
                Text("NOISE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                
                Text("White noise generator for percussive sounds and texture")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.synthSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                    
                Text("Level controlled by MIX slider")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.orange)
                    .opacity(0.8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Oscillators Section Preview")
                .font(.title2)
                .foregroundColor(.white)
        }
        .padding()
    }
    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
}
