//
//  MixControls.swift
//  VoxExtension
//
//  Created by Gemini on 7/6/25.
//

import SwiftUI

/// Mix controls with vertical sliders for oscillator levels
struct MixControls: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section title - left aligned
            Text("MIX")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.synthPrimary)
            
            // Sliders in a grouping rectangle (matching EnvelopeSection style)
            VStack {
                HStack(spacing: 20) {
                    // OSC 1 level slider
                    VStack(spacing: 4) {
                        SynthSlider(
                            param: parameterTree.oscillator1.osc1Level,
                            orientation: .vertical,
                            trackWidth: 6,
                            trackLength: 80,
                            showLabel: false
                        )
                        Text("OSC1")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                            .fixedSize()
                    }
                    
                    // OSC 2 level slider
                    VStack(spacing: 4) {
                        SynthSlider(
                            param: parameterTree.oscillator2.osc2Level,
                            orientation: .vertical,
                            trackWidth: 6,
                            trackLength: 80,
                            showLabel: false
                        )
                        Text("OSC2")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                            .fixedSize()
                    }
                    
                    // Sub Oscillator level slider
                    VStack(spacing: 4) {
                        SynthSlider(
                            param: parameterTree.subOscillator.subOscLevel,
                            orientation: .vertical,
                            trackWidth: 6,
                            trackLength: 80,
                            showLabel: false
                        )
                        Text("SUB")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                            .fixedSize()
                    }
                    
                    // Noise level slider
                    VStack(spacing: 4) {
                        SynthSlider(
                            param: parameterTree.noise.noiseLevel,
                            orientation: .vertical,
                            trackWidth: 6,
                            trackLength: 80,
                            showLabel: false
                        )
                        Text("NOISE")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.synthSecondary)
                            .fixedSize()
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
            )
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
